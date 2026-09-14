-- Cancellation feedback: the reason + optional notes a user leaves in the
-- Manage Subscription flow on the way out. Insert-only from the client under the
-- user's own id (RLS); the founder reads it server-side (service role / dashboard).
-- No client SELECT policy, so one user can never read another's feedback.

create table if not exists public.cancel_feedback (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references auth.users (id) on delete cascade,
    reason     text not null,
    notes      text,
    created_at timestamptz not null default now()
);

alter table public.cancel_feedback enable row level security;

-- Authenticated users may insert only their own row. No select/update/delete
-- policy exists, so the client can write but never read this table.
grant insert on public.cancel_feedback to authenticated;

create policy "cancel_feedback insert own"
    on public.cancel_feedback
    for insert
    to authenticated
    with check ((select auth.uid()) = user_id);
