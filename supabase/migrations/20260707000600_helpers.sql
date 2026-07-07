-- RLS helper functions. All SECURITY DEFINER with an empty search_path:
-- definer bypasses RLS inside the helper (profiles policies reference these
-- helpers, so an invoker version would recurse), and the empty search_path
-- forces fully-qualified names.

create or replace function app.current_company_id()
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select company_id from public.profiles where id = (select auth.uid());
$$;

create or replace function app.current_member_role()
returns public.app_role
language sql stable security definer
set search_path = ''
as $$
  select role from public.profiles where id = (select auth.uid());
$$;

-- Owner/manager: company-wide visibility and people management.
create or replace function app.is_office()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(app.current_member_role() in ('owner', 'manager'), false);
$$;

-- Membership: explicit row, or office role on a same-company project.
create or replace function app.is_member_of_project(p_project_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.project_members pm
    where pm.project_id = p_project_id
      and pm.profile_id = (select auth.uid())
  )
  or (
    app.is_office()
    and exists (
      select 1
      from public.projects p
      where p.id = p_project_id
        and p.company_id = app.current_company_id()
    )
  );
$$;

-- Members who are not customers may write (messages, tasks, media).
create or replace function app.can_write_project(p_project_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select app.is_member_of_project(p_project_id)
     and coalesce(app.current_member_role() <> 'customer', false);
$$;

-- Message visibility, reused by attachments/annotations policies.
-- Customers only see messages explicitly shared with them; everyone is
-- shielded from expired and soft-deleted messages.
create or replace function app.can_read_message(p_message_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.messages m
    where m.id = p_message_id
      and m.deleted_at is null
      and (m.expires_at is null or m.expires_at > now())
      and app.is_member_of_project(m.project_id)
      and (app.current_member_role() <> 'customer' or m.shared_with_customer)
  );
$$;

-- Storage read gate for customers: the object path must belong to a photo
-- attachment (or its annotation render) of a message shared with them.
create or replace function app.customer_can_read_object(p_bucket text, p_name text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.attachments a
    join public.messages m on m.id = a.message_id
    where ((a.storage_bucket = p_bucket and a.storage_path = p_name)
           or exists (
             select 1 from public.photo_annotations pa
             where pa.attachment_id = a.id
               and p_bucket = 'photos'
               and pa.rendered_path = p_name
           ))
      and m.deleted_at is null
      and (m.expires_at is null or m.expires_at > now())
      and m.shared_with_customer
      and app.is_member_of_project(m.project_id)
  );
$$;

grant execute on function
  app.current_company_id(),
  app.current_member_role(),
  app.is_office(),
  app.is_member_of_project(uuid),
  app.can_write_project(uuid),
  app.can_read_message(uuid),
  app.customer_can_read_object(text, text)
to authenticated;
