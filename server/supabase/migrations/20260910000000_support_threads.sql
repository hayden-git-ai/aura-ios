-- Maps a user's support thread to its Slack message timestamp, so the two-way
-- relay knows which Slack thread carries which user's conversation.
--
-- One row per user. `slack_ts` is the timestamp of the parent Slack message
-- (the thread root) posted the first time that user writes in. Every later
-- message from that user is posted as a reply under this ts, and every founder
-- reply in that Slack thread is matched back to this user_id.
--
-- Only the service role (the edge functions) ever touches this table. RLS is on
-- with no policies, so the anon/authenticated client cannot read or write it;
-- the service role bypasses RLS.

create table if not exists public.support_threads (
    user_id    uuid primary key references auth.users(id) on delete cascade,
    slack_ts   text not null,
    created_at timestamptz not null default now()
);

-- Founder replies arrive keyed by the Slack thread ts, so we look up by it.
create index if not exists support_threads_slack_ts
    on public.support_threads (slack_ts);

alter table public.support_threads enable row level security;
