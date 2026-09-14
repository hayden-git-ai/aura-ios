-- Per-device daily quota for photo-proof verification.
--
-- The verify-proof Edge Function calls bump_proof_usage() before every Gemini
-- request. The shared app key stops strangers, but it ships in the binary, so
-- the working assumption is that somebody has it and the only question left is
-- how much they can spend. This is the ceiling that answers that: a real person
-- never reaches it, a scraper hits a wall on every device it can fake.
--
-- The function is the ONLY thing that touches this table. It runs as the
-- service role (which bypasses RLS); no anon or authenticated client can read,
-- write, or call anything here. RLS is enabled with no policies so that even if
-- the table were ever exposed through the Data API, it stays sealed.
--
-- Column names (device_id, day, count) match the table that already existed on
-- the project when this migration was first written, so the create-if-not-exists
-- below is a no-op there and creates the same shape on a fresh project.

create table if not exists public.proof_usage (
    device_id text not null,
    day       date not null default (now() at time zone 'utc')::date,
    count     integer not null default 0,
    primary key (device_id, day)
);

alter table public.proof_usage enable row level security;

-- No policies, and no grants to the client roles. Locked to the service role.
revoke all on table public.proof_usage from anon, authenticated;

-- Counts this request against the device's day and reports whether it may
-- proceed. The increment and the read happen in one statement so two requests
-- landing together can't both see the same number: the row is updated and
-- returns its own new value atomically.
--
-- The parameters (p_device, p_limit) and the returned column names (allowed,
-- used) are the contract the Edge Function reads; they are deliberately NOT the
-- table's own column names. Internally the count lives in `count`; it is
-- returned as `used`.
create or replace function public.bump_proof_usage(p_device text, p_limit integer)
returns table (allowed boolean, used integer)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    v_count integer;
begin
    insert into public.proof_usage (device_id, day, count)
    values (p_device, (now() at time zone 'utc')::date, 1)
    on conflict (device_id, day)
        do update set count = public.proof_usage.count + 1
    returning public.proof_usage.count into v_count;

    allowed := v_count <= p_limit;
    used := v_count;
    return next;
end;
$$;

-- The function is invoked with the service-role key. Nobody else may call it.
revoke all on function public.bump_proof_usage(text, integer) from public, anon, authenticated;
grant execute on function public.bump_proof_usage(text, integer) to service_role;
