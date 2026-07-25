-- Chat overview: thread identity, read state, mentions, references, search.
--
-- The chat spine (messages/attachments/photo_annotations, project thread =
-- task_id null) is unchanged; everything here is additive on top of it.
--
-- The one structural idea: give a message an explicit thread identity
-- (thread_id = coalesce(task_id, project_id)). It removes the
-- "task_id is null" gymnastics from every query and index — both clients
-- currently filter realtime rows in JS to work around it — and gives the read
-- model a single join key.
--
-- Ordering note: every ALTER TABLE on public.messages is in this one migration
-- because the STORED generated columns rewrite the table and take an ACCESS
-- EXCLUSIVE lock. Doing it once is the difference between one blip and four.

-- ============================================================ 0. extensions
-- German stemming needs a config; unaccent folds umlauts so "Lüftung" and
-- "Lueftung" match. pg_trgm is the compound-word fallback (see the note on
-- search below).
create extension if not exists unaccent with schema extensions;
create extension if not exists pg_trgm with schema extensions;

create text search configuration public.german_unaccent (copy = pg_catalog.german);
alter text search configuration public.german_unaccent
  alter mapping for hword, hword_part, word
  with extensions.unaccent, german_stem;

-- ============================================================== 1. messages
-- thread_id is generated, so a client cannot forge it and no trigger guard is
-- needed. The media flags let the inbox filter "has photo / has voice" without
-- joining attachments.
alter table public.messages
  add column thread_id uuid generated always as (coalesce(task_id, project_id)) stored,
  add column has_photo boolean not null default false,
  add column has_voice boolean not null default false,
  add column has_video boolean not null default false,
  add column search_tsv tsvector
    generated always as (to_tsvector('public.german_unaccent', coalesce(body, ''))) stored;

create index messages_thread_created_idx
  on public.messages (thread_id, created_at desc, id desc) where deleted_at is null;
create index messages_sender_created_idx
  on public.messages (sender_id, created_at desc) where deleted_at is null;
create index messages_project_sender_created_idx
  on public.messages (project_id, sender_id, created_at desc) where deleted_at is null;
create index messages_search_idx on public.messages using gin (search_tsv);
-- Snowball does not decompose German compounds: a search for "Rohr" will never
-- match "Lüftungsrohr" through FTS. Prefix queries cover the head of a compound;
-- this trigram index covers the tail and middle. Proper decompounding needs
-- hunspell dictionary files, which Supabase-hosted does not allow.
create index messages_body_trgm_idx on public.messages
  using gin (body extensions.gin_trgm_ops) where body is not null;

-- Attachments have a direct INSERT grant, so the flags are maintained by
-- trigger rather than inside send_message — they stay true whatever the path.
create or replace function app.sync_message_media_flags()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.messages m
     set has_photo = m.has_photo or new.kind = 'photo',
         has_voice = m.has_voice or new.kind = 'voice',
         has_video = m.has_video or new.kind = 'video'
   where m.id = new.message_id;
  return null;
end; $$;

create trigger sync_message_media_flags after insert on public.attachments
  for each row execute function app.sync_message_media_flags();

update public.messages m set
  has_photo = exists (select 1 from public.attachments a where a.message_id = m.id and a.kind = 'photo'),
  has_voice = exists (select 1 from public.attachments a where a.message_id = m.id and a.kind = 'voice'),
  has_video = exists (select 1 from public.attachments a where a.message_id = m.id and a.kind = 'video');

-- ========================================================== 2. thread_state
-- One denormalized row per thread. The inbox is then a bounded scan of
-- ~#threads rows instead of an aggregate over the whole message history.
create table public.thread_state (
  thread_id uuid primary key,
  company_id uuid not null references public.companies (id) on delete cascade,
  project_id uuid not null references public.projects (id) on delete cascade,
  task_id uuid references public.tasks (id) on delete cascade,
  message_count integer not null default 0,
  last_message_id uuid references public.messages (id) on delete set null,
  last_message_at timestamptz,
  last_sender_id uuid references public.profiles (id) on delete set null,
  last_kind public.message_kind,
  last_preview text,
  last_expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index thread_state_company_recent_idx on public.thread_state (company_id, last_message_at desc);
create index thread_state_project_recent_idx on public.thread_state (project_id, last_message_at desc);

create or replace function app.sync_thread_state()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.thread_state as ts
    (thread_id, company_id, project_id, task_id, message_count,
     last_message_id, last_message_at, last_sender_id, last_kind, last_preview, last_expires_at)
  values (new.thread_id, new.company_id, new.project_id, new.task_id, 1,
          new.id, new.created_at, new.sender_id, new.kind,
          left(coalesce(new.body, ''), 140), new.expires_at)
  on conflict (thread_id) do update set
    message_count   = ts.message_count + 1,
    last_message_id = excluded.last_message_id,
    last_message_at = excluded.last_message_at,
    last_sender_id  = excluded.last_sender_id,
    last_kind       = excluded.last_kind,
    last_preview    = excluded.last_preview,
    last_expires_at = excluded.last_expires_at;
  return null;
end; $$;

create trigger sync_thread_state after insert on public.messages
  for each row execute function app.sync_thread_state();

-- Soft-deleting the newest message must not leave its text as the preview.
create or replace function app.resync_thread_state()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    update public.thread_state ts set
      last_message_id = s.id,
      last_message_at = s.created_at,
      last_sender_id  = s.sender_id,
      last_kind       = s.kind,
      last_preview    = left(coalesce(s.body, ''), 140),
      last_expires_at = s.expires_at,
      message_count   = greatest(ts.message_count - 1, 0)
    from (
      select m.id, m.created_at, m.sender_id, m.kind, m.body, m.expires_at
        from public.messages m
       where m.thread_id = new.thread_id and m.deleted_at is null
       order by m.created_at desc, m.id desc
       limit 1
    ) s
    where ts.thread_id = new.thread_id;
  end if;
  return new;
end; $$;

create trigger resync_thread_state after update of deleted_at on public.messages
  for each row execute function app.resync_thread_state();

alter table public.thread_state enable row level security;

-- Customers are excluded outright: last_preview would otherwise leak the text of
-- a message that was never shared_with_customer.
create policy thread_state_select on public.thread_state
  for select to authenticated
  using (
    app.is_member_of_project(project_id)
    and coalesce(app.current_member_role() <> 'customer', false)
  );

-- Read-only for clients; the table is trigger-maintained.
grant select on public.thread_state to authenticated;

insert into public.thread_state (thread_id, company_id, project_id, task_id, message_count,
  last_message_id, last_message_at, last_sender_id, last_kind, last_preview, last_expires_at)
select distinct on (m.thread_id)
  m.thread_id, m.company_id, m.project_id, m.task_id,
  count(*) over (partition by m.thread_id),
  m.id, m.created_at, m.sender_id, m.kind, left(coalesce(m.body, ''), 140), m.expires_at
from public.messages m
where m.deleted_at is null
order by m.thread_id, m.created_at desc, m.id desc;

-- ====================================================== 3. message_mentions
create table public.message_mentions (
  message_id uuid not null references public.messages (id) on delete cascade,
  mentioned_profile_id uuid not null references public.profiles (id) on delete cascade,
  -- Denormalized scope, derived by trigger — never trusted from the client.
  company_id uuid not null references public.companies (id) on delete cascade,
  project_id uuid not null references public.projects (id) on delete cascade,
  start_offset integer,
  length integer,
  acknowledged_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (message_id, mentioned_profile_id)
);

create index message_mentions_open_idx
  on public.message_mentions (mentioned_profile_id, created_at desc) where acknowledged_at is null;
create index message_mentions_person_project_idx
  on public.message_mentions (mentioned_profile_id, project_id, created_at desc);

-- Mentionable = a non-customer of the same company who is on the project.
create or replace function app.can_mention(p_project_id uuid, p_profile_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles pr
    where pr.id = p_profile_id
      and pr.company_id = app.current_company_id()
      and pr.role <> 'customer'
      and (
        exists (select 1 from public.project_members pm
                 where pm.project_id = p_project_id and pm.profile_id = pr.id)
        or pr.role in ('owner', 'manager')
      )
  );
$$;

grant execute on function app.can_mention(uuid, uuid) to authenticated;

create or replace function app.sync_mention_scope()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  select m.company_id, m.project_id into strict new.company_id, new.project_id
  from public.messages m where m.id = new.message_id;

  if not app.can_mention(new.project_id, new.mentioned_profile_id) then
    raise exception 'cannot mention profile % on project %',
      new.mentioned_profile_id, new.project_id;
  end if;

  return new;
end; $$;

create trigger sync_mention_scope before insert on public.message_mentions
  for each row execute function app.sync_mention_scope();

alter table public.message_mentions enable row level security;

create policy message_mentions_select on public.message_mentions
  for select to authenticated
  using (app.can_read_message(message_id));

-- Only the sender of the message may attach mentions to it.
create policy message_mentions_insert on public.message_mentions
  for insert to authenticated
  with check (
    exists (select 1 from public.messages m
             where m.id = message_id and m.sender_id = (select auth.uid()))
  );

-- Acknowledging is the mentioned person's own action.
create policy message_mentions_update_self on public.message_mentions
  for update to authenticated
  using (mentioned_profile_id = (select auth.uid()))
  with check (mentioned_profile_id = (select auth.uid()));

grant select, insert, update on public.message_mentions to authenticated;

-- ========================================================== 4. message_refs
create type public.message_ref_kind as enum ('task', 'attachment');

create table public.message_refs (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages (id) on delete cascade,
  kind public.message_ref_kind not null,
  task_id uuid references public.tasks (id) on delete cascade,
  attachment_id uuid references public.attachments (id) on delete cascade,
  company_id uuid not null references public.companies (id) on delete cascade,
  project_id uuid not null references public.projects (id) on delete cascade,
  start_offset integer,
  length integer,
  created_at timestamptz not null default now(),
  constraint message_refs_one_target check (
    (kind = 'task'       and task_id is not null and attachment_id is null) or
    (kind = 'attachment' and attachment_id is not null and task_id is null)
  ),
  constraint message_refs_unique unique (message_id, kind, task_id, attachment_id)
);

create index message_refs_message_idx on public.message_refs (message_id);
create index message_refs_task_idx
  on public.message_refs (task_id, created_at desc) where task_id is not null;
create index message_refs_attachment_idx
  on public.message_refs (attachment_id, created_at desc) where attachment_id is not null;

-- Scope comes from the message; the target must live in the same project, so a
-- reference can never splice in a title from a project the readers cannot see.
create or replace function app.sync_ref_scope()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  select m.company_id, m.project_id into strict new.company_id, new.project_id
  from public.messages m where m.id = new.message_id;

  if new.kind = 'task' and not exists (
    select 1 from public.tasks t where t.id = new.task_id and t.project_id = new.project_id
  ) then
    raise exception 'referenced task % is not in project %', new.task_id, new.project_id;
  end if;

  if new.kind = 'attachment' and not exists (
    select 1 from public.attachments a
    join public.messages tm on tm.id = a.message_id
    where a.id = new.attachment_id and tm.project_id = new.project_id
  ) then
    raise exception 'referenced attachment % is not in project %', new.attachment_id, new.project_id;
  end if;

  return new;
end; $$;

create trigger sync_ref_scope before insert on public.message_refs
  for each row execute function app.sync_ref_scope();

alter table public.message_refs enable row level security;

create policy message_refs_select on public.message_refs
  for select to authenticated
  using (app.can_read_message(message_id));

create policy message_refs_insert on public.message_refs
  for insert to authenticated
  with check (
    exists (select 1 from public.messages m
             where m.id = message_id and m.sender_id = (select auth.uid()))
  );

grant select, insert on public.message_refs to authenticated;

-- ==================================================== 5. thread_read_state
-- The unread mechanism is a per-(person, thread) cursor, not message_reads.
-- Counting through message_reads would need an anti-join over every message;
-- message_reads stays in the schema and is reserved for "seen by" receipts so
-- the two read models never drift.
create table public.thread_read_state (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  thread_id uuid not null,
  last_read_at timestamptz not null default now(),
  last_read_message_id uuid references public.messages (id) on delete set null,
  muted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (profile_id, thread_id)
);

alter table public.thread_read_state enable row level security;

create policy thread_read_state_all_self on public.thread_read_state
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

grant select, insert, update, delete on public.thread_read_state to authenticated;

-- SECURITY INVOKER on purpose: the policy above plus message_mentions_update_self
-- are the authorization. A cursor for a thread you cannot read is inert.
create or replace function public.mark_thread_read(
  p_thread_id uuid,
  p_up_to timestamptz default now()
) returns void
language plpgsql
set search_path = ''
as $$
declare
  v_up_to timestamptz := least(coalesce(p_up_to, now()), now());
begin
  insert into public.thread_read_state (profile_id, thread_id, last_read_at, updated_at)
  values ((select auth.uid()), p_thread_id, v_up_to, now())
  on conflict (profile_id, thread_id) do update
    set last_read_at = greatest(public.thread_read_state.last_read_at, excluded.last_read_at),
        updated_at = now();

  -- Opening a thread clears its mentions from the attention list.
  update public.message_mentions mn
     set acknowledged_at = now()
    from public.messages m
   where mn.message_id = m.id
     and m.thread_id = p_thread_id
     and mn.mentioned_profile_id = (select auth.uid())
     and mn.acknowledged_at is null
     and m.created_at <= v_up_to;
end; $$;

revoke execute on function public.mark_thread_read(uuid, timestamptz) from public, anon;
grant execute on function public.mark_thread_read(uuid, timestamptz) to authenticated;

-- Seed so existing members do not wake up to a wall of unread.
insert into public.thread_read_state (profile_id, thread_id, last_read_at)
select p.id, ts.thread_id, now()
from public.profiles p
join public.thread_state ts on ts.company_id = p.company_id
where p.role <> 'customer'
on conflict do nothing;

-- ======================================================= 6. send_message v2
-- CREATE OR REPLACE cannot add parameters — it would leave a second overload and
-- PostgREST then fails EVERY send_message call with an ambiguous-function error.
-- Drop and recreate in the same transaction, then re-apply the grants.
drop function public.send_message(uuid, uuid, public.message_kind, text, jsonb, boolean, timestamptz);

create or replace function public.send_message(
  p_project_id uuid,
  p_task_id uuid default null,
  p_kind public.message_kind default 'text',
  p_body text default null,
  p_attachments jsonb default '[]',
  p_shared_with_customer boolean default false,
  p_expires_at timestamptz default null,
  -- [{"profile_id":uuid,"start_offset":int,"length":int}]
  p_mentions jsonb default '[]',
  -- [{"kind":"task","task_id":uuid,"start_offset":int,"length":int}]
  p_refs jsonb default '[]'
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_message_id uuid;
  v_att jsonb;
begin
  if jsonb_typeof(coalesce(p_attachments, '[]'::jsonb)) <> 'array' then
    raise exception 'p_attachments must be a JSON array';
  end if;

  insert into public.messages
    (company_id, project_id, task_id, sender_id, kind, body, shared_with_customer, expires_at)
  values
    -- company_id placeholder: the sync_message_company trigger derives the real
    -- value from the project before constraints/RLS checks run.
    ('00000000-0000-0000-0000-000000000000', p_project_id, p_task_id,
     (select auth.uid()), p_kind, nullif(trim(p_body), ''), p_shared_with_customer, p_expires_at)
  returning id into v_message_id;

  for v_att in select * from jsonb_array_elements(coalesce(p_attachments, '[]'::jsonb))
  loop
    insert into public.attachments
      (message_id, kind, storage_bucket, storage_path, mime_type,
       byte_size, width, height, duration_seconds, waveform)
    values
      (v_message_id,
       (v_att ->> 'kind')::public.attachment_kind,
       v_att ->> 'storage_bucket',
       v_att ->> 'storage_path',
       v_att ->> 'mime_type',
       (v_att ->> 'byte_size')::bigint,
       (v_att ->> 'width')::int,
       (v_att ->> 'height')::int,
       (v_att ->> 'duration_seconds')::double precision,
       v_att -> 'waveform');
  end loop;

  -- Scope placeholders are overwritten by the sync_* BEFORE triggers, same
  -- pattern as company_id above.
  insert into public.message_mentions
    (message_id, mentioned_profile_id, company_id, project_id, start_offset, length)
  select v_message_id, (e ->> 'profile_id')::uuid,
         '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000',
         (e ->> 'start_offset')::int, (e ->> 'length')::int
  from jsonb_array_elements(coalesce(p_mentions, '[]'::jsonb)) as e
  on conflict do nothing;

  insert into public.message_refs
    (message_id, kind, task_id, attachment_id, company_id, project_id, start_offset, length)
  select v_message_id, (e ->> 'kind')::public.message_ref_kind,
         (e ->> 'task_id')::uuid, (e ->> 'attachment_id')::uuid,
         '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000',
         (e ->> 'start_offset')::int, (e ->> 'length')::int
  from jsonb_array_elements(coalesce(p_refs, '[]'::jsonb)) as e;

  return v_message_id;
end; $$;

revoke execute on function public.send_message(
  uuid, uuid, public.message_kind, text, jsonb, boolean, timestamptz, jsonb, jsonb
) from public, anon;
grant execute on function public.send_message(
  uuid, uuid, public.message_kind, text, jsonb, boolean, timestamptz, jsonb, jsonb
) to authenticated;

-- ============================================================= 7. realtime
-- Two extra channels per client: thread_state filtered by company_id drives the
-- inbox, message_mentions filtered by mentioned_profile_id drives the attention
-- badge. Clients must never subscribe to public.messages company-wide.
alter publication supabase_realtime add table public.thread_state;
alter publication supabase_realtime add table public.message_mentions;
