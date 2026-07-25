-- Appointment reminders: fix a window that could never fire just after midnight.
--
-- The first cut of the appointment block filtered `t.due_date = v_today` while
-- comparing against `now() .. now() + 90 minutes`. Those two disagree across a
-- date boundary: at 23:40 the lookahead reaches 01:10 the next morning, but a
-- task at 01:10 carries TOMORROW's date, so it matched nothing. Every
-- appointment in the first 90 minutes of a day was silently skipped — silently
-- being the problem, since a missed reminder looks exactly like no reminder.
--
-- Found by probing the deployed function at 23:36 local, which is the only
-- reason the window was ever exercised.
--
-- NOTE ON HISTORY: 20260728090000 in this repo already carries the corrected
-- predicate — it was amended before release, while the only databases running
-- it were this project's own. On a fresh database this migration is therefore
-- an idempotent no-op. It exists so the recorded migration history matches the
-- deployed one, which received the two as separate steps.
create or replace function public.enqueue_due_reminders()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_now_local timestamp := (now() at time zone 'Europe/Zurich');
  v_today date := v_now_local::date;
  v_count integer := 0;
begin
  if extract(hour from v_now_local) = 6 then
    insert into public.notification_outbox
      (kind, company_id, project_id, task_id, dedupe_key, payload)
    select 'task_due_soon', t.company_id, t.project_id, t.id,
           'due:' || t.id::text || ':' || t.due_date::text,
           jsonb_build_object('due_date', t.due_date, 'due_time', t.due_time)
      from public.tasks t
     where t.status in ('todo', 'in_progress', 'blocked')
       and t.due_date = v_today + 1
    on conflict (dedupe_key) do nothing;
    get diagnostics v_count = row_count;

    insert into public.notification_outbox
      (kind, company_id, project_id, task_id, dedupe_key, payload)
    select 'task_overdue', t.company_id, t.project_id, t.id,
           'overdue:' || t.id::text || ':' || v_today::text,
           jsonb_build_object('due_date', t.due_date, 'due_time', t.due_time)
      from public.tasks t
     where t.status in ('todo', 'in_progress', 'blocked')
       and t.due_date < v_today
       and t.due_date >= v_today - 14
    on conflict (dedupe_key) do nothing;
  end if;

  -- The date range spans today AND tomorrow purely to keep the scan bounded;
  -- the timestamp comparison below is the actual rule.
  insert into public.notification_outbox
    (kind, company_id, project_id, task_id, dedupe_key, payload)
  select 'task_due_soon', t.company_id, t.project_id, t.id,
         'appt:' || t.id::text || ':' || t.due_date::text,
         jsonb_build_object('due_date', t.due_date, 'due_time', t.due_time)
    from public.tasks t
   where t.status in ('todo', 'in_progress', 'blocked')
     and t.due_time is not null
     and t.due_date between v_today and v_today + 1
     and (t.due_date + t.due_time) between v_now_local
                                       and v_now_local + interval '90 minutes'
  on conflict (dedupe_key) do nothing;

  perform app.nudge_notifier();
  return v_count;
end; $$;

revoke execute on function public.enqueue_due_reminders() from public, anon, authenticated;
