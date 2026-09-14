-- Drop the vestigial coin/streak columns on profiles.
--
-- The coin balance and streak counts are client-side state that syncs through
-- public.progress (day_log + stats), never these columns. They were carried on
-- profiles from an earlier design and are now dead weight: the app's profile
-- upsert only writes display_name/email/avatar_url. Because they are
-- client-writable, a modified client could still stuff junk into them, so
-- dropping them shrinks the attack surface and removes a second, non-authoritative
-- coin/streak store that could confuse a future reader.

alter table public.profiles drop column if exists coins;
alter table public.profiles drop column if exists current_streak;
alter table public.profiles drop column if exists longest_streak;
