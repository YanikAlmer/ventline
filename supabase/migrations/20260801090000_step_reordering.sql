-- Let someone actually reorder the steps in a work package.
--
-- tasks.sort_order has existed since the first tasks migration and both
-- clients order by it. Nothing has ever written it, so every step has
-- sort_order = 0 and the real order is the created_at tiebreak — which means
-- the order is "whenever someone happened to type it in", and cannot be
-- changed afterwards. On a job that is the difference between a list you can
-- work down and a list you have to read twice.
--
-- Done as one RPC rather than N updates from the client, for three reasons:
--
--   1. **Atomic.** A drag rewrites every position. Sent as separate updates,
--      a dropped connection halfway leaves two steps claiming position 3 and
--      the list silently reorders itself on next load.
--   2. **Cheap.** One round trip on a phone with one bar, not one per step.
--   3. **Checkable.** The whole new order arrives together, so the server can
--      verify it describes exactly this package's steps — which is what makes
--      the permission check meaningful. Position-at-a-time, a caller could
--      renumber a task in another project one update at a time.
--
-- Workers are already blocked from writing sort_order by the security
-- hardening trigger, and that stays true here: this function refuses them
-- explicitly rather than relying on a definer context to smuggle the write
-- past a rule that exists on purpose.

create or replace function public.reorder_task_steps(
  p_parent_id uuid,
  p_ordered_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_project uuid;
  v_count integer;
begin
  -- Must be a work package: steps do not nest, so a step has nothing to order.
  select project_id into v_project
  from public.tasks
  where id = p_parent_id and parent_id is null;

  if not found then
    raise exception 'Arbeitspaket % nicht gefunden', p_parent_id
      using errcode = 'no_data_found';
  end if;

  if not app.can_write_project(v_project) then
    raise exception 'not allowed' using errcode = 'insufficient_privilege';
  end if;

  -- SECURITY DEFINER runs past RLS, so the rule a worker meets on a direct
  -- UPDATE has to be restated here or this function becomes the way around it.
  -- Same wording as the trigger, so the client shows one message either way.
  if app.current_member_role() = 'worker' then
    raise exception 'workers can only change task status'
      using errcode = 'insufficient_privilege';
  end if;

  -- One comparison covering three separate ways to get this wrong: a short
  -- list (omitted steps keep their old positions and collide), a list naming
  -- a step of some other package (renumbering it through this function's
  -- definer rights), and a list repeating an id (arithmetically plausible,
  -- leaves a step behind). Sorted both sides, so only membership is compared
  -- and not the order being requested.
  if (select array_agg(x order by x) from unnest(p_ordered_ids) as x)
     is distinct from
     (select array_agg(t.id order by t.id) from public.tasks t
       where t.parent_id = p_parent_id)
  then
    raise exception 'die Reihenfolge ist nicht mehr aktuell; bitte neu laden'
      using errcode = 'check_violation';
  end if;

  update public.tasks t
     set sort_order = o.ord
    from unnest(p_ordered_ids) with ordinality as o(id, ord)
   where t.id = o.id;

  get diagnostics v_count = row_count;
  return v_count;
end; $$;

revoke execute on function public.reorder_task_steps(uuid, uuid[]) from public, anon;
grant execute on function public.reorder_task_steps(uuid, uuid[]) to authenticated;

-- Existing rows all sit at 0, so the created_at tiebreak is the order people
-- have been seeing. Write that down as the starting positions, or the first
-- drag would appear to shuffle steps nobody touched.
with numbered as (
  select id, row_number() over (
           partition by parent_id order by sort_order, created_at, id) as ord
  from public.tasks
  where parent_id is not null
)
update public.tasks t
   set sort_order = numbered.ord
  from numbered
 where t.id = numbered.id
   and t.sort_order is distinct from numbered.ord;
