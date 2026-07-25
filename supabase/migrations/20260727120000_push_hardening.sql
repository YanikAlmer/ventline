-- Push notification fixes from adversarial review of 20260727090000.
--
-- The critical one was reproduced on the live database: a single bad timezone
-- string in one user's preferences aborted claim_notification_batch for EVERY
-- tenant, because `at time zone` raises on an unknown identifier and the whole
-- function rolls back. "Europe/Zuerich" — the German spelling of Zürich, and
-- exactly the typo a Swiss user would make — was enough. No malice required.

-- ====================================================== 1. timezone safety
-- Make the lookup total instead of throwing. An unrecognised zone falls back
-- to the company default rather than taking the notification system down.
create or replace function app.in_quiet_hours(p_tz text, p_start time, p_end time)
returns boolean language sql stable set search_path = '' as $$
  with tz as (
    select coalesce(
      (select name from pg_catalog.pg_timezone_names where name = p_tz),
      'Europe/Zurich') as name
  )
  select case
    when p_start = p_end then false
    when p_start <  p_end then (now() at time zone (select name from tz))::time >= p_start
                           and (now() at time zone (select name from tz))::time <  p_end
    else (now() at time zone (select name from tz))::time >= p_start
      or (now() at time zone (select name from tz))::time <  p_end
  end;
$$;

-- Belt to those braces: reject a bad zone at write time so the preference row
-- never holds one, with a clear error instead of a silent fallback.
create or replace function app.validate_notification_prefs()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.time_zone) then
    raise exception 'unknown time zone %', new.time_zone
      using hint = 'Use an IANA identifier such as Europe/Zurich.';
  end if;
  return new;
end; $$;

create trigger validate_notification_prefs
  before insert or update of time_zone on public.notification_prefs
  for each row execute function app.validate_notification_prefs();

-- ============================================ 2. task visibility (leak fix)
-- The old task gate was `pr.role <> 'customer' or t.visible_to_customer`, but
-- customers are already excluded earlier, so the OR collapsed to true and the
-- predicate degenerated to "the task exists". Task-kind notifications carry no
-- message_id, so can_profile_read_message — the only membership check in the
-- function — was skipped entirely. A worker removed from a project kept their
-- task_assignments row and therefore kept receiving that project's task titles
-- on their lock screen, while the app itself showed them nothing.
create or replace function app.can_profile_read_task(p_profile_id uuid, p_task_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.tasks t
    join public.profiles pr on pr.id = p_profile_id
    where t.id = p_task_id
      and pr.company_id = t.company_id
      and (
        exists (select 1 from public.project_members pm
                 where pm.project_id = t.project_id and pm.profile_id = pr.id)
        or pr.role in ('owner', 'manager')
      )
      and (pr.role <> 'customer' or t.visible_to_customer)
  );
$$;

grant execute on function app.can_profile_read_task(uuid, uuid) to authenticated;

-- ========================================== 3. per-device delivery tracking
-- One outbox row fans out to many devices. Settling per row meant a single
-- retryable failure re-pushed to every device that had already succeeded —
-- up to six times.
create table public.notification_deliveries (
  outbox_id uuid not null references public.notification_outbox (id) on delete cascade,
  device_id uuid not null,
  delivered_at timestamptz not null default now(),
  primary key (outbox_id, device_id)
);

alter table public.notification_deliveries enable row level security;
-- Service role only, like the outbox itself.

-- ================================================ 4. recipients, corrected
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
  select p_target_id as pid where p_target_id is not null
  union
  select ta.profile_id from public.task_assignments ta
   where p_target_id is null and p_task_id is not null and ta.task_id = p_task_id
  union
  select pm.profile_id from public.project_members pm
   where p_target_id is null and p_kind = 'chat_message'
     and p_task_id is null and pm.project_id = p_project_id
  union
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
    and pr.role <> 'customer'
    -- Every notification is scoped to one company; a candidate from another
    -- tenant can never be eligible even if a stray row put them in the union.
    and pr.company_id = p_company_id
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
    -- Thread-level mute. Conversation noise only: an assignment or a deadline
    -- still breaks through a muted thread, because those are directed at you.
    and (p_kind not in ('chat_message', 'mention')
         or not exists (
           select 1 from public.thread_read_state tr
           where tr.profile_id = pr.id
             and tr.thread_id = coalesce(p_task_id, p_project_id)
             and tr.muted))
    -- A mention already produces its own, better-worded push. Without this the
    -- same message arrives twice on the same lock screen.
    and (p_kind <> 'chat_message'
         or p_message_id is null
         or not exists (
           select 1 from public.message_mentions mn
           where mn.message_id = p_message_id and mn.mentioned_profile_id = pr.id))
    and (p_message_id is null or app.can_profile_read_message(pr.id, p_message_id))
    -- Real membership check for task kinds, which carry no message_id.
    and (p_task_id is null or app.can_profile_read_task(pr.id, p_task_id))
    and exists (select 1 from public.devices d where d.profile_id = pr.id)
)
select e.id,
       e.quiet_on and app.in_quiet_hours(e.tz, e.quiet_start, e.quiet_end) as passive,
       app.unread_count(e.id) as badge
from eligible e;
$$;

-- ================================================= 5. badge for office roles
-- The inner join on project_members returned 0 for an owner or manager who
-- reads projects through their role rather than an explicit membership row, so
-- every push wiped their app-icon badge. Use the same visibility rule as the
-- audience. The 30-day floor is now its own sargable predicate rather than
-- being buried inside greatest().
create or replace function app.unread_count(p_profile_id uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(count(*), 0)::int
  from public.messages m
  join public.profiles pr on pr.id = p_profile_id
  left join public.thread_read_state tr
    on tr.profile_id = p_profile_id and tr.thread_id = m.thread_id
  where m.sender_id <> p_profile_id
    and m.deleted_at is null
    and (m.expires_at is null or m.expires_at > now())
    and pr.company_id = m.company_id
    and (
      exists (select 1 from public.project_members pm
               where pm.project_id = m.project_id and pm.profile_id = pr.id)
      or pr.role in ('owner', 'manager')
    )
    and (pr.role <> 'customer' or m.shared_with_customer)
    and m.created_at > now() - interval '30 days'
    and m.created_at > coalesce(tr.last_read_at, '-infinity'::timestamptz);
$$;

-- =============================================== 6. attribution, not trust
-- assigned_by is client-writable and became the push actor, so a worker could
-- put someone else's name on a lock screen — or set it to the recipient and
-- suppress the notification entirely, since the actor is never notified.
create or replace function app.stamp_assigned_by()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- auth.uid() is null for service-role writes; only then is the supplied
  -- value trusted.
  new.assigned_by := coalesce((select auth.uid()), new.assigned_by);
  return new;
end; $$;

drop trigger if exists stamp_assigned_by on public.task_assignments;
create trigger stamp_assigned_by before insert on public.task_assignments
  for each row execute function app.stamp_assigned_by();

-- Re-assignment must notify again. The old key was permanent, so removing and
-- re-adding somebody to a task silently produced nothing forever after.
create or replace function app.enqueue_notification_task_assigned()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notification_outbox
    (kind, company_id, project_id, task_id, actor_id, target_id, dedupe_key)
  select 'task_assigned', t.company_id, t.project_id, t.id,
         new.assigned_by, new.profile_id,
         'assign:' || new.task_id::text || ':' || new.profile_id::text || ':'
           || extract(epoch from now())::bigint::text
    from public.tasks t where t.id = new.task_id
  on conflict (dedupe_key) do nothing;
  return new;
end; $$;

-- ================================================== 7. claim / settle fixes
create or replace function public.claim_notification_batch(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_ids uuid[]; v_result jsonb;
begin
  with upd as (
    update public.notification_outbox o
       set status = 'sending',
           attempts = o.attempts + 1,
           -- Push the deadline forward so the drain measures time since THIS
           -- claim. Previously next_attempt_at still held the creation time, so
           -- the unstick immediately re-queued rows that were still in flight.
           next_attempt_at = now() + interval '5 minutes'
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
           case when m.kind = 'text' then left(m.body, 140) end as message_preview,
           r.profile_id, r.passive, r.badge,
           d.id as device_id, d.push_token, d.platform,
           d.apns_environment, d.locale,
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
      -- A retry must not re-push to a handset that already got it.
      where o.id = any(v_ids)
        and not exists (
          select 1 from public.notification_deliveries nd
          where nd.outbox_id = o.id and nd.device_id = d.id)) f;

  update public.notification_outbox o
     set status = 'skipped', processed_at = now()
   where o.id = any(v_ids)
     and not exists (
       select 1 from jsonb_array_elements(coalesce(v_result, '[]'::jsonb)) e
        where (e ->> 'id')::uuid = o.id);

  return coalesce(v_result, '[]'::jsonb);
end; $$;

create or replace function public.settle_notification_batch(p_results jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  -- Record what actually landed, so a retry skips these handsets.
  insert into public.notification_deliveries (outbox_id, device_id)
  select (e ->> 'id')::uuid, (e ->> 'device_id')::uuid
    from jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) e
   where coalesce((e ->> 'ok')::boolean, false)
  on conflict do nothing;

  delete from public.devices d
   using jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) e
   where d.id = (e ->> 'device_id')::uuid
     and coalesce((e ->> 'prune')::boolean, false)
     and d.updated_at <= coalesce((e ->> 'invalid_since')::timestamptz, now());

  update public.notification_outbox o
     set status = 'sent', processed_at = now()
   where o.status = 'sending'
     and o.id in (select (e ->> 'id')::uuid
                    from jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) e)
     and not exists (
       select 1 from jsonb_array_elements(coalesce(p_results, '[]'::jsonb)) e2
        where (e2 ->> 'id')::uuid = o.id
          and coalesce((e2 ->> 'retryable')::boolean, false));

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

-- ==================================================== 8. drain corrections
create or replace function public.drain_notification_outbox()
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.notification_outbox
     set status = 'expired', processed_at = now()
   where status = 'pending'
     and kind in ('chat_message', 'mention')
     and created_at < now() - interval '1 hour';

  -- Unstick abandoned in-flight rows using the SAME terminal condition and
  -- backoff as settle. Previously this reset them to pending unconditionally,
  -- ignoring attempts, so a row nobody could ever deliver retried forever.
  update public.notification_outbox
     set status = case when attempts >= 6 then 'failed'::public.notification_status
                       else 'pending'::public.notification_status end,
         next_attempt_at = now() + (interval '30 seconds' * power(2, least(attempts, 5))),
         last_error = coalesce(last_error, 'abandoned in flight'),
         processed_at = case when attempts >= 6 then now() end
   where status = 'sending'
     and next_attempt_at < now();

  if exists (select 1 from public.notification_outbox
              where status = 'pending' and next_attempt_at <= now()) then
    perform app.nudge_notifier();
  end if;
end; $$;

-- Overdue tasks re-notified every single morning, forever. Nag for two weeks,
-- then stop: after that it is a report, not a notification.
create or replace function public.enqueue_due_reminders()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_today date := (now() at time zone 'Europe/Zurich')::date;
  v_count integer := 0;
begin
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
     and t.due_date >= v_today - 14
  on conflict (dedupe_key) do nothing;

  perform app.nudge_notifier();
  return v_count;
end; $$;

revoke execute on function public.enqueue_due_reminders() from public, anon, authenticated;
revoke execute on function public.drain_notification_outbox() from public, anon, authenticated;

-- ================================================= 9. register_device fixes
-- The inherited unique (profile_id, push_token) is not the identity any more
-- and made a reinstall (new install_id, same token) raise 23505. install_id is
-- the identity; drop the legacy constraint and reclaim by token as well.
alter table public.devices
  drop constraint if exists devices_profile_id_apns_token_key;

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

  -- A token must belong to exactly one row, whoever owned it before: a
  -- reinstall produces a new install_id for an unchanged token.
  delete from public.devices
   where push_token = p_push_token
     and install_id is distinct from p_install_id;
  delete from public.devices
   where install_id = p_install_id and profile_id <> v_user;

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

-- ==================================================== 10. outbox retention
-- Unbounded growth, and it holds who-was-notified metadata longer than any
-- purpose requires.
select cron.schedule('ventline-prune-outbox', '23 3 * * *',
                     $$delete from public.notification_outbox
                        where processed_at is not null
                          and processed_at < now() - interval '30 days';$$);
