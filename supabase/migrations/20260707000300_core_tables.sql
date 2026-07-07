-- Tenancy root, user profiles, invites, projects, memberships.

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  created_at timestamptz not null default now()
);

-- 1:1 with auth.users. Rows are created by the handle_new_user() trigger
-- (see triggers migration) or by public.create_company() /
-- public.redeem_invite() for the bootstrap paths.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  company_id uuid not null references public.companies (id) on delete cascade,
  role public.app_role not null default 'worker',
  full_name text not null check (char_length(full_name) between 1 and 120),
  phone text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_company_idx on public.profiles (company_id);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  code text not null unique,
  role public.app_role not null default 'worker',
  full_name text,
  -- Projects the invitee is auto-added to on redemption (required for
  -- customer invites — a customer without membership sees nothing).
  project_ids uuid[] not null default '{}',
  invited_by uuid references public.profiles (id) on delete set null,
  expires_at timestamptz not null default now() + interval '14 days',
  redeemed_by uuid references public.profiles (id) on delete set null,
  redeemed_at timestamptz,
  created_at timestamptz not null default now()
);

create index invites_company_idx on public.invites (company_id);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  address text,
  description text,
  status public.project_status not null default 'planning',
  -- Shown in the customer portal header; the customer's profile name may
  -- differ from how the company labels the job.
  customer_display_name text,
  cover_photo_path text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index projects_company_status_idx on public.projects (company_id, status);

-- Explicit project scoping for foreman/worker/customer. Owners and managers
-- see every company project implicitly (see app.is_member_of_project()).
create table public.project_members (
  project_id uuid not null references public.projects (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  added_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (project_id, profile_id)
);

create index project_members_profile_idx on public.project_members (profile_id);

-- Explicit grants: new cloud projects no longer auto-expose public entities.
grant select, insert, update, delete on public.companies to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.invites to authenticated;
grant select, insert, update, delete on public.projects to authenticated;
grant select, insert, update, delete on public.project_members to authenticated;
