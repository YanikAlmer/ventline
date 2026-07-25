-- Push notifications: transactional outbox, recipient resolution, delivery.
--
-- Architecture: row triggers INSERT into notification_outbox inside the same
-- transaction as the write, so a notification is never produced for a
-- rolled-back message and never lost. A statement-level trigger then fires one
-- payload-free "nudge" at the edge function via pg_net, and pg_cron drains
-- every minute as a safety net. Deadline reminders need scheduling anyway, so
-- one mechanism covers both instead of two unrelated code paths.
--
-- Rejected: raw Database Webhooks (fire-and-forget, no retry, no dedupe, and
-- cannot express deadline reminders) and polling (0-60s latency is not
-- acceptable for jobsite chat).
--
-- Reconciliation note: the read cursor is public.thread_read_state from
-- 20260726090000. This migration deliberately does NOT add a second cursor
-- table — two unread models would drift, which is the same trap message_reads
-- was demoted to avoid.

-- =========================================================== 0. extensions
-- Guarded: a plain Postgres (scripts/db-validate.sh) has neither extension.
-- scripts/auth-shim.sql stubs the net/cron surface so the migration still
-- applies and the trigger paths stay under test locally.
do $$
begin
  create extension if not exists pg_net with schema extensions;
exception when others then
  raise notice 'pg_net unavailable — nudges will no-op (expected off-Supabase)';
end $$;

do $$
begin
  create extension if not exists pg_cron with schema cron;
exception when others then
  raise notice 'pg_cron unavailable — using shim (expected off-Supabase)';
end $$;

-- The function URL and shared secret live in Vault, never inline in a function
-- body. Set once per environment, out of band:
--   select vault.create_secret('https://<ref>.supabase.co/functions/v1/notify-push',
--                              'notify_push_url');
--   select vault.create_secret('<32 random bytes>', 'notify_push_secret');

-- ============================================================== 1. devices
-- The table shipped in 20260707000500 but no client ever wrote to it, so there
-- is nothing to preserve. install_id is what makes re-registration idempotent
-- across reinstalls and token rotation.
delete from public.devices;

alter table public.devices rename column apns_token to push_token;

alter table public.devices
  add column install_id uuid not null,
  add column apns_environment text not null default 'production'
     check (apns_environment in ('sandbox', 'production')),
  add column locale text not null default 'de',
  add column app_version text,
  add column created_at timestamptz not null default now(),
  add column last_seen_at timestamptz not null default now(),
  add constraint devices_install_id_key unique (install_id);

create index devices_profile_idx on public.devices (profile_id);

-- Registration has to be able to take an install_id or token away from a
-- previously signed-in profile. The devices RLS policy (profile_id = auth.uid())
-- correctly stops a client doing that itself, so it happens in a definer RPC:
-- otherwise signing out of A and into B keeps delivering A's jobsite chat to
-- B's lock screen.
create or replace function public.register_device(
  p_install_id uuid,
  p_platform public.device_platform,
  p_push_token text,
  p_apns_environment text default 'production',
  p_locale text default 'de',
  p_app_version text default null
) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_id uuid;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if p_apns_environment not in ('sandbox', 'production') then
    raise exception 'invalid apns environment';
  end if;
  if nullif(trim(p_push_token), '') is null then
    raise exception 'push token required';
  end if;

  delete from public.devices
   where (install_id = p_install_id or push_token = p_push_token)
     and profile_id <> v_user;

  insert into public.devices
    (profile_id, install_id, platform, push_token, apns_environment,
     locale, app_version, updated_at, last_seen_at)
  values
    (v_user, p_install_id, p_platform, p_push_token, p_apns_environment,
     p_locale, p_app_version, now(), now())
  on conflict (install_id) do update set
    profile_id       = excluded.profile_id,
    platform         = excluded.platform,
    push_token       = excluded.push_token,
    apns_environment = excluded.apns_environment,
    locale           = excluded.locale,
    app_version      = excluded.app_version,
    updated_at       = now(),
    last_seen_at     = now()
  returning id into v_id;

  return v_id;
end; $$;

revoke execute on function public.register_device(
  uuid, public.device_platform, text, text, text, text) from public, anon;
grant execute on function public.register_device(
  uuid, public.device_platform, text, text, text, text) to authenticated;

-- ========================================================== 2. preferences
create table public.notification_prefs (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  push_enabled          boolean not null default true,
  chat_enabled          boolean not null default true,
  mentions_enabled      boolean not null default true,
  task_assigned_enabled boolean not null default true,
  task_status_enabled   boolean not null default true,
  deadlines_enabled     boolean not null default true,
  -- Office roles can read every company project through RLS, but notifications
  -- follow explicit project_members rows. This opts them back into everything;
  -- default true because in a 5-30 person KMU the owner IS the dispatcher.
  watch_all_projects    boolean not null default true,
  -- Quiet hours never DROP a notification. They strip the sound and drop the
  -- APNs priority so it waits silently until morning — nobody wants a jobsite
  -- ping at 22:00, but nobody wants to lose it either.
  quiet_hours_enabled   boolean not null default true,
  quiet_hours_start     time not null default '21:00',
  quiet_hours_end       time not null default '06:00',
  time_zone             text not null default 'Europe/Zurich',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_updated_at before update on public.notification_prefs
  for each row execute function app.set_updated_at();

insert into public.notification_prefs (profile_id)
select id from public.profiles
on conflict do nothing;

create or replace function app.create_notification_prefs()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notification_prefs (profile_id) values (new.id)
  on conflict do nothing;
  return new;
end; $$;

create trigger create_notification_prefs after insert on public.profiles
  for each row execute function app.create_notification_prefs();

alter table public.notification_prefs enable row level security;

create policy notification_prefs_all_self on public.notification_prefs
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

grant select, insert, update on public.notification_prefs to authenticated;

-- Per-project mute. thread_read_state.muted already mutes a single thread;
-- this is the coarser "I am not on this site this month" control.
create table public.project_notification_mutes (
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  project_id  uuid not null references public.projects (id) on delete cascade,
  muted_until timestamptz,   -- null = until explicitly unmuted
  created_at  timestamptz not null default now(),
  primary key (profile_id, project_id)
);

alter table public.project_notification_mutes enable row level security;

create policy project_notification_mutes_select on public.project_notification_mutes
  for select to authenticated using (profile_id = (select auth.uid()));

create policy project_notification_mutes_insert on public.project_notification_mutes
  for insert to authenticated
  with check (profile_id = (select auth.uid()) and app.is_member_of_project(project_id));

create policy project_notification_mutes_update on public.project_notification_mutes
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

create policy project_notification_mutes_delete on public.project_notification_mutes
  for delete to authenticated using (profile_id = (select auth.uid()));

grant select, insert, update, delete on public.project_notification_mutes to authenticated;

-- =============================================================== 3. outbox
create type public.notification_kind as enum (
  'chat_message', 'mention', 'task_assigned',
  'task_status', 'task_due_soon', 'task_overdue'
);

create type public.notification_status as enum (
  'pending', 'sending', 'sent', 'failed', 'skipped', 'expired'
);

create table public.notification_outbox (
  id          uuid primary key default gen_random_uuid(),
  kind        public.notification_kind not null,
  company_id  uuid not null references public.companies (id) on delete cascade,
  project_id  uuid not null references public.projects (id) on delete cascade,
  task_id     uuid references public.tasks (id) on delete cascade,
  message_id  uuid references public.messages (id) on delete cascade,
  -- Who caused it. Never notified about their own action.
  actor_id    uuid references public.profiles (id) on delete set null,
  -- Set when there is one obvious recipient (task_assigned); null => resolve.
  target_id   uuid references public.profiles (id) on delete cascade,
  payload     jsonb not null default '{}',
  dedupe_key  text not null,
  status      public.notification_status not null default 'pending',
  attempts    integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error  text,
  created_at  timestamptz not null default now(),
  processed_at timestamptz
);

create unique index notification_outbox_dedupe_idx
  on public.notification_outbox (dedupe_key);
create index notification_outbox_due_idx
  on public.notification_outbox (next_attempt_at) where status = 'pending';

alter table public.notification_outbox enable row level security;
-- No policies and no grants: service role only, same as media_deletion_queue.

-- ================================================ 4. visibility (one source)
-- The same predicate as the messages_select RLS policy, but evaluated for an
-- arbitrary profile rather than the caller — the drain runs with auth.uid()
-- null, so it cannot rely on the policy itself.
create or replace function app.can_profile_read_message(
  p_profile_id uuid, p_message_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.messages m
    join public.profiles pr on pr.id = p_profile_id
    where m.id = p_message_id
      and m.deleted_at is null
      and (m.expires_at is null or m.expires_at > now())
      and pr.company_id = m.company_id
      and (
        exists (select 1 from public.project_members pm
                 where pm.project_id = m.project_id and pm.profile_id = pr.id)
        or pr.role in ('owner', 'manager')
      )
      and (pr.role <> 'customer' or m.shared_with_customer)
  );
$$;

-- The existing helper now delegates, so there is exactly one definition of
-- "may this person read this message". Behaviour is unchanged for every policy
-- that already references it.
create or replace function app.can_read_message(p_message_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select app.can_profile_read_message((select auth.uid()), p_message_id);
$$;

grant execute on function app.can_profile_read_message(uuid, uuid) to authenticated;

-- Absolute badge value: APNs cannot increment. Counted off thread_read_state,
-- the cursor shipped with the chat overview. The 30-day floor bounds the cost
-- for someone who has never opened a thread.
create or replace function app.unread_count(p_profile_id uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(count(*), 0)::int
  from public.messages m
  join public.project_members pm
    on pm.project_id = m.project_id and pm.profile_id = p_profile_id
  left join public.thread_read_state tr
    on tr.profile_id = p_profile_id and tr.thread_id = m.thread_id
  where m.sender_id <> p_profile_id
    and m.deleted_at is null
    and (m.expires_at is null or m.expires_at > now())
    and m.created_at > greatest(coalesce(tr.last_read_at, '-infinity'::timestamptz),
                                now() - interval '30 days');
$$;

-- ================================================== 5. recipient resolution
-- Handles a window that crosses midnight (21:00 -> 06:00).
create or replace function app.in_quiet_hours(p_tz text, p_start time, p_end time)
returns boolean language sql stable set search_path = '' as $$
  select case
    when p_start = p_end then false
    when p_start <  p_end then (now() at time zone p_tz)::time >= p_start
                           and (now() at time zone p_tz)::time <  p_end
    else (now() at time zone p_tz)::time >= p_start
      or (now() at time zone p_tz)::time <  p_end
  end;
$$;

create or replace function app.notification_recipients(
  p_kind       public.notification_kind,
  p_company_id uuid,
  p_project_id uuid,
  p_task_id    uuid,
  p_message_id uuid,
  p_actor_id   uuid,
  p_target_id  uuid
) returns table (profile_id uuid, passive boolean, badge integer)
language sql stable security definer set search_path = '' as $$
with candidate as (
  -- explicit single target (task_assigned)
  select p_target_id as pid where p_target_id is not null
  union
  -- anyone assigned to the task: task threads, status changes, deadlines
  select ta.profile_id from public.task_assignments ta
   where p_target_id is null and p_task_id is not null and ta.task_id = p_task_id
  union
  -- project-level chat reaches every explicit member
  select pm.profile_id from public.project_members pm
   where p_target_id is null and p_kind = 'chat_message'
     and p_task_id is null and pm.project_id = p_project_id
  union
  -- supervision: foremen on this project, office who watch everything
  select pr.id
    from public.profiles pr
    left join public.project_members pm
      on pm.profile_id = pr.id and pm.project_id = p_project_id
    left join public.notification_prefs np on np.profile_id = pr.id
   where p_target_id is null
     and pr.company_id = p_company_id
     and (
       (pr.role = 'foreman' and pm.profile_id is not null)
       or (pr.role in ('owner', 'manager') and coalesce(np.watch_all_projects, true))
     )
),
eligible as (
  select
    pr.id,
    coalesce(np.time_zone, 'Europe/Zurich')      as tz,
    coalesce(np.quiet_hours_enabled, true)       as quiet_on,
    coalesce(np.quiet_hours_start, time '21:00') as quiet_start,
    coalesce(np.quiet_hours_end,   time '06:00') as quiet_end
  from candidate c
  join public.profiles pr on pr.id = c.pid
  left join public.notification_prefs np on np.profile_id = pr.id
  where pr.id is distinct from p_actor_id
    -- HARD RULE: a customer is never in an internal notification audience.
    and pr.role <> 'customer'
    and coalesce(np.push_enabled, true)
    and case p_kind
          when 'chat_message'  then coalesce(np.chat_enabled, true)
          when 'mention'       then coalesce(np.mentions_enabled, true)
          when 'task_assigned' then coalesce(np.task_assigned_enabled, true)
          when 'task_status'   then coalesce(np.task_status_enabled, true)
          else                      coalesce(np.deadlines_enabled, true)
        end
    and not exists (
      select 1 from public.project_notification_mutes mu
      where mu.profile_id = pr.id and mu.project_id = p_project_id
        and (mu.muted_until is null or mu.muted_until > now()))
    -- Braces: the same predicate the RLS policy would apply, for the recipient.
    and (p_message_id is null or app.can_profile_read_message(pr.id, p_message_id))
    and (p_task_id is null
         or exists (select 1 from public.tasks t
                     where t.id = p_task_id
                       and (pr.role <> 'customer' or t.visible_to_customer)))
    -- Somewhere to actually deliver it.
    and exists (select 1 from public.devices d where d.profile_id = pr.id)
)
select e.id,
       e.quiet_on and app.in_quiet_hours(e.tz, e.quiet_start, e.quiet_end) as passive,
       app.unread_count(e.id) as badge
from eligible e;
$$;

-- ===================================================== 6. enqueue + nudge
-- Fire-and-forget wake-up. Never blocks or fails the write that caused it: a
-- failed nudge only makes delivery late, because the per-minute drain picks
-- the row up regardless.
create or replace function app.nudge_notifier()
returns void language plpgsql security definer set search_path = '' as $$
declare v_url text; v_secret text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'notify_push_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'notify_push_secret';
  if v_url is null or v_secret is null then return; end if;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'x-ventline-notify-secret', v_secret),
    body    := jsonb_build_object('trigger', 'nudge'),
    timeout_milliseconds := 3000);
exception when others then
  return;
end; $$;

create or replace function app.nudge_notifier_stmt()
returns trigger language plpgsql security definer set search_path = '' as $$
begin perform app.nudge_notifier(); return null; end; $$;

-- chat messages ---------------------------------------------------------
create or replace function app.enqueue_notification_message()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- 'system' rows would duplicate the task_status push for the same event.
  if new.kind = 'system' then return new; end if;

  insert into public.notification_outbox
    (kind, company_id, project_id, task_id, message_id, actor_id, dedupe_key, payload)
  values
    ('chat_message', new.company_id, new.project_id, new.task_id, new.id,
     new.sender_id, 'msg:' || new.id::text,
     jsonb_build_object('message_kind', new.kind, 'expires_at', new.expires_at))
  on conflict (dedupe_key) do nothing;
  return new;
end; $$;

create trigger enqueue_notification after insert on public.messages
  for each row execute function app.enqueue_notification_message();
create trigger nudge_notifier after insert on public.messages
  for each statement execute function app.nudge_notifier_stmt();

-- mentions --------------------------------------------------------------
create or replace function app.enqueue_notification_mention()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_actor uuid;
begin
  select m.sender_id into v_actor from public.messages m where m.id = new.message_id;

  insert into public.notification_outbox
    (kind, company_id, project_id, task_id, message_id, actor_id, target_id, dedupe_key)
  select 'mention', new.company_id, new.project_id, m.task_id, new.message_id,
         v_actor, new.mentioned_profile_id,
         'mention:' || new.message_id::text || ':' || new.mentioned_profile_id::text
    from public.messages m where m.id = new.message_id
  on conflict (dedupe_key) do nothing;
  return new;
end; $$;

create trigger enqueue_notification after insert on public.message_mentions
  for each row execute function app.enqueue_notification_mention();

-- task assignment -------------------------------------------------------
create or replace function app.enqueue_notification_task_assigned()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notification_outbox
    (kind, company_id, project_id, task_id, actor_id, target_id, dedupe_key)
  select 'task_assigned', t.company_id, t.project_id, t.id,
         coalesce(new.assigned_by, (select auth.uid())), new.profile_id,
         'assign:' || new.task_id::text || ':' || new.profile_id::text
    from public.tasks t where t.id = new.task_id
  on conflict (dedupe_key) do nothing;
  return new;
end; $$;

create trigger enqueue_notification after insert on public.task_assignments
  for each row execute function app.enqueue_notification_task_assigned();
create trigger nudge_notifier after insert on public.task_assignments
  for each statement execute function app.nudge_notifier_stmt();

-- task status -----------------------------------------------------------
create or replace function app.enqueue_notification_task_status()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status is not distinct from old.status then return new; end if;

  insert into public.notification_outbox
    (kind, company_id, project_id, task_id, actor_id, dedupe_key, payload)
  values
    ('task_status', new.company_id, new.project_id, new.id,
     (select auth.uid()),
     'status:' || new.id::text || ':' || new.status::text || ':'
       || extract(epoch from now())::bigint::text,
     jsonb_build_object('status', new.status, 'previous_status', old.status))
  on conflict (dedupe_key) do nothing;
  return new;
end; $$;

create trigger enqueue_notification after update of status on public.tasks
  for each row execute function app.enqueue_notification_task_status();
create trigger nudge_notifier after update of status on public.tasks
  for each statement execute function app.nudge_notifier_stmt();

-- ============================================== 7. claim / settle (edge fn)
create or replace function public.claim_notification_batch(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_ids uuid[]; v_result jsonb;
begin
  with upd as (
    update public.notification_outbox o
       set status = 'sending', attempts = o.attempts + 1
     where o.id in (
       select id from public.notification_outbox
        where status = 'pending' and next_attempt_at <= now()
        order by created_at
        limit p_limit
        for update skip locked)
    returning o.id)
  select array_agg(id) into v_ids from upd;

  if v_ids is null then return '[]'::jsonb; end if;

  select jsonb_agg(to_jsonb(f)) into v_result
  from (
    select o.id, o.kind, o.project_id, o.task_id, o.message_id, o.payload,
           p.name          as project_name,
           t.title         as task_title,
           t.due_date      as task_due_date,
           actor.full_name as actor_name,
           m.kind          as message_kind,
           -- No preview for media: a photo caption must not reach a lock screen.
           case when m.kind = 'text' then left(m.body, 140) end as message_preview,
           r.profile_id, r.passive, r.badge,
           d.id as device_id, d.push_token, d.platform,
           d.apns_environment, d.locale,
           -- Never deliver a push for a message that has already vanished.
           extract(epoch from least(now() + interval '4 hours',
                                    coalesce(m.expires_at, 'infinity')))::bigint
             as expiration_epoch,
           case when o.kind in ('task_status', 'task_due_soon', 'task_overdue')
                then 'task:' || o.task_id::text || ':' || o.kind::text end
             as collapse_id
      from public.notification_outbox o
      join public.projects p          on p.id = o.project_id
      left join public.tasks t        on t.id = o.task_id
      left join public.messages m     on m.id = o.message_id
      left join public.profiles actor on actor.id = o.actor_id
      cross join lateral app.notification_recipients(
        o.kind, o.company_id, o.project_id, o.task_id,
        o.message_id, o.actor_id, o.target_id) r
      join public.devices d on d.profile_id = r.profile_id
     where o.id = any(v_ids)) f;

  -- Rows whose audience resolved empty are finished, not stuck in 'sending'.
  update public.notification_outbox o
     set status = 'skipped', processed_at = now()
   where o.id = any(v_ids)
     and not exists (
       select 1 from jsonb_array_elements(coalesce(v_result, '[]'::jsonb)) e
        where (e ->> 'id')::uuid = o.id);

  return coalesce(v_result, '[]'::jsonb);
end; $$;

-- p_results: [{ id, device_id, ok, retryable, prune, invalid_since, error }]
create or replace function public.settle_notification_batch(p_results jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  -- APNs 410 Unregistered / 400 BadDeviceToken. The invalid_since guard keeps a
  -- token that has been re-registered since Apple invalidated the old one.
  delete from public.devices d
   using jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) e
   where d.id = (e ->> 'device_id')::uuid
     and coalesce((e ->> 'prune')::boolean, false)
     and d.updated_at <= coalesce((e ->> 'invalid_since')::timestamptz, now());

  -- An outbox row is done when no device failed retryably for it.
  update public.notification_outbox o
     set status = 'sent', processed_at = now()
   where o.status = 'sending'
     and o.id in (select (e ->> 'id')::uuid
                    from jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) e)
     and not exists (
       select 1 from jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) e2
        where (e2 ->> 'id')::uuid = o.id
          and coalesce((e2 ->> 'retryable')::boolean, false));

  -- Retryable failures back off exponentially and give up after 6 attempts.
  update public.notification_outbox o
     set status = case when o.attempts >= 6 then 'failed'::public.notification_status
                       else 'pending'::public.notification_status end,
         next_attempt_at = now() + (interval '30 seconds' * power(2, least(o.attempts, 5))),
         last_error = f.err,
         processed_at = case when o.attempts >= 6 then now() end
    from (select (e ->> 'id')::uuid as id, max(e ->> 'error') as err
            from jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) e
           where coalesce((e ->> 'retryable')::boolean, false)
           group by 1) f
   where o.id = f.id and o.status = 'sending';
end; $$;

revoke execute on function public.claim_notification_batch(integer)
  from public, anon, authenticated;
revoke execute on function public.settle_notification_batch(jsonb)
  from public, anon, authenticated;

-- ============================================================ 8. scheduling
create or replace function public.enqueue_due_reminders()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_today date := (now() at time zone 'Europe/Zurich')::date;
  v_count integer := 0;
begin
  -- Only at 06:00 Zurich: after quiet hours, before the crew rolls out. An
  -- hourly cron with a local-hour gate survives the CET/CEST switch, which a
  -- fixed UTC schedule would not.
  if extract(hour from now() at time zone 'Europe/Zurich') <> 6 then
    return 0;
  end if;

  insert into public.notification_outbox
    (kind, company_id, project_id, task_id, dedupe_key, payload)
  select 'task_due_soon', t.company_id, t.project_id, t.id,
         'due:' || t.id::text || ':' || t.due_date::text,
         jsonb_build_object('due_date', t.due_date)
    from public.tasks t
   where t.status in ('todo', 'in_progress', 'blocked')
     and t.due_date = v_today + 1
  on conflict (dedupe_key) do nothing;
  get diagnostics v_count = row_count;

  insert into public.notification_outbox
    (kind, company_id, project_id, task_id, dedupe_key, payload)
  select 'task_overdue', t.company_id, t.project_id, t.id,
         'overdue:' || t.id::text || ':' || v_today::text,
         jsonb_build_object('due_date', t.due_date)
    from public.tasks t
   where t.status in ('todo', 'in_progress', 'blocked')
     and t.due_date < v_today
  on conflict (dedupe_key) do nothing;

  perform app.nudge_notifier();
  return v_count;
end; $$;

create or replace function public.drain_notification_outbox()
returns void language plpgsql security definer set search_path = '' as $$
begin
  -- A chat push an hour late is noise, not news.
  update public.notification_outbox
     set status = 'expired', processed_at = now()
   where status = 'pending'
     and kind in ('chat_message', 'mention')
     and created_at < now() - interval '1 hour';

  -- Unstick rows abandoned mid-flight by a crashed or timed-out invocation.
  update public.notification_outbox
     set status = 'pending'
   where status = 'sending'
     and next_attempt_at < now() - interval '5 minutes';

  if exists (select 1 from public.notification_outbox
              where status = 'pending' and next_attempt_at <= now()) then
    perform app.nudge_notifier();
  end if;
end; $$;

revoke execute on function public.enqueue_due_reminders() from public, anon, authenticated;
revoke execute on function public.drain_notification_outbox() from public, anon, authenticated;

select cron.schedule('ventline-notify-drain', '* * * * *',
                     $$select public.drain_notification_outbox();$$);
select cron.schedule('ventline-due-reminders', '0 * * * *',
                     $$select public.enqueue_due_reminders();$$);
-- Retire handsets that stopped checking in (uninstalled without a 410).
select cron.schedule('ventline-prune-devices', '17 3 * * *',
                     $$delete from public.devices
                        where last_seen_at < now() - interval '90 days';$$);
