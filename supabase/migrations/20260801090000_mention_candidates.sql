-- What the composer is allowed to offer.
--
-- send_message has taken p_mentions and p_refs since the chat-overview
-- migration, and app.can_mention has been enforcing who may be mentioned. No
-- client ever wrote either, so message_mentions has only ever been populated by
-- the test suite — which also means the highest-signal push event in the whole
-- product has never fired from real use.
--
-- These two functions exist so the picker offers **exactly** the set the server
-- will accept. A client that filtered project members itself would silently
-- omit owners and managers, who may be mentioned on any project without being
-- members of it — and would then be corrected by a raised exception at send
-- time, after the message was typed.

-- ============================================= the offset contract
-- Nothing in SQL reads start_offset; it exists so a client can highlight the
-- range in the body it already has. That makes the unit a client-side contract,
-- and an unstated one is a bug waiting for the first emoji.
--
-- **UTF-16 code units.** JavaScript strings are natively UTF-16, and Swift
-- reaches the same view through String.utf16, so both clients index the same
-- way without conversion. Postgres substring() counts code points and would
-- disagree past the BMP — which is exactly why nothing here does the slicing.
comment on column public.message_mentions.start_offset is
  'Offset of the "@Name" run in messages.body, in UTF-16 code units. Rendering hint only; never sliced server-side.';
comment on column public.message_mentions.length is
  'Length of the "@Name" run in UTF-16 code units, including the @.';
comment on column public.message_refs.start_offset is
  'Offset of the "#Titel" run in messages.body, in UTF-16 code units. Rendering hint only; never sliced server-side.';
comment on column public.message_refs.length is
  'Length of the "#Titel" run in UTF-16 code units, including the #.';

-- =================================================== who may be mentioned
-- Deliberately mirrors app.can_mention rather than re-deriving the rule: this
-- returns the rows, that one answers yes or no about a row, and if they ever
-- disagree the picker offers someone the insert will refuse.
create or replace function public.mention_candidates(
  p_project_id uuid,
  p_query text default null,
  p_limit integer default 8
)
returns table (
  profile_id uuid,
  full_name text,
  role public.app_role,
  is_member boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select pr.id,
         pr.full_name,
         pr.role,
         exists (select 1 from public.project_members pm
                  where pm.project_id = p_project_id and pm.profile_id = pr.id)
  from public.profiles pr
  where app.is_member_of_project(p_project_id)
    and app.can_mention(p_project_id, pr.id)
    and (
      p_query is null or p_query = ''
      -- Accent- and case-insensitive: nobody types the umlaut in a hurry, and
      -- German names are full of them. unaccent folds ü to u, so "muller"
      -- finds "Müller". The second arm covers the other spelling everyone
      -- actually types, "Mueller" -- replace() and not translate(), which maps
      -- single characters and would turn "ue" into two separate substitutions.
      or extensions.unaccent(pr.full_name) ilike
         '%' || extensions.unaccent(p_query) || '%'
      or extensions.unaccent(pr.full_name) ilike
         '%' || replace(replace(replace(extensions.unaccent(p_query),
              'ue', 'u'), 'oe', 'o'), 'ae', 'a') || '%'
    )
  -- Members of this project first: on a jobsite thread they are who you mean
  -- nine times out of ten, and the office is the exception.
  order by exists (select 1 from public.project_members pm
                    where pm.project_id = p_project_id and pm.profile_id = pr.id) desc,
           pr.full_name
  limit greatest(1, least(coalesce(p_limit, 8), 25));
$$;

revoke execute on function public.mention_candidates(uuid, text, integer)
  from public, anon;
grant execute on function public.mention_candidates(uuid, text, integer) to authenticated;

-- ================================================ what may be referenced
-- Work packages and their steps, with the package name carried on the step, so
-- "#Dichtungen" reads as "Dichtungen (Dachzentrale)" in the picker. Someone
-- working five sites has near-identical step names on all of them.
create or replace function public.task_ref_candidates(
  p_project_id uuid,
  p_query text default null,
  p_limit integer default 8
)
returns table (
  task_id uuid,
  title text,
  parent_title text,
  status public.task_status,
  is_package boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, t.title, parent.title, t.status, t.parent_id is null
  from public.tasks t
  left join public.tasks parent on parent.id = t.parent_id
  where t.project_id = p_project_id
    and app.can_read_task(t.id)
    and (
      p_query is null or p_query = ''
      or extensions.unaccent(t.title) ilike '%' || extensions.unaccent(p_query) || '%'
    )
  -- Packages before their steps, then alphabetical: the picker mirrors the
  -- board, where a step is never a peer of a package.
  order by (t.parent_id is null) desc, coalesce(parent.title, t.title), t.title
  limit greatest(1, least(coalesce(p_limit, 8), 25));
$$;

revoke execute on function public.task_ref_candidates(uuid, text, integer)
  from public, anon;
grant execute on function public.task_ref_candidates(uuid, text, integer) to authenticated;
