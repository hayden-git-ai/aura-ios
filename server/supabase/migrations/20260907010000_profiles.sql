-- Per-user profile: the portable identity + progress that follows a person
-- across devices. Frozen-apps selections are deliberately NOT here: their
-- FamilyActivitySelection tokens are device-local and cannot be synced.
--
-- One row per auth user, created automatically on signup (web or app) so the
-- client only ever reads and updates its own row, never races to insert it.
-- Everything is owner-scoped by RLS to the verified JWT user, so a modified
-- client cannot read or write anyone else's row or forge its own user_id.

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
-- No delete policy: profiles die with the auth user via the cascade, not by a
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

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
    before update on public.profiles
    for each row execute function public.touch_updated_at();

-- Create the profile the moment the account is created (web signup fires this
-- too), so neither surface races to insert it. security definer because it
-- writes a table the brand-new user cannot yet touch.
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();
