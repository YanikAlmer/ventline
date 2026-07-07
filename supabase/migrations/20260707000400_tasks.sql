create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  -- Denormalized for cheap RLS checks; kept honest by sync_task_company() trigger.
  company_id uuid not null references public.companies (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 300),
  description text,
  status public.task_status not null default 'todo',
  due_date date,
  sort_order double precision not null default 0,
  -- Curated customer portal visibility.
  visible_to_customer boolean not null default false,
  completed_by uuid references public.profiles (id) on delete set null,
  completed_at timestamptz,
  approved_by uuid references public.profiles (id) on delete set null,
  approved_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tasks_project_status_idx on public.tasks (project_id, status);
create index tasks_company_idx on public.tasks (company_id);

create table public.task_assignments (
  task_id uuid not null references public.tasks (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  assigned_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (task_id, profile_id)
);

-- "My Tasks" lookup.
create index task_assignments_profile_idx on public.task_assignments (profile_id);

grant select, insert, update, delete on public.tasks to authenticated;
grant select, insert, update, delete on public.task_assignments to authenticated;
