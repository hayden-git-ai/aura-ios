-- Private Storage bucket for the user's own photos: Wall-of-Wins proof shots and
-- the profile picture. Personal images, so the bucket is private and reached only
-- through the authenticated client, never a public URL.
--
-- Objects are owner-scoped by path: the first folder is the user id, e.g.
--   <uid>/wins/<win_id>.jpg
--   <uid>/avatar.jpg
-- and every policy checks that first path segment against auth.uid(), so a user
-- can only ever touch objects under their own prefix.

insert into storage.buckets (id, name, public)
values ('user-media', 'user-media', false)
on conflict (id) do nothing;

create policy "user-media own read" on storage.objects
    for select to authenticated
    using (bucket_id = 'user-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "user-media own insert" on storage.objects
    for insert to authenticated
    with check (bucket_id = 'user-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "user-media own update" on storage.objects
    for update to authenticated
    using (bucket_id = 'user-media' and (storage.foldername(name))[1] = auth.uid()::text)
    with check (bucket_id = 'user-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "user-media own delete" on storage.objects
    for delete to authenticated
    using (bucket_id = 'user-media' and (storage.foldername(name))[1] = auth.uid()::text);
