-- Carry the lifetime achievement counters alongside the day-log, in the same
-- per-user progress row. These (earned minutes, healthy habits, reps, focus
-- minutes, per-habit / per-exercise completion counts, health collects, the
-- first-week baseline) drive the Stats achievement cards and are stored
-- separately from the day-log in the app, so the day-log sync did not cover them.
--
-- JSON object encoded by the app, stored as text for the same reason day_log is:
-- the app owns the encoding and nothing queries into it.

alter table public.progress
    add column if not exists stats text not null default '{}';
