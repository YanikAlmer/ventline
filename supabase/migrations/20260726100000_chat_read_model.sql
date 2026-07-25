-- Chat read model: the queries behind the Kommunikation screen.
--
-- Everything here is SECURITY INVOKER, so RLS on messages/thread_state/
-- message_mentions is the authorization — a customer calling these sees exactly
-- what messages_select already allows, and nothing in this file re-implements a
-- permission check.
--
-- Cost discipline: the thread list reads thread_state (one row per thread), and
-- the per-thread unread count is a LATERAL that only runs for the rows the LIMIT
-- actually returns.

-- Needed by person_messages' "reply to something they wrote" leg.
create index messages_reply_idx on public.messages (reply_to_message_id)
  where reply_to_message_id is not null;

-- ======================================================== inbox: thread list
-- Cheap view for badges and rollups (no per-thread counts).
create or replace view public.inbox_threads
with (security_invoker = on) as
select
  ts.thread_id, ts.project_id, p.name as project_name, p.status as project_status,
  ts.task_id, t.title as task_title, t.status as task_status,
  ts.message_count, ts.last_message_id, ts.last_message_at, ts.last_sender_id, ts.last_kind,
  -- Never surface the preview of a message that has already expired.
  case when ts.last_expires_at is null or ts.last_expires_at > now()
       then ts.last_preview end as last_preview,
  rs.last_read_at,
  coalesce(rs.muted, false) as muted,
  (ts.last_sender_id <> (select auth.uid())
   and ts.last_message_at > coalesce(rs.last_read_at, '-infinity'::timestamptz)) as has_unread
from public.thread_state ts
join public.projects p on p.id = ts.project_id
left join public.tasks t on t.id = ts.task_id
left join public.thread_read_state rs
       on rs.thread_id = ts.thread_id and rs.profile_id = (select auth.uid());

grant select on public.inbox_threads to authenticated;

-- The paged list WITH unread counts.
create or replace function public.inbox_page(
  p_project_id uuid default null,
  p_before timestamptz default null,
  p_limit integer default 50
) returns table (
  thread_id uuid, project_id uuid, project_name text, project_status public.project_status,
  task_id uuid, task_title text, task_status public.task_status,
  last_message_id uuid, last_message_at timestamptz,
  last_sender_id uuid, last_sender_name text,
  last_kind public.message_kind, last_preview text,
  unread_count integer, unread_mention_count integer,
  last_read_at timestamptz, muted boolean
)
language sql stable
set search_path = ''
as $$
  select
    ts.thread_id, ts.project_id, p.name, p.status,
    ts.task_id, t.title, t.status,
    ts.last_message_id, ts.last_message_at,
    ts.last_sender_id, sp.full_name,
    ts.last_kind,
    case when ts.last_expires_at is null or ts.last_expires_at > now() then ts.last_preview end,
    u.unread_count, u.unread_mention_count,
    rs.last_read_at, coalesce(rs.muted, false)
  from public.thread_state ts
  join public.projects p on p.id = ts.project_id
  left join public.tasks t on t.id = ts.task_id
  left join public.profiles sp on sp.id = ts.last_sender_id
  left join public.thread_read_state rs
         on rs.thread_id = ts.thread_id and rs.profile_id = (select auth.uid())
  cross join lateral (
    select
      count(*)::int as unread_count,
      count(*) filter (where exists (
        select 1 from public.message_mentions mn
        where mn.message_id = m.id and mn.mentioned_profile_id = (select auth.uid())
      ))::int as unread_mention_count
    from public.messages m
    where m.thread_id = ts.thread_id
      and m.deleted_at is null
      and (m.expires_at is null or m.expires_at > now())
      and m.sender_id <> (select auth.uid())
      -- 30-day floor: someone who has never opened a thread must not trigger a
      -- count over its entire history.
      and m.created_at > greatest(coalesce(rs.last_read_at, '-infinity'::timestamptz),
                                  now() - interval '30 days')
  ) u
  where (p_project_id is null or ts.project_id = p_project_id)
    and (p_before is null or ts.last_message_at < p_before)
  order by ts.last_message_at desc nulls last
  limit least(coalesce(p_limit, 50), 100);
$$;

revoke execute on function public.inbox_page(uuid, timestamptz, integer) from public, anon;
grant execute on function public.inbox_page(uuid, timestamptz, integer) to authenticated;

-- ========================================================= inbox: attention
-- "Braucht deine Aufmerksamkeit". Bounded by construction: each leg is limited
-- before the union, so this never scans history.
create or replace function public.inbox_attention(p_limit integer default 20)
returns table (
  reason text, message_id uuid, thread_id uuid, project_id uuid, task_id uuid,
  sender_id uuid, kind public.message_kind, body text, created_at timestamptz
)
language sql stable
set search_path = ''
as $$
  ( -- unacknowledged @mentions
    select 'mention'::text, m.id, m.thread_id, m.project_id, m.task_id,
           m.sender_id, m.kind, m.body, m.created_at
    from public.message_mentions mn
    join public.messages m on m.id = mn.message_id
    where mn.mentioned_profile_id = (select auth.uid())
      and mn.acknowledged_at is null
      and m.deleted_at is null
      and (m.expires_at is null or m.expires_at > now())
    order by m.created_at desc
    limit least(coalesce(p_limit, 20), 50) )
  union all
  ( -- unread in threads of work assigned to me
    select 'my_task'::text, m.id, m.thread_id, m.project_id, m.task_id,
           m.sender_id, m.kind, m.body, m.created_at
    from public.task_assignments ta
    join public.messages m on m.thread_id = ta.task_id
    left join public.thread_read_state rs
           on rs.thread_id = ta.task_id and rs.profile_id = (select auth.uid())
    where ta.profile_id = (select auth.uid())
      and m.deleted_at is null
      and (m.expires_at is null or m.expires_at > now())
      and m.sender_id <> (select auth.uid())
      and coalesce(rs.muted, false) = false
      and m.created_at > greatest(coalesce(rs.last_read_at, '-infinity'::timestamptz),
                                  now() - interval '14 days')
    order by m.created_at desc
    limit least(coalesce(p_limit, 20), 50) )
  order by 9 desc
  limit least(coalesce(p_limit, 20), 50);
$$;

revoke execute on function public.inbox_attention(integer) from public, anon;
grant execute on function public.inbox_attention(integer) to authenticated;

-- ================================================================== search
-- unaccent folds "ü" to "u", NOT to the German transliteration "ue", so a user
-- typing "lueftung" gets no FTS hit for "Lüftung". Fold ue/oe/ae the same way
-- unaccent does and OR the two queries: the original still matches words that
-- genuinely contain "ue" (Steuerung), so this only adds recall.
create or replace function app.fold_umlaut_digraphs(p text)
returns text
language sql immutable
set search_path = ''
as $$
  select regexp_replace(
           regexp_replace(
             regexp_replace(p, 'ue', 'u', 'gi'),
           'oe', 'o', 'gi'),
         'ae', 'a', 'gi');
$$;

grant execute on function app.fold_umlaut_digraphs(text) to authenticated;

create or replace function public.search_messages(
  p_query text default null,
  p_project_ids uuid[] default null,
  p_sender_ids uuid[] default null,
  p_mentions_profile_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_has_photo boolean default null,
  p_has_voice boolean default null,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 30
) returns table (
  id uuid, project_id uuid, task_id uuid, thread_id uuid, sender_id uuid,
  kind public.message_kind, body text, created_at timestamptz,
  has_photo boolean, has_voice boolean, headline text, rank real
)
language sql stable
set search_path = ''
as $$
  with q as (
    select
      nullif(trim(p_query), '') as raw,
      case when nullif(trim(p_query), '') is null then null
           else websearch_to_tsquery('public.german_unaccent', p_query) end as tsq,
      case when nullif(trim(p_query), '') is null
             or app.fold_umlaut_digraphs(p_query) = p_query then null
           else websearch_to_tsquery('public.german_unaccent',
                                     app.fold_umlaut_digraphs(p_query)) end as tsq_alt
  )
  select m.id, m.project_id, m.task_id, m.thread_id, m.sender_id, m.kind, m.body,
         m.created_at, m.has_photo, m.has_voice,
         case when q.tsq is null then null
              else ts_headline('public.german_unaccent', coalesce(m.body, ''), q.tsq,
                               'MaxFragments=1,MaxWords=18,MinWords=6,StartSel=<<,StopSel=>>') end,
         case when q.tsq is null then 0::real else ts_rank_cd(m.search_tsv, q.tsq) end
  from public.messages m, q
  where m.deleted_at is null
    and (m.expires_at is null or m.expires_at > now())
    and (q.tsq is null
         or m.search_tsv @@ q.tsq
         or (q.tsq_alt is not null and m.search_tsv @@ q.tsq_alt)
         -- Trigram leg: catches the tail/middle of German compounds, which
         -- Snowball cannot decompose ("Rohr" inside "Lüftungsrohr").
         or (length(q.raw) >= 3 and m.body ilike '%' || q.raw || '%'))
    and (p_project_ids is null or m.project_id = any (p_project_ids))
    and (p_sender_ids is null or m.sender_id = any (p_sender_ids))
    and (p_from is null or m.created_at >= p_from)
    and (p_to is null or m.created_at < p_to)
    and (p_has_photo is null or m.has_photo = p_has_photo)
    and (p_has_voice is null or m.has_voice = p_has_voice)
    and (p_mentions_profile_id is null or exists (
          select 1 from public.message_mentions mn
          where mn.message_id = m.id and mn.mentioned_profile_id = p_mentions_profile_id))
    and (p_before_created_at is null
         or (m.created_at, m.id) < (p_before_created_at, p_before_id))
  order by m.created_at desc, m.id desc
  limit least(coalesce(p_limit, 30), 100);
$$;

revoke execute on function public.search_messages(
  text, uuid[], uuid[], uuid, timestamptz, timestamptz, boolean, boolean, timestamptz, uuid, integer
) from public, anon;
grant execute on function public.search_messages(
  text, uuid[], uuid[], uuid, timestamptz, timestamptz, boolean, boolean, timestamptz, uuid, integer
) to authenticated;

-- =========================================================== person lenses
-- "What did I exchange with that person — and in which project?"
create or replace function public.person_messages(
  p_profile_id uuid,
  p_project_id uuid default null,
  p_direction text default 'both',   -- 'from' | 'to' | 'both'
  p_before_created_at timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 30
) returns table (
  id uuid, project_id uuid, task_id uuid, thread_id uuid, sender_id uuid,
  kind public.message_kind, body text, created_at timestamptz,
  has_photo boolean, has_voice boolean, direction text
)
language sql stable
set search_path = ''
as $$
  with base as (
    select m.id, m.project_id, m.task_id, m.thread_id, m.sender_id, m.kind, m.body,
           m.created_at, m.has_photo, m.has_voice, 'from'::text as direction
    from public.messages m
    where p_direction in ('from', 'both')
      and m.sender_id = p_profile_id and m.deleted_at is null
      and (m.expires_at is null or m.expires_at > now())
      and (p_project_id is null or m.project_id = p_project_id)
      and (p_before_created_at is null or (m.created_at, m.id) < (p_before_created_at, p_before_id))
    order by m.created_at desc, m.id desc
    limit least(coalesce(p_limit, 30), 100)
  ), mentioned as (
    select m.id, m.project_id, m.task_id, m.thread_id, m.sender_id, m.kind, m.body,
           m.created_at, m.has_photo, m.has_voice, 'to'::text
    from public.message_mentions mn
    join public.messages m on m.id = mn.message_id
    where p_direction in ('to', 'both')
      and mn.mentioned_profile_id = p_profile_id and m.deleted_at is null
      and (m.expires_at is null or m.expires_at > now())
      and (p_project_id is null or m.project_id = p_project_id)
      and (p_before_created_at is null or (m.created_at, m.id) < (p_before_created_at, p_before_id))
    order by m.created_at desc, m.id desc
    limit least(coalesce(p_limit, 30), 100)
  ), replied as (
    select m.id, m.project_id, m.task_id, m.thread_id, m.sender_id, m.kind, m.body,
           m.created_at, m.has_photo, m.has_voice, 'to'::text
    from public.messages m
    join public.messages parent on parent.id = m.reply_to_message_id
    where p_direction in ('to', 'both')
      and parent.sender_id = p_profile_id and m.deleted_at is null
      and (m.expires_at is null or m.expires_at > now())
      and (p_project_id is null or m.project_id = p_project_id)
      and (p_before_created_at is null or (m.created_at, m.id) < (p_before_created_at, p_before_id))
    order by m.created_at desc, m.id desc
    limit least(coalesce(p_limit, 30), 100)
  ), merged as (
    select * from base
    union all select * from mentioned
    union all select * from replied
  )
  select distinct on (created_at, id) *
  from merged
  order by created_at desc, id desc
  limit least(coalesce(p_limit, 30), 100);
$$;

revoke execute on function public.person_messages(uuid, uuid, text, timestamptz, uuid, integer)
  from public, anon;
grant execute on function public.person_messages(uuid, uuid, text, timestamptz, uuid, integer)
  to authenticated;

-- Rows for the "Personen" lens: who has been active, on which project.
create or replace view public.person_activity
with (security_invoker = on) as
select m.sender_id as profile_id,
       m.project_id,
       count(*)::int as message_count,
       max(m.created_at) as last_message_at
from public.messages m
where m.deleted_at is null
  and m.created_at > now() - interval '90 days'
group by m.sender_id, m.project_id;

grant select on public.person_activity to authenticated;

-- ====================================================== jump-to-context
-- Opening a search hit needs the messages around it, not a whole thread reload.
create or replace function public.messages_around(
  p_message_id uuid,
  p_radius integer default 25
) returns setof public.messages
language sql stable
set search_path = ''
as $$
  with anchor as (
    select thread_id, created_at, id from public.messages where id = p_message_id
  )
  ( select m.* from public.messages m, anchor a
     where m.thread_id = a.thread_id and m.deleted_at is null
       and (m.created_at, m.id) <= (a.created_at, a.id)
     order by m.created_at desc, m.id desc
     limit least(coalesce(p_radius, 25), 100) + 1 )
  union all
  ( select m.* from public.messages m, anchor a
     where m.thread_id = a.thread_id and m.deleted_at is null
       and (m.created_at, m.id) > (a.created_at, a.id)
     order by m.created_at asc, m.id asc
     limit least(coalesce(p_radius, 25), 100) );
$$;

revoke execute on function public.messages_around(uuid, integer) from public, anon;
grant execute on function public.messages_around(uuid, integer) to authenticated;
