# Supabase Auth + Sync Plan (draft)

Draft for review. Nothing here is built yet. It covers how the native app gets a
real Supabase session from Sign in with Apple/Google, and the first table to sync.

## Identity model: two paths, one Supabase project

There are two populations, created two different ways, both living in the same
`auth.users`:

- **Web-funnel users** create their paid account on the web paywall with
  **email and password**.
- **Direct App Store users** create their account in the app with **Apple or
  Google**.

So the app must support **all three** sign-in methods: email/password (so a
returning web user can reach their paid account), plus Apple and Google (for
direct users). Supabase runs all three providers on one project.

### The gap this exposes

App onboarding today offers only Apple, Google, and Skip. **A paying web user
cannot currently sign into their account from the app**, because there is no
email/password path. Adding that path is now part of this work, not optional.

### The edge case to guard, not block on

The same person usually stays on one path, so the two populations rarely collide.
The one bad case: a web user (paid, email/password) opens the app and taps "Sign
in with Apple" instead of entering their email/password. That creates a **second,
empty Apple user**, and their subscription and app data drift apart.

Two guardrails, both cheap:
1. **UX:** make email/password sign-in a clear, first-class option for returning
   users, not buried under the Apple/Google buttons.
2. **Linking:** turn on Supabase automatic identity linking by confirmed email,
   so if the Apple/Google email matches the web account's email, it links to the
   same user instead of forking. Note this does not save a user who uses Apple's
   Hide My Email (the relayed address will not match), which is why the UX
   guardrail comes first.

## Native sign-in flow (Apple)

The current `AppleSignInCoordinator` reads `fullName`/`email` and discards the
identity token, with no nonce. To make a Supabase session it needs three changes:

1. Generate a random raw nonce. Set `request.nonce = sha256(rawNonce)` on the
   `ASAuthorizationAppleIDRequest`.
2. On success, capture `credential.identityToken` (the JWT), alongside the
   name/email it already reads.
3. Call `supabase.auth.signInWithIdToken(credentials: .init(provider: .apple,
   idToken: token, nonce: rawNonce))`. Supabase verifies the token with Apple and
   returns a session (access JWT + refresh token).

Name/email are still captured on the first authorization only (Apple sends them
once) and written to the profile row after the session exists.

## Native sign-in flow (Google) — thread 3, later

Same shape once the SDK and client id exist: GoogleSignIn returns an `idToken`,
then `signInWithIdToken(provider: .google, idToken:)`. Identical session bridge.

## Session lifecycle

- Add `supabase-swift`. Create one `SupabaseClient` configured with the project
  URL and the **anon/publishable** key (safe to ship; never the service-role key).
- supabase-swift stores the session itself. Confirm it uses the **Keychain**, not
  UserDefaults, and set an appropriate accessibility class (runbook Phase 3).
- On launch: restore the session, refresh if expired. `isSignedIn` becomes
  derived from session presence, replacing the current local UserDefaults bool.
- Sign out: clear the session **and** the local per-user cache (display name,
  email, avatar, progress) so the next user does not see the last one's data.
- Account switch and reinstall: same cache-clear discipline.

## The frozen-apps reality (correction to the original plan)

The original note listed "profile + frozen apps" as the first sync target. Frozen
apps **cannot be synced**. A `FamilyActivitySelection` is made of
`ApplicationToken`s, which are opaque and **device-local**: Apple mints them per
device and they are not portable to another device or user. There is no API to
move a selection between devices. So on a new phone the user re-picks their apps,
by design, and the block config stays local (it already persists in
`block-config.json`).

What is genuinely portable, and therefore the right first sync target, is
**profile + progress**: name, email, avatar, coins, streaks. That is what follows
a person across devices.

(If we ever want cross-device *display* of which apps are frozen, we could sync
harmless metadata like counts, but never the tokens, and it would not restore
actual blocking. Out of scope for v1.)

## First synced table: `profiles`

One row per user, created automatically when the account is created (on web), so
the app only ever reads and updates its own row.

```sql
-- One profile per auth user. Portable identity + progress.
create table if not exists public.profiles (
    user_id        uuid primary key references auth.users(id) on delete cascade,
    display_name   text,
    email          text,
    avatar_url     text,
    coins          integer not null default 0,
    current_streak integer not null default 0,
    longest_streak integer not null default 0,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- A person sees and edits only their own row. auth.uid() is the verified user
-- from the JWT, so user_id can never be spoofed to someone else's.
create policy "profiles self-select" on public.profiles
    for select using (auth.uid() = user_id);

create policy "profiles self-insert" on public.profiles
    for insert with check (auth.uid() = user_id);

create policy "profiles self-update" on public.profiles
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- No delete policy: profiles die with the auth user via the cascade, not by
-- direct client delete.

-- Keep updated_at honest without trusting the client to set it.
create or replace function public.touch_updated_at()
returns trigger language plpgsql
set search_path = public, pg_temp
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

create trigger profiles_touch_updated_at
    before update on public.profiles
    for each row execute function public.touch_updated_at();

-- Create the profile the moment the account is created (web signup fires this
-- too), so neither surface races to insert it. security definer because it
-- writes a table the new user cannot yet touch.
create or replace function public.handle_new_user()
returns trigger language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
    insert into public.profiles (user_id, email)
    values (new.id, new.email)
    on conflict (user_id) do nothing;
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();
```

Notes:

- `user_id` is the primary key and equals `auth.uid()`. It is never sent by the
  client; RLS derives it from the verified JWT. A modified client cannot write
  another user's row or forge its own id (runbook Phase 5).
- The `handle_new_user` trigger means the row always exists after signup, so the
  app only needs select and update. The self-insert policy is a harmless safety
  net for any pre-existing user without a row.
- `coins`, `current_streak`, `longest_streak` are the user's **own** state.
  Letting the client write them is fine here: cheating them only cheats yourself,
  because coins buy nothing but your own screen time. If coins ever gate a
  server-authoritative benefit (a paid unlock, a leaderboard), the award has to
  move to a server-verified transaction. Flagged, not needed for v1.
- Ships only the anon/publishable key. RLS is the enforcement, not the key.

## Bonus this unlocks: real auth on verify-proof

Once every app user carries a Supabase session, the photo-proof endpoint can stop
relying on the shared app key: require the JWT (drop `--no-verify-jwt`),
authenticate the user, and rate-limit on the **user id** instead of the device
id. That closes the "real authentication" item the security audit flagged as the
last before-launch gap. Sequence it after sign-in is live.

## What I need from you

1. **The anon / publishable key** for the project (safe to ship and to paste
   here; it is designed to be public, unlike the service-role key).
2. **Providers enabled in Supabase Auth:**
   - **Email** on, so email/password works (it usually is by default).
   - **Apple** on, with the app's Bundle ID `Aura-App.Aura-iOS` in its Client IDs
     list. Because the app uses native id-token sign-in (not a web redirect), the
     Bundle ID in Client IDs is the essential part; the OAuth secret-key setup is
     not needed for the app.
   - **Automatic linking by confirmed email** turned on, per the edge case above.
3. **Thumbs-up on the schema** below (this one is just your approval, not a task).

## Build order once those exist

1. Add `supabase-swift`, create the client, Keychain session storage.
2. Add an **email/password sign-in** path to onboarding (the missing piece for
   web users): `signInWithPassword(email:password:)`, with a password-reset link.
3. Add nonce + identity-token capture to `AppleSignInCoordinator`, call
   `signInWithIdToken`, derive `isSignedIn` from the session.
4. Apply the `profiles` migration; read the row on launch, write it on changes
   (name, avatar, coins, streak).
5. Google sign-in (thread 3) once the OAuth client id and SDK are in.
6. Move verify-proof to JWT auth.
