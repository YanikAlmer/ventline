-- Storage buckets and object policies. All buckets are private; clients read
-- through short-lived signed URLs. The path convention drives every policy:
--
--   photos/voice/video:  {company_id}/{project_id}/{message_id}/{uuid}.{ext}
--   avatars:             {profile_id}.jpg

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('photos',  'photos',  false,  10 * 1024 * 1024, array['image/jpeg', 'image/png', 'image/heic', 'image/webp']),
  ('voice',   'voice',   false,  20 * 1024 * 1024, array['audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac', 'audio/mpeg']),
  ('video',   'video',   false, 200 * 1024 * 1024, array['video/mp4', 'video/quicktime']),
  ('avatars', 'avatars', false,   5 * 1024 * 1024, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Path segment -> uuid without throwing on malformed paths (a bad cast inside
-- a policy would abort unrelated queries with an error instead of denying).
create or replace function app.safe_uuid(p text)
returns uuid
language plpgsql immutable
set search_path = ''
as $$
begin
  return p::uuid;
exception when others then
  return null;
end;
$$;

grant execute on function app.safe_uuid(text) to authenticated;

-- Uploads: path must start with the uploader's own company id, target a
-- project they can write to, and (media buckets) carry a well-formed path.
create policy media_objects_insert on storage.objects
  for insert to authenticated
  with check (
    (
      bucket_id in ('photos', 'voice', 'video')
      and (storage.foldername(name))[1] = app.current_company_id()::text
      and app.can_write_project(app.safe_uuid((storage.foldername(name))[2]))
    )
    or (
      bucket_id = 'avatars'
      and name like (select auth.uid())::text || '.%'
      and app.current_member_role() is not null
    )
  );

-- Reads: working members read everything in their projects; customers only
-- objects referenced by messages shared with them; avatars are visible
-- within the company.
create policy media_objects_select on storage.objects
  for select to authenticated
  using (
    (
      bucket_id in ('photos', 'voice', 'video')
      and (
        (
          app.current_member_role() not in ('customer')
          and app.is_member_of_project(app.safe_uuid((storage.foldername(name))[2]))
        )
        or app.customer_can_read_object(bucket_id, name)
      )
    )
    or (
      bucket_id = 'avatars'
      and exists (
        select 1 from public.profiles pr
        where pr.id = app.safe_uuid(split_part(name, '.', 1))
          and pr.company_id = app.current_company_id()
      )
    )
  );

-- Uploader may replace/remove their own objects (e.g. retrying a failed
-- send, updating an avatar).
create policy media_objects_update_own on storage.objects
  for update to authenticated
  using (owner_id = (select auth.uid())::text)
  with check (owner_id = (select auth.uid())::text);

create policy media_objects_delete_own on storage.objects
  for delete to authenticated
  using (owner_id = (select auth.uid())::text);
