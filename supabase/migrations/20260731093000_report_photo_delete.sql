-- A report photo could be added but never removed.
--
-- attachments_delete was written when an attachment could only hang off a
-- message or a task, and it still says `task_id is not null and ...`. The
-- reports migration then gave attachments a report_id — and nothing extended
-- the policy, so a report-owned attachment matched no delete rule at all.
--
-- The failure was silent in the worst way: RLS answers a forbidden delete by
-- deleting nothing rather than by raising, so the call succeeded, returned no
-- error, and left the row exactly where it was. Nobody noticed because no UI
-- had ever attached a report photo in the first place.
--
-- The rule mirrors the task one — your own upload, or the office — with one
-- addition that the task case has no equivalent of: **not while frozen**. A
-- signed Rapport's photos are part of what the customer signed. report_photos
-- already refuses to give up the link row; without this the attachment beneath
-- it would still be deletable, and the freeze would be enforced in one place
-- but not the other.
drop policy attachments_delete on public.attachments;

create policy attachments_delete on public.attachments
  for delete to authenticated
  using (
    (
      task_id is not null
      and app.can_write_task(task_id)
      and (uploaded_by = (select auth.uid()) or app.is_office())
    )
    or (
      report_id is not null
      and app.can_write_report(report_id)
      and not app.report_is_frozen(report_id)
      and (uploaded_by = (select auth.uid()) or app.is_office())
    )
  );
