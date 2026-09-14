-- Maps a user to their Crisp conversation, so the support relay knows which Crisp
-- conversation carries which user. One row per user. `session_id` is the Crisp
-- conversation id (e.g. "session_..."); the first time a user writes in we create
-- a Crisp conversation and record it, and every later message posts into it. When
-- a founder replies in Crisp, the webhook matches its session_id back to this user.
--
-- Only the service role (the edge functions) touches this table. RLS is on with no
-- policies, so the anon/authenticated client cannot read or write it; the service
-- role bypasses RLS.

create table if not exists public.crisp_sessions (
    user_id    uuid primary key references auth.users(id) on delete cascade,
    session_id text not null,
    created_at timestamptz not null default now()
);

-- Operator replies arrive keyed by the Crisp session id, so we look up by it.
create index if not exists crisp_sessions_session
    on public.crisp_sessions (session_id);

alter table public.crisp_sessions enable row level security;
