-- The in-app support thread ("message the founders"). One row per message.
--
-- A person only ever sees and writes their own thread. Users may insert only
-- their own `user` messages; `team` replies are written by the service role (the
-- Slack round-trip edge function, next), which bypasses RLS. No user update or
-- delete: a thread is a record, not something to edit after the fact.

create table if not exists public.support_messages (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references auth.users(id) on delete cascade,
    sender     text not null check (sender in ('user', 'team')),
    text       text not null,
    created_at timestamptz not null default now()
);

create index if not exists support_messages_user_created
    on public.support_messages (user_id, created_at);

alter table public.support_messages enable row level security;

-- Read only your own thread. (select auth.uid()) evaluates once per query.
create policy "support self-select" on public.support_messages
    for select using ((select auth.uid()) = user_id);

-- Insert only your own messages, and only as the user (never forge a team reply).
create policy "support self-insert" on public.support_messages
    for insert with check ((select auth.uid()) = user_id and sender = 'user');
