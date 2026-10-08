-- What a season looks like from above.
--
-- Every screen in this app answers one question about one row. Nobody has ever
-- been able to ask how the season as a whole is going — how many of the files
-- are actually running, whether the people who owe reports are filing them,
-- where the mission's strength sits. Those answers exist; they are just spread
-- across eight tables and nobody has counted them.
--
-- One function, one round trip, because a dashboard that fires fourteen queries
-- is a dashboard that loads in fourteen steps. It takes a season and returns
-- everything as jsonb: counts, breakdowns, and the one genuine time series this
-- schema holds — reports, by the day they account for.
--
-- SECURITY DEFINER, and therefore gated by hand.
--
-- This has to bypass RLS: a count computed under row-level security is not a
-- count, it is the number of rows this particular reader may see, which is a
-- different and much less useful number that changes per viewer. So the
-- function reads everything and then decides, section by section, what to hand
-- back — using the SAME permissions the screens use. A reader without
-- `employees.view` gets no `people` key at all, rather than a zero: a zero is a
-- claim about the mission, and "you may not ask" is not the same claim.
--
-- Every section is null-or-present. The app draws what it was given.

create or replace function dashboard_stats(p_season_id uuid default null)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = public
as $$
declare
  v_season_id uuid;
  v_season jsonb;
  v_people jsonb;
  v_approvals jsonb;
  v_modules jsonb;
  v_reports jsonb;
  v_ratings jsonb;
  v_can_people boolean;
  v_can_modules boolean;
begin
  -- Only an approved, unsuspended account gets anything at all.
  if not is_approved() then
    return jsonb_build_object('season', null);
  end if;

  -- No season named means the one being worked through.
  select s.id into v_season_id
  from seasons s
  where (p_season_id is not null and s.id = p_season_id)
     or (p_season_id is null and s.is_current)
  limit 1;

  if v_season_id is null then
    return jsonb_build_object('season', null);
  end if;

  select jsonb_build_object(
           'id', s.id,
           'hijri_year', s.hijri_year,
           'gregorian_label', s.gregorian_label,
           'is_current', s.is_current
         )
    into v_season
  from seasons s
  where s.id = v_season_id;

  v_can_people := has_permission('employees.view');
  v_can_modules :=
    has_permission('modules.manage') or has_permission('modules.members');

  -- ── The mission's people ────────────────────────────────────────────────
  --
  -- Scoped to the season through season_participants: "how many employees are
  -- there" is a question about the database, "how many are on THIS season" is a
  -- question about the mission.
  if v_can_people then
    select jsonb_build_object(
             'participants', count(*) filter (where sp.status = 'active'),
             'withdrawn', count(*) filter (where sp.status = 'withdrawn'),
             'internal', count(*) filter
               (where sp.status = 'active' and not pr.is_external),
             'external', count(*) filter
               (where sp.status = 'active' and pr.is_external),
             'by_mission', coalesce((
               select jsonb_agg(jsonb_build_object('key', key, 'count', n)
                                order by n desc)
               from (
                 select coalesce(p2.mission_type::text, 'unknown') as key,
                        count(*) as n
                 from season_participants sp2
                 join profiles p2 on p2.id = sp2.profile_id
                 where sp2.season_id = v_season_id and sp2.status = 'active'
                 group by 1
               ) m
             ), '[]'::jsonb),
             'by_gender', coalesce((
               select jsonb_agg(jsonb_build_object('key', key, 'count', n)
                                order by n desc)
               from (
                 select coalesce(p3.gender::text, 'unknown') as key,
                        count(*) as n
                 from season_participants sp3
                 join profiles p3 on p3.id = sp3.profile_id
                 where sp3.season_id = v_season_id and sp3.status = 'active'
                 group by 1
               ) g
             ), '[]'::jsonb),
             -- The eight biggest trades, which is as many as a ranked bar chart
             -- can be read at a glance. The tail is summed into one row rather
             -- than dropped, so the total still adds up.
             'by_job_title', coalesce((
               select jsonb_agg(row_to_json(t)::jsonb order by t.n desc)
               from (
                 -- `name` is the Arabic one and stayed unrenamed in 0046; only
                 -- the English column was added beside it.
                 select jt.name as label_ar,
                        jt.name_en as label_en,
                        count(*) as n
                 from season_participants sp4
                 join profiles p4 on p4.id = sp4.profile_id
                 join job_titles jt on jt.id = p4.job_title_id
                 where sp4.season_id = v_season_id and sp4.status = 'active'
                 group by jt.id, jt.name, jt.name_en
                 order by count(*) desc
                 limit 8
               ) t
             ), '[]'::jsonb)
           )
      into v_people
    from season_participants sp
    join profiles pr on pr.id = sp.profile_id
    where sp.season_id = v_season_id;
  end if;

  -- ── The queue at the door ───────────────────────────────────────────────
  --
  -- Not season-scoped, and deliberately: somebody waiting to be approved is not
  -- on a season yet. That is the whole reason they are waiting.
  if has_permission('approvals.decide') then
    select jsonb_build_object(
             'pending', count(*) filter (where account_status = 'pending'),
             'approved', count(*) filter (where account_status = 'approved'),
             'rejected', count(*) filter (where account_status = 'rejected'),
             'incomplete', count(*) filter (where account_status = 'incomplete')
           )
      into v_approvals
    from profiles;
  end if;

  -- ── The season's files ──────────────────────────────────────────────────
  if v_can_modules then
    select jsonb_build_object(
             'total', count(*),
             'active', count(*) filter (where m.is_active),
             'draft', count(*) filter (where not m.is_active),
             -- `ends_on` is inclusive — a file is still running ON that date
             -- (0058) — so a file has ended only once the date is behind us.
             -- Null means it runs on its condition alone and has not ended by
             -- any date, which is not the same as running forever.
             'ended', count(*) filter
               (where m.ends_on is not null and m.ends_on < current_date),
             'running', count(*) filter (
               where m.is_active
                 and (m.ends_on is null or m.ends_on >= current_date)
             ),
             'by_type', coalesce((
               select jsonb_agg(row_to_json(t)::jsonb order by t.total desc)
               from (
                 select mt.name_ar as label_ar,
                        mt.name_en as label_en,
                        count(*) as total,
                        count(*) filter (where m2.is_active) as active,
                        count(*) filter (where not m2.is_active) as draft
                 from modules m2
                 join module_types mt on mt.id = m2.module_type_id
                 where m2.season_id = v_season_id
                 group by mt.id, mt.name_ar, mt.name_en
               ) t
             ), '[]'::jsonb),
             'nodes', coalesce((
               select count(*)
               from module_nodes n
               join modules m3 on m3.id = n.module_id
               where m3.season_id = v_season_id
             ), 0),
             'members', coalesce((
               select count(distinct mm.profile_id)
               from module_members mm
               join modules m4 on m4.id = mm.module_id
               where m4.season_id = v_season_id
             ), 0),
             -- A file with no one in it is the one thing on this page that is
             -- always worth acting on, so it is counted rather than inferred.
             'unstaffed', coalesce((
               select count(*)
               from modules m5
               where m5.season_id = v_season_id
                 and not exists (
                   select 1 from module_members mm2 where mm2.module_id = m5.id
                 )
             ), 0)
           )
      into v_modules
    from modules m
    where m.season_id = v_season_id;

    -- ── Reports: the one real time series in here ─────────────────────────
    --
    -- Thirty days back, by the period the report ACCOUNTS for rather than the
    -- moment it was typed — a Monday report filed on Tuesday belongs to Monday,
    -- and the schema already normalises that into period_start.
    select jsonb_build_object(
             'total', count(*),
             'authors', count(distinct r.author_id),
             'series', coalesce((
               select jsonb_agg(row_to_json(d)::jsonb order by d.day)
               from (
                 select coalesce(r2.period_start, r2.created_at::date) as day,
                        count(*) as n
                 from module_reports r2
                 join modules m6 on m6.id = r2.module_id
                 where m6.season_id = v_season_id
                   and coalesce(r2.period_start, r2.created_at::date)
                       >= current_date - 29
                 group by 1
               ) d
             ), '[]'::jsonb)
           )
      into v_reports
    from module_reports r
    join modules m7 on m7.id = r.module_id
    where m7.season_id = v_season_id;
  end if;

  -- ── What the people who worked a file said about each other ─────────────
  --
  -- Counts and an average only. Who said what about whom is anonymous by
  -- design (see 0059), and an aggregate small enough to be reversed would
  -- undo that — so a file with fewer than three verdicts is left out of the
  -- distribution entirely.
  if v_can_modules then
    select jsonb_build_object(
             'count', count(*),
             'rated_people', count(distinct rt.ratee_id),
             'average', round(avg(rt.stars)::numeric, 2),
             'distribution', coalesce((
               select jsonb_agg(jsonb_build_object('stars', s, 'count', n)
                                order by s)
               from (
                 select rt2.stars as s, count(*) as n
                 from module_ratings rt2
                 join modules m8 on m8.id = rt2.module_id
                 where m8.season_id = v_season_id
                 group by rt2.stars
               ) x
             ), '[]'::jsonb)
           )
      into v_ratings
    from module_ratings rt
    join modules m9 on m9.id = rt.module_id
    where m9.season_id = v_season_id;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'season', v_season,
    'people', v_people,
    'approvals', v_approvals,
    'modules', v_modules,
    'reports', v_reports,
    'ratings', v_ratings
  ));
end;
$$;

grant execute on function dashboard_stats(uuid) to authenticated;

-- The seasons a dashboard may be pointed at, newest first. Every approved
-- account may read the list — the filter is useless without it, and a season's
-- year is not a secret.
create or replace function dashboard_seasons()
  returns table (id uuid, hijri_year int, gregorian_label text, is_current boolean)
  language sql
  stable
  security definer
  set search_path = public
as $$
  select s.id, s.hijri_year, s.gregorian_label, s.is_current
  from seasons s
  where is_approved()
  order by s.hijri_year desc;
$$;

grant execute on function dashboard_seasons() to authenticated;
