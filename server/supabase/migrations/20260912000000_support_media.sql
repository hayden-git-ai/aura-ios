-- Rich media on support messages. A message is either text (media_url null) or a
-- media message (media_url set, text optionally used as a caption). `media_mime`
-- lets the app decide how to render it (image / video / audio / file), and
-- `media_name` is the original filename for file downloads.
--
-- Outbound (user) media is uploaded to Storage and passed as a signed URL that
-- Crisp can fetch; inbound (operator) media carries Crisp's own CDN URL.

alter table public.support_messages
    add column if not exists media_url  text,
    add column if not exists media_mime text,
    add column if not exists media_name text;
