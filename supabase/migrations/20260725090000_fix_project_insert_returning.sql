-- Fix: creating a project failed with "new row violates row-level security
-- policy for table projects".
--
-- Root cause: the clients insert with a RETURNING clause (PostgREST
-- `Prefer: return=representation`, i.e. `.insert(...).select()`), so the new
-- row must satisfy the SELECT policy as well. That policy called
-- app.is_member_of_project(id), which is STABLE + SECURITY DEFINER and
-- resolves membership by looking the project up in public.projects. A STABLE
-- function sees the snapshot from the start of the statement, so the row being
-- inserted is invisible to it: the office branch found no project, and no
-- project_members row exists yet either. Both branches returned false and the
-- insert was rejected — an owner could never create a project from the UI.
-- (`return=minimal` succeeded, which is what isolated it to the RETURNING path.)
--
-- Fix: decide project visibility from the row's own company_id, which is
-- available to the policy for the new row, instead of re-reading the table.
-- Membership is checked through a definer helper that only touches
-- project_members (that table's own RLS hides rows from customers, so a plain
-- subquery in the policy would see nothing).
--
-- The company_id = app.current_company_id() term preserves the cross-company
-- hardening from 20260722120000: a membership row pointing at another
-- company's project still grants nothing.

create or replace function app.is_direct_project_member(p_project_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.project_members pm
    where pm.project_id = p_project_id
      and pm.profile_id = (select auth.uid())
  );
$$;

grant execute on function app.is_direct_project_member(uuid) to authenticated;

drop policy if exists projects_select_member on public.projects;

create policy projects_select_member on public.projects
  for select to authenticated
  using (
    company_id = app.current_company_id()
    and (app.is_office() or app.is_direct_project_member(id))
  );
