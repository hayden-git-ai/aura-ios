-- Per-user progress: the day-log history that streak, journey, stats, and
-- coins-earned all derive from. Kept separate from profiles so identity stays
-- light and progress can grow independently.
--
-- day_log is the JSON-encoded [DayRecord] array (ISO8601 dates), the same shape
-- the app stores locally. Stored as text, not jsonb, so the app controls the
-- encoding exactly and there is no date-format mismatch; nothing queries into it.
--
-- Owner-scoped by RLS to the verified JWT user. Spendable balance is NOT synced
-- here: a purchase unlocks apps on one device, so "spent" is device-local; only
-- the earn history travels.

create table if not exists public.progress (
    user_id    uuid primary key references auth.users(id) on delete cascade,
    day_log    text not null default '[]',
    updated_at timestamptz not null default now()
);

alter table public.progress enable row level security;

create policy "progress self-select" on public.progress
    for select using (auth.uid() = user_id);

create policy "progress self-insert" on public.progress
    for insert with check (auth.uid() = user_id);

create policy "progress self-update" on public.progress
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- No delete policy: progress dies with the auth user via the cascade.

-- Reuses touch_updated_at() from the profiles migration.
drop trigger if exists progress_touch_updated_at on public.progress;
create trigger progress_touch_updated_at
    before update on public.progress
    for each row execute function public.touch_updated_at();
