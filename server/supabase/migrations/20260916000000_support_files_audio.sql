-- Local preparation only: deploy with the compatible support-send validator.
-- Keep the existing private bucket, owner-scoped policies and 10 MB limit.
update storage.buckets
set file_size_limit = 10485760,
    allowed_mime_types = array[
      'image/jpeg', 'image/png', 'image/heic', 'image/heif',
      'application/pdf', 'text/plain',
      'audio/mp4', 'audio/x-m4a', 'audio/aac', 'audio/mpeg', 'audio/wav', 'audio/x-wav'
    ]
where id = 'user-media';
