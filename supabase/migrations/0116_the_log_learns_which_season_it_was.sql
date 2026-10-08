-- Which season a line of the log belongs to.
--
-- The log has been filterable by person, by kind of act, by table group, by
-- date and by text since 0077 — and never by season, because a line of it does
-- not know. `audit_log` carries the table, the row id and the two images, and
-- the season was only ever available to a reader who happened to know that a
-- window of dates was roughly a season.
--
-- Roughly is the problem. Two seasons that overlap by a day are two different
-- answers, and "everything written between these dates" is not "everything
-- belonging to this season" — the أعمال of 1447 continue while 1448 is being
-- prepared, and a date range cannot tell them apart.
--
-- So the season is STAMPED on the line when it is written, from the row that
-- was written. Three states, not two, and that is the whole design:
--
--   * a season       — the lines belonging to it;
--   * no season      — the lines belonging to none, which is most of the log:
--                      accounts, grants, master data, place codes. These are
--                      not a leftover, they are the acts that outlive seasons;
--   * everything     — the default, and what the log has always shown.
--
-- A filter with only the first two would be a filter that hides the majority of
-- the log the moment it is touched — منح الصلاحيات and تعديلات الموظفين and
-- البيانات الرئيسية would all vanish, and those are much of what the log is
-- opened for.

alter table audit_log
  add column if not exists season_id uuid
    references seasons (id) on delete set null;

comment on column audit_log.season_id is
  'The season this act belongs to, stamped at write time by audit_row_change. '
  'Null means it belongs to no season — an account, a grant, a place code — '
  'which is a real answer and not a gap.';

-- Reads by season are windowed like every other read of this table: newest
-- first. Nulls are indexed too, because "the acts that belong to no season" is
-- one of the three things this filter can be asked.
create index if not exists audit_log_season
  on audit_log (season_id, id desc);

-- ========================================================= 1. finding the season

create or replace function audit_season_of(p_table text, p_data jsonb)
  returns uuid
  language plpgsql stable security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if p_data is null then
    return null;
  end if;

  -- 1. The row says so itself. `modules`, `reports`, `place_check_ins`,
  --    `evaluations`, `season_participants` — everything scoped by 0043.
  if p_data ? 'season_id' then
    return nullif(p_data ->> 'season_id', '')::uuid;
  end if;

  -- 2. A season's own row IS its season, which is what makes "show me 1448"
  --    include the act of creating 1448.
  if p_table = 'seasons' then
    return nullif(p_data ->> 'id', '')::uuid;
  end if;

  -- 3. It hangs off a file, and the file names the season. This is the rung
  --    that matters: `module_nodes`, `module_members`, `module_tasks` and
  --    `module_reports` carry no season of their own, and building a file is
  --    exactly the work somebody filtering by season is looking for.
  if p_data ? 'module_id' then
    select m.season_id into v_id
      from modules m
     where m.id = nullif(p_data ->> 'module_id', '')::uuid;
    return v_id;
  end if;

  -- 4. Or off a node of one — `module_node_members`, where the برج is between
  --    the man and the file.
  if p_data ? 'node_id' then
    select m.season_id into v_id
      from module_nodes n
      join modules m on m.id = n.module_id
     where n.id = nullif(p_data ->> 'node_id', '')::uuid;
    return v_id;
  end if;

  return null;
exception
  -- Never, under any circumstances, at the cost of the write being audited.
  -- This runs inside the trigger of every audited table: a malformed id or a
  -- row that has gone would otherwise abort the very act it exists to record,
  -- and an unstamped line is enormously better than a refused edit.
  when others then
    return null;
end;
$$;

comment on function audit_season_of(text, jsonb) is
  'The season an audited row belongs to: its own season_id, or the season of '
  'the file it hangs off, or none. Never raises — see the handler.';

revoke execute on function audit_season_of(text, jsonb) from public, anon;

-- ================================================= 2. the recorder stamps it

-- Unchanged but for the last column. Restated whole because CREATE OR REPLACE
-- takes the body as given, and half a trigger is not a thing that exists.
create or replace function audit_row_change() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_changed text[];
begin
  if tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);

    -- The columns that actually moved. `updated_at` is bookkeeping, not a
    -- decision, so it never counts as one of them.
    select array_agg(d.k) into v_changed
    from (
      select coalesce(o.key, n.key) as k
      from jsonb_each(v_old) o
      full outer join jsonb_each(v_new) n on n.key = o.key
      where o.value is distinct from n.value
    ) d
    where d.k <> 'updated_at';

    if v_changed is null then
      -- Nothing moved but the timestamp. For `reports` that IS the event:
      -- save_report rewrites the (unaudited) rows and blocks wholesale, and
      -- the header update is the one line that stands for the whole save.
      if tg_table_name = 'reports' then
        v_changed := array['content'];
      else
        return null;
      end if;
    end if;
  elsif tg_op = 'INSERT' then
    v_new := to_jsonb(new);
  else
    v_old := to_jsonb(old);
  end if;

  insert into audit_log
    (actor_id, actor_name, action, table_name,
     record_id, record_label, old_data, new_data, changed_fields, season_id)
  values
    (auth.uid(), audit_actor_name(auth.uid()), lower(tg_op), tg_table_name,
     coalesce(v_new ->> 'id', v_old ->> 'id'),
     audit_record_label(tg_table_name, coalesce(v_new, v_old)),
     v_old, v_new, v_changed,
     -- The NEW image where there is one: a row moved from one season to
     -- another belongs, as an act, to the season it was moved INTO.
     audit_season_of(tg_table_name, coalesce(v_new, v_old)));

  return null;
end;
$$;

-- ================================================== 3. the lines already written

-- Every line the log already holds, stamped by the same ladder. Bounded to the
-- lines that can actually get an answer — a row whose images carry none of the
-- three keys is an account or a grant, and reading it would be work spent to
-- write back the null it already has.
--
-- `audit_log` is one of the five tables 0077 leaves untriggered, so this update
-- does not log itself.
update audit_log a
   set season_id = audit_season_of(a.table_name, coalesce(a.new_data, a.old_data))
 where a.season_id is null
   and (
     a.table_name = 'seasons'
     or coalesce(a.new_data, a.old_data) ?| array['season_id', 'module_id', 'node_id']
   );

-- ==================================================== 4. asking for one season

-- Two parameters for three states, and they are not interchangeable:
--
--   p_seasonless = true   → the lines belonging to NO season. Wins outright.
--   p_season_id  = <uuid> → that season's lines.
--   neither               → everything, which is what the log has always shown.
--
-- Spelled the same way in both functions, for the reason 0111 gives: a header
-- counting a wider set than the list beneath it is a header that disagrees with
-- its own page.

drop function if exists audit_events(int, bigint, uuid, text[], text[],
                                     timestamptz, timestamptz, text);

create function audit_events(
  p_limit int default 50,
  p_before_id bigint default null,
  p_actor_id uuid default null,
  p_actions text[] default null,
  p_tables text[] default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_query text default null,
  p_season_id uuid default null,
  p_seasonless boolean default false
) returns table (
  id bigint,
  occurred_at timestamptz,
  actor_id uuid,
  actor_name text,
  actor_photo_url text,
  action text,
  table_name text,
  record_id text,
  record_label text,
  old_data jsonb,
  new_data jsonb,
  changed_fields text[],
  season_id uuid
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (is_admin() or has_permission('audit.view')) then
    raise exception 'not authorized';
  end if;

  return query
  select a.id, a.occurred_at, a.actor_id,
         coalesce(
           nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
           a.actor_name) as actor_name,
         p.photo_url as actor_photo_url,
         a.action, a.table_name, a.record_id, a.record_label,
         a.old_data, a.new_data, a.changed_fields, a.season_id
  from audit_log a
  left join profiles p on p.id = a.actor_id
  where (p_before_id is null or a.id < p_before_id)
    and (p_actor_id is null or a.actor_id = p_actor_id)
    and (p_actions is null or a.action = any (p_actions))
    and (p_tables is null or a.table_name = any (p_tables))
    and (p_from is null or a.occurred_at >= p_from)
    and (p_to is null or a.occurred_at < p_to)
    and (case
           when coalesce(p_seasonless, false) then a.season_id is null
           when p_season_id is not null then a.season_id = p_season_id
           else true
         end)
    and (
      nullif(btrim(coalesce(p_query, '')), '') is null
      or ar_fold(coalesce(a.record_label, ''))
           like '%' || ar_fold(btrim(p_query)) || '%'
      or ar_fold(coalesce(a.actor_name, ''))
           like '%' || ar_fold(btrim(p_query)) || '%'
    )
  order by a.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

grant execute on function audit_events(int, bigint, uuid, text[], text[],
                                       timestamptz, timestamptz, text, uuid,
                                       boolean) to authenticated;

drop function if exists audit_summary(uuid, text[], text[], timestamptz,
                                      timestamptz, text, int);

create function audit_summary(
  p_actor_id   uuid default null,
  p_actions    text[] default null,
  p_tables     text[] default null,
  p_from       timestamptz default null,
  p_to         timestamptz default null,
  p_query      text default null,
  p_days       int default 30,
  p_season_id  uuid default null,
  p_seasonless boolean default false
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_from   timestamptz;
  v_to     timestamptz;
  v_span   interval;
  v_bucket text;
  v_step   interval;
  v_out    jsonb;
begin
  -- The same door as the log itself. Counting rows a reader may not read is
  -- still telling them what is in those rows.
  if not (is_admin() or has_permission('audit.view')) then
    raise exception 'not authorized';
  end if;

  -- The reader's range when they set one; the last p_days otherwise. The upper
  -- bound stays exclusive, as it is in `audit_events`, so the two agree at the
  -- boundary rather than differing by one day's worth of rows.
  v_to   := coalesce(p_to, now());
  v_from := coalesce(
    p_from,
    date_trunc('day', v_to) - make_interval(days => greatest(coalesce(p_days, 30), 1) - 1)
  );
  if v_from > v_to then
    v_from := v_to;
  end if;

  v_span := v_to - v_from;
  if v_span <= interval '62 days' then
    v_bucket := 'day';   v_step := interval '1 day';
  elsif v_span <= interval '400 days' then
    v_bucket := 'week';  v_step := interval '1 week';
  else
    v_bucket := 'month'; v_step := interval '1 month';
  end if;

  with scoped as (
    select a.id, a.occurred_at, a.action, a.actor_id
    from audit_log a
    where a.occurred_at >= v_from
      and a.occurred_at <  v_to
      and (p_actor_id is null or a.actor_id = p_actor_id)
      and (p_actions   is null or a.action = any (p_actions))
      and (p_tables    is null or a.table_name = any (p_tables))
      and (case
             when coalesce(p_seasonless, false) then a.season_id is null
             when p_season_id is not null then a.season_id = p_season_id
             else true
           end)
      and (
        nullif(btrim(coalesce(p_query, '')), '') is null
        or ar_fold(coalesce(a.record_label, ''))
             like '%' || ar_fold(btrim(p_query)) || '%'
        or ar_fold(coalesce(a.actor_name, ''))
             like '%' || ar_fold(btrim(p_query)) || '%'
      )
  ),
  -- Every bucket in the window, occupied or not.
  buckets as (
    select generate_series(
             date_trunc(v_bucket, v_from),
             date_trunc(v_bucket, v_to),
             v_step
           ) as bucket
  ),
  counted as (
    select b.bucket, count(s.id) as n
    from buckets b
    left join scoped s
      on date_trunc(v_bucket, s.occurred_at) = b.bucket
    group by b.bucket
  ),
  by_action as (
    select s.action as key, count(*) as n
    from scoped s
    group by s.action
    order by 2 desc
  )
  select jsonb_build_object(
    'from',    v_from,
    'to',      v_to,
    'bucket',  v_bucket,
    'total',   (select count(*) from scoped),
    -- Distinct people, and the system's own rows are not a person: a trigger
    -- firing under the service role has a null actor, and counting it as one
    -- would inflate "who was working" by exactly one, always.
    'actors',  (select count(distinct s.actor_id)
                  from scoped s where s.actor_id is not null),
    'series',  coalesce((
                 select jsonb_agg(
                          jsonb_build_object('day', c.bucket, 'n', c.n)
                          order by c.bucket)
                 from counted c), '[]'::jsonb),
    'by_action', coalesce((
                 select jsonb_agg(
                          jsonb_build_object('key', b.key, 'n', b.n))
                 from by_action b), '[]'::jsonb)
  ) into v_out;

  return v_out;
end;
$$;

grant execute on function audit_summary(uuid, text[], text[], timestamptz,
                                        timestamptz, text, int, uuid,
                                        boolean) to authenticated;

-- ==================================================== 5. which seasons to offer
--
-- The filter's option list. Only the seasons the log actually holds something
-- for: offering 1445 on a database whose log was pruned to two years (0109) is
-- offering a choice whose only possible answer is "nothing".

create or replace function audit_seasons()
  returns table (season_id uuid, hijri_year int, n bigint)
  language plpgsql stable security definer set search_path = public as $$
begin
  if not (is_admin() or has_permission('audit.view')) then
    raise exception 'not authorized';
  end if;

  return query
  select s.id, s.hijri_year, count(a.id)
    from seasons s
    join audit_log a on a.season_id = s.id
   group by s.id, s.hijri_year
   order by s.hijri_year desc;
end;
$$;

grant execute on function audit_seasons() to authenticated;
