-- The user's editable library: their habits (custom ones plus the tweaks they
-- made to the seeded set) and their routines. Carried in the same per-user
-- progress row as one JSON object { updatedAt, habits, routines }.
--
-- Unlike the day-log and counters (which only grow and merge max-wins), the
-- library is a mutable list, so the app resolves it last-write-wins by the
-- updatedAt inside the blob: a fresh device adopts the account's library, a
-- locally-customized device pushes its own, and neither dominant flow loses data.

alter table public.progress
    add column if not exists library text not null default '{}';
