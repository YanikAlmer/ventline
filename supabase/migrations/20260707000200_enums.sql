create type public.app_role as enum ('owner', 'manager', 'foreman', 'worker', 'customer');

create type public.project_status as enum ('planning', 'active', 'on_hold', 'completed', 'archived');

-- Approval flow: workers move todo <-> in_progress -> done (and may flag blocked);
-- foremen/office move anything, including done -> approved.
create type public.task_status as enum ('todo', 'in_progress', 'blocked', 'done', 'approved');

-- 'system' records thread events, e.g. "Task marked done by Miguel".
create type public.message_kind as enum ('text', 'photo', 'voice', 'video', 'system');

create type public.attachment_kind as enum ('photo', 'voice', 'video');

create type public.device_platform as enum ('ios', 'web');
