-- Chat spine. The schema supports every milestone-2 feature from day one:
-- video attachments, disappearing messages (expires_at), read receipts,
-- push notification device registry.

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  project_id uuid not null references public.projects (id) on delete cascade,
  -- null => project-level thread; otherwise a task thread.
  task_id uuid references public.tasks (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  kind public.message_kind not null default 'text',
  -- Text body, or caption for media messages. May be null for pure media sends.
  body text check (body is null or char_length(body) <= 8000),
  -- Curated customer portal visibility.
  shared_with_customer boolean not null default false,
  -- Disappearing messages: RLS filters expired rows from day one; hard
  -- purge is milestone 2 (purge_expired_messages + cleanup edge function).
  expires_at timestamptz,
  reply_to_message_id uuid references public.messages (id) on delete set null,
  edited_at timestamptz,
  -- Soft delete (office roles); hard delete only via service-role purge.
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  -- A message belongs to exactly one chat thread; require text content for
  -- text/system, so empty messages can't be sent.
  constraint messages_text_has_body check (kind not in ('text', 'system') or body is not null)
);

create index messages_task_created_idx on public.messages (task_id, created_at desc);
create index messages_project_created_idx on public.messages (project_id, created_at desc);
create index messages_expiring_idx on public.messages (expires_at) where expires_at is not null;

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages (id) on delete cascade,
  kind public.attachment_kind not null,
  storage_bucket text not null,
  storage_path text not null,
  mime_type text not null,
  byte_size bigint,
  width integer,
  height integer,
  -- voice / video
  duration_seconds double precision,
  -- Precomputed amplitude bars for voice bubbles: [0..1] floats.
  waveform jsonb,
  created_at timestamptz not null default now()
);

create index attachments_message_idx on public.attachments (message_id);

-- Markup drawn over a photo attachment. Stores BOTH the editable vector data
-- (PencilKit PKDrawing, re-openable on iOS) and a flattened rendered JPEG
-- (displayable on web / customer portal with zero canvas code).
create table public.photo_annotations (
  id uuid primary key default gen_random_uuid(),
  attachment_id uuid not null references public.attachments (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  -- {"format":"pencilkit-v1","canvas":{"w":int,"h":int},"pkdrawing_base64":"..."}
  drawing_data jsonb not null,
  rendered_path text not null,
  created_at timestamptz not null default now()
);

create index photo_annotations_attachment_idx on public.photo_annotations (attachment_id);

-- Read receipts — schema now, UI milestone 2.
create table public.message_reads (
  message_id uuid not null references public.messages (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, profile_id)
);

-- Push targets — registration in milestone 1 is optional, sending is milestone 2.
create table public.devices (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  platform public.device_platform not null,
  apns_token text not null,
  updated_at timestamptz not null default now(),
  unique (profile_id, apns_token)
);

-- Storage paths orphaned by hard deletes/expiry, drained by the
-- cleanup-expired-media edge function (milestone 2). Service-role only.
create table public.media_deletion_queue (
  id bigint generated always as identity primary key,
  storage_bucket text not null,
  storage_path text not null,
  enqueued_at timestamptz not null default now()
);

grant select, insert, update on public.messages to authenticated; -- no client hard deletes
grant select, insert on public.attachments to authenticated;
grant select, insert on public.photo_annotations to authenticated;
grant select, insert on public.message_reads to authenticated;
grant select, insert, update, delete on public.devices to authenticated;
-- media_deletion_queue: intentionally no grants to API roles.
