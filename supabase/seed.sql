-- Development seed data. NOT applied to production (supabase db push ignores
-- seed.sql unless you pass --include-seed). Used by scripts/db-validate.sh
-- and `supabase db reset` for local development.
--
-- Two companies to exercise cross-tenant isolation:
--   Alpine Air (HVAC): owner Olivia, manager Marcus, foreman Frank,
--     workers Wanda & Miguel, customer Carla (Maple Street only)
--   Baltic Builders: owner Boris, worker Wes
--
-- All auth users share the password "password123" when seeded via Supabase
-- auth; in the validation harness they are plain rows in the shimmed
-- auth.users table.

-- Deterministic UUIDs make RLS tests readable.
-- Users: 00000000-0000-4000-8000-0000000000XX
insert into auth.users (id, email, raw_user_meta_data)
values
  ('00000000-0000-4000-8000-000000000001', 'olivia@alpineair.test',  '{"company_name": "Alpine Air", "full_name": "Olivia Owner"}'),
  ('00000000-0000-4000-8000-000000000002', 'marcus@alpineair.test',  '{}'),
  ('00000000-0000-4000-8000-000000000003', 'frank@alpineair.test',   '{}'),
  ('00000000-0000-4000-8000-000000000004', 'wanda@alpineair.test',   '{}'),
  ('00000000-0000-4000-8000-000000000005', 'miguel@alpineair.test',  '{}'),
  ('00000000-0000-4000-8000-000000000006', 'carla@customer.test',    '{}'),
  ('00000000-0000-4000-8000-000000000007', 'boris@baltic.test',      '{"company_name": "Baltic Builders", "full_name": "Boris Owner"}'),
  ('00000000-0000-4000-8000-000000000008', 'wes@baltic.test',        '{}');

-- Olivia's and Boris's companies were created by the handle_new_user trigger.
-- Fetch their ids into psql variables is not possible in plain SQL; use DO.
do $$
declare
  v_alpine uuid;
  v_baltic uuid;
  v_maple uuid := '00000000-0000-4000-9000-000000000001';
  v_depot uuid := '00000000-0000-4000-9000-000000000002';
  v_task_filter uuid := '00000000-0000-4000-a000-000000000001';
  v_task_duct   uuid := '00000000-0000-4000-a000-000000000002';
  v_task_therm  uuid := '00000000-0000-4000-a000-000000000003';
  v_msg_shared  uuid := '00000000-0000-4000-b000-000000000001';
  v_msg_private uuid := '00000000-0000-4000-b000-000000000002';
begin
  select company_id into strict v_alpine
  from public.profiles where id = '00000000-0000-4000-8000-000000000001';
  select company_id into strict v_baltic
  from public.profiles where id = '00000000-0000-4000-8000-000000000007';

  -- Remaining Alpine profiles (trigger only made the owners).
  insert into public.profiles (id, company_id, role, full_name, phone) values
    ('00000000-0000-4000-8000-000000000002', v_alpine, 'manager',  'Marcus Manager', '+1 555 0102'),
    ('00000000-0000-4000-8000-000000000003', v_alpine, 'foreman',  'Frank Foreman',  '+1 555 0103'),
    ('00000000-0000-4000-8000-000000000004', v_alpine, 'worker',   'Wanda Worker',   '+1 555 0104'),
    ('00000000-0000-4000-8000-000000000005', v_alpine, 'worker',   'Miguel Mendez',  '+1 555 0105'),
    ('00000000-0000-4000-8000-000000000006', v_alpine, 'customer', 'Carla Customer', null),
    ('00000000-0000-4000-8000-000000000008', v_baltic, 'worker',   'Wes Walker',     null);

  insert into public.projects (id, company_id, name, address, status, customer_display_name, created_by) values
    (v_maple, v_alpine, 'Maple Street Renovation', '12 Maple St', 'active',
     'The Hendersons', '00000000-0000-4000-8000-000000000002'),
    (v_depot, v_alpine, 'Depot Rooftop Units', '400 Industrial Ave', 'planning',
     null, '00000000-0000-4000-8000-000000000002');

  -- Frank, Wanda, Carla on Maple Street; Miguel on Depot.
  insert into public.project_members (project_id, profile_id, added_by) values
    (v_maple, '00000000-0000-4000-8000-000000000003', '00000000-0000-4000-8000-000000000002'),
    (v_maple, '00000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000002'),
    (v_maple, '00000000-0000-4000-8000-000000000006', '00000000-0000-4000-8000-000000000002'),
    (v_depot, '00000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000002');

  insert into public.tasks (id, project_id, company_id, title, status, visible_to_customer, created_by) values
    (v_task_filter, v_maple, v_alpine, 'Replace air filters',        'in_progress', true,
     '00000000-0000-4000-8000-000000000003'),
    (v_task_duct,   v_maple, v_alpine, 'Seal duct joints in attic',  'todo',        false,
     '00000000-0000-4000-8000-000000000003'),
    (v_task_therm,  v_depot, v_alpine, 'Install smart thermostats',  'todo',        false,
     '00000000-0000-4000-8000-000000000002');

  insert into public.task_assignments (task_id, profile_id, assigned_by) values
    (v_task_filter, '00000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000003'),
    (v_task_duct,   '00000000-0000-4000-8000-000000000004', '00000000-0000-4000-8000-000000000003'),
    (v_task_therm,  '00000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000002');

  insert into public.messages (id, company_id, project_id, task_id, sender_id, kind, body, shared_with_customer) values
    (v_msg_shared, v_alpine, v_maple, v_task_filter,
     '00000000-0000-4000-8000-000000000004', 'text',
     'Filters replaced, before/after photos coming.', true),
    (v_msg_private, v_alpine, v_maple, v_task_filter,
     '00000000-0000-4000-8000-000000000004', 'text',
     'Heads up: attic access is tight, bring the small ladder.', false);
end;
$$;
