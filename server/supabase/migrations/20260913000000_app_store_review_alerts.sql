-- Tracks App Store reviews already posted to Slack, so the poller only alerts
-- once per review.

create table if not exists public.app_store_review_alerts (
    review_id   text primary key,
    country     text not null,
    posted_at   timestamptz not null default now(),
    title       text,
    rating      integer,
    author_name text,
    updated_at  timestamptz
);

alter table public.app_store_review_alerts enable row level security;

-- This table is only for the Edge Function service role. Clients do not need it.
revoke all on table public.app_store_review_alerts from anon, authenticated;
