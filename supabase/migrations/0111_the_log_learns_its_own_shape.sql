-- The log could be read, and could not be described.
--
-- `audit_events` (0077) hands back fifty rows at a time, keyset-paged, newest
-- first. That is the right shape for reading a register line by line and the
-- wrong shape for every question that is about the register itself: whether
-- last Tuesday was busier than the Tuesday before, whether the deletions are
-- one person's or everybody's, whether the quiet week was quiet or was the
-- week the trigger stopped firing.
--
-- The app could have drawn those from the page it happens to be holding, and
-- that is precisely the thing not to do. Fifty rows is not a sample of the log,
-- it is its most recent end; a chart built from it would say "activity is
-- falling" every time a reader scrolled far enough back, and would say it in
-- the confident voice of a picture. A summary has to be counted where the rows
-- are.
--
-- ----------------------------------------------------------- the same window
--
-- Every filter `audit_events` takes, this takes too, spelled identically —
-- actor, action, table group, range, search. It has to be identical: a header
-- that counts a wider set than the list beneath it is a header that disagrees
-- with the page it sits on, and the reader has no way to tell which is lying.
-- The two exceptions are `p_before_id` and `p_limit`, which are about paging
-- and not about which events exist.
--
-- ---------------------------------------------------------------- the bucket
--
-- Chosen from the span rather than fixed, and returned in the payload so the
-- app labels the axis with what it actually got. A day is the natural unit and
-- is used up to 62 of them; past that the points stop being distinguishable on
-- a phone-width chart and the shape is better read weekly, then monthly. The
-- default window — no range set — is the last 30 days.
--
-- The series is GAP-FILLED. A day nothing happened on is a day with a zero on
-- it, not a day missing from the axis; a line drawn straight from Monday to
-- Thursday over an absent Tuesday and Wednesday is a line that invents traffic
-- on the days the mission was quiet.

create or replace function audit_summary(
  p_actor_id uuid default null,
  p_actions  text[] default null,
  p_tables   text[] default null,
  p_from     timestamptz default null,
  p_to       timestamptz default null,
  p_query    text default null,
  p_days     int default 30
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

-- Same grant as everything else the app calls: the function decides who may
-- have an answer, not the grant.
grant execute on function audit_summary(uuid, text[], text[], timestamptz,
                                        timestamptz, text, int) to authenticated;

-- ------------------------------------------------------------------ the index
--
-- `audit_events` reads by id and is served by the primary key. This one reads
-- by TIME, over a window, and would otherwise scan a table 0109 sizes at two
-- years of every write in the project. Descending, because every window this
-- function is asked for ends at or near now.
create index if not exists audit_log_occurred_at_idx
  on audit_log (occurred_at desc);
