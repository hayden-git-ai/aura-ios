# Photo-proof verification

A Supabase Edge Function. One job: hold the Gemini key so the app doesn't have
to. Anything shipped inside an iOS binary can be extracted from it, and a leaked
key is somebody else's traffic on your bill.

The function is already written: `supabase/functions/verify-proof/index.ts`.
Nothing below asks you to write code.

---

## Deploying it

Run every command from this `server/` folder.

### 1. Install the CLI

```bash
brew install supabase/tap/supabase
```

### 2. Sign in

```bash
supabase login
```

Opens a browser, you approve, it comes back. Once per machine.

### 3. Find your project reference

In the Supabase dashboard, open your project. The URL looks like:

```
https://supabase.com/dashboard/project/abcdefghijklmnop
```

That last part is the reference. It's also under Project Settings → General →
Reference ID.

### 4. Link this folder to that project

```bash
supabase init
supabase link --project-ref YOUR_REFERENCE
```

`init` creates a config file next to the function. `link` may ask for your
database password. It's the one you set when you created the project. If you
don't have it, reset it under Project Settings → Database. Nothing here uses the
database, it's just how linking authenticates.

### 5. Hand over the Gemini key

```bash
supabase secrets set GEMINI_API_KEY=paste_your_key_here
```

This stores it on Supabase, not in this folder. It never goes near the repo.

### 6. Deploy

```bash
supabase functions deploy verify-proof --no-verify-jwt
```

`--no-verify-jwt` because Aura has no accounts yet, so there's no signed-in user
to check. See **Before launch** below. This is the one thing here you must come
back to.

---

## Wiring it into the app

Deploying prints your URL. It's always this shape:

```
https://YOUR_REFERENCE.supabase.co/functions/v1/verify-proof
```

Open `Aura iOS/Services/…/HabitStore.swift`, find `proofEndpoint`, and replace
the `nil`:

```swift
private static let proofEndpoint: URL? = URL(string: "https://YOUR_REFERENCE.supabase.co/functions/v1/verify-proof")
```

That's the whole switch. `nil` keeps the app on the mock; a URL puts it on the
real thing. Build and take a photo.

---

## Checking it works before touching the app

```bash
curl -X POST https://YOUR_REFERENCE.supabase.co/functions/v1/verify-proof \
  -H 'content-type: application/json' \
  -d "{\"habitName\":\"Read\",\"hint\":\"Book in frame and readable\",\"image\":\"$(base64 -i ~/Desktop/book.jpg)\"}"
```

Point it at any photo on your desktop. You want:

```json
{"passed":true,"reason":"Book open in frame, clearly readable."}
```

If something's wrong the error says which: `GEMINI_API_KEY not set` means step 5
didn't take, and `gemini 400` means the key itself was rejected.

Watch it run with `supabase functions logs verify-proof`.

---

## Changing the model

`MODEL` at the top of `index.ts`, then deploy again. It's pinned server-side on
purpose: Flash versions move, and comparing models for cost or accuracy
shouldn't need an App Store release.

---

## How the endpoint is protected today

Every request must carry an `x-aura-key` header matching the `AURA_APP_KEY`
secret. Without it the function answers 401 and never calls Gemini, so the URL
on its own is worth nothing to whoever finds it.

**Be clear about what this is.** The key ships inside the app binary and can be
extracted by anyone willing to pull the IPA apart. It is not authentication. It
turns away scanners, crawlers, and anyone the link gets forwarded to, which is
the difference between "somebody found it" and "somebody attacked it". It will
not stop a determined person.

Rotating it takes two steps, and the server half needs no App Store release:

```bash
npx -y supabase@latest secrets set AURA_APP_KEY=new_value --project-ref YOUR_REFERENCE
```

then ship the app with the new value in `LiveProofVerifier.appKey`. Old builds
stop working the moment the secret changes, so rotate on a release, not between
them.

## Rate limiting

Every request counts against a per-device daily ceiling, currently **60**. A real
person never reaches it. The counter lives in `public.proof_usage` and is
incremented by `public.bump_proof_usage`, a `security definer` function that
updates the row and returns its new value in one statement, so two requests
arriving together cannot both read the same number.

The device is the app's `identifierForVendor`: the same for every Aura install on
a phone, reset if the app is deleted, and meaningless to anyone but us. No
account, no advertising identifier.

Change the ceiling without deploying anything:

```bash
npx -y supabase@latest secrets set PROOF_DAILY_LIMIT=100 --project-ref YOUR_REFERENCE
```

It takes effect on the next cold start, within a few seconds.

**It fails open.** If Postgres is unreachable the verification still runs and the
ceiling is what's lost. Losing the cap briefly is a smaller problem than every
user in the world being unable to earn.

A request with no device header collapses into one shared `unknown` bucket rather
than being waved through, so omitting the header is worse than sending it.

Old rows are harmless but accumulate. One row per device per day, so a cleanup is
worth scheduling eventually:

```sql
delete from public.proof_usage where day < current_date - 30;
```

## Kill switch

One secret cuts all Gemini spend instantly, with no redeploy and no App Store
release:

```bash
npx -y supabase@latest secrets set PROOF_DISABLED=on --project-ref YOUR_REFERENCE
```

While it is on, every request short-circuits before the key check, the rate gate,
and any call to Google, and returns a pass. That is deliberate: a pass is the same
thing the app already falls back to when it cannot reach the endpoint, so users
keep earning while nothing is spent. The trade during an incident is that a few
unverified photos get through, which is cheaper than a runaway bill and kinder
than freezing everyone out. To freeze earning instead, change the disabled branch
in `index.ts` to return `passed: false`.

Turn it back on by clearing the secret:

```bash
npx -y supabase@latest secrets unset PROOF_DISABLED --project-ref YOUR_REFERENCE
```

Any obvious truthy value (`on`, `1`, `true`, `yes`) enables it; anything else,
including unset, leaves verification running. It is read fresh on each request, so
the effect is immediate.

## Authentication

Two ways in, checked strongest first:

1. **Signed-in user.** The app sends its Supabase access token in the
   `Authorization: Bearer` header. The function verifies it against Auth
   (`/auth/v1/user`) and, when valid, counts the daily quota per **user id** —
   which no faked device id can multiply. This is real authentication.
2. **Not-yet-signed-in.** No valid token, so the function requires the shared
   `AURA_APP_KEY` and counts the quota per **device**. Weak by nature (the key
   ships in the binary) but it keeps the bare URL worthless.

`verify_jwt` stays **off** at the gateway on purpose: the anonymous-but-keyed
path in (2) has to reach the function. Authentication happens inside the function
instead, which is what lets both paths coexist.

### Before launch

Make sign-in mandatory, then **drop the shared-key fallback** so the endpoint is
JWT-only: delete path (2) and reject any request without a valid token. At that
point the extractable app key stops mattering. App Attest is an alternative if
you ever want to gate abuse without requiring an account.
