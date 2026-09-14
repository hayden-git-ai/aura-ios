-- Resolve Supabase Security + Performance Advisor warnings (2026-09-08).
--
-- SECURITY: handle_new_user() and rls_auto_enable() are SECURITY DEFINER and were
-- executable by public/anon/authenticated. They are only ever meant to run from
-- their triggers (which execute with definer rights regardless of the caller's
-- EXECUTE grant), so revoking direct execute closes the "public can execute a
-- SECURITY DEFINER function" warning without changing behavior.
--
-- PERFORMANCE: every RLS policy called auth.uid() directly, which Postgres
-- re-evaluates once per row ("Auth RLS Initialization Plan" warning). Wrapping it
-- as (select auth.uid()) makes the planner evaluate it a single time per query.
-- Identical security, far cheaper at scale.

-- 1. Security: lock the definer functions to their triggers only.
revoke execute on function public.handle_new_user() from anon, authenticated, public;
revoke execute on function public.rls_auto_enable() from anon, authenticated, public;

-- 2. Performance: profiles policies.
alter policy "profiles self-select" on public.profiles
    using ((select auth.uid()) = user_id);
alter policy "profiles self-insert" on public.profiles
    with check ((select auth.uid()) = user_id);
alter policy "profiles self-update" on public.profiles
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

-- 3. Performance: progress policies.
alter policy "progress self-select" on public.progress
    using ((select auth.uid()) = user_id);
alter policy "progress self-insert" on public.progress
    with check ((select auth.uid()) = user_id);
alter policy "progress self-update" on public.progress
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

-- 4. Performance: storage (user-media) policies. Not flagged by the advisor, but
-- the same per-row auth.uid() pattern, so wrap it here too.
alter policy "user-media own read" on storage.objects
    using (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
alter policy "user-media own insert" on storage.objects
    with check (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
alter policy "user-media own update" on storage.objects
    using (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text)
    with check (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
alter policy "user-media own delete" on storage.objects
    using (bucket_id = 'user-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
