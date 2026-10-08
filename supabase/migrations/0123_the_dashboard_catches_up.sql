-- The dashboard catches up with the app.
--
-- `dashboard_stats` was last written in 0085. The app is at 0122. In between it
-- gained the urgent-report register, the attendance board, the personal task
-- system, the evaluations and the complaints — five whole sections of work —
-- and the one screen whose entire job is to say how the mission is going
-- carried none of them.
--
-- That is not a missing feature so much as a screen that quietly stopped being
-- true. Somebody reads ten cards, sees no card about emergencies, and concludes
-- there is nothing to know about emergencies. A dashboard is trusted in a way a
-- list is not — it is the thing you look at INSTEAD of looking at everything —
-- and one that omits half the app while looking complete is worse than one that
-- was never built.
--
-- Five sections added, and the whole function restated because its body is one
-- procedure and there is no way to add to it in place.
--
-- ------------------------------------------------------ what is season-scoped
--
-- Three of the five cannot be, and the app has to say so on their cards rather
-- than let the season selector at the top of the page imply otherwise:
--
--   * `evaluations` and `place_check_ins` both carry `season_id`. Scoped.
--   * `personal_tasks`, `complaints` and `incidents` do not, and should not:
--     a task assigned to a man is his until it is answered, a complaint is
--     about conduct rather than about a season, and an emergency belongs to the
--     hour it happened in. Counting them against a season would mean inventing
--     a join that the schema deliberately does not have.
--
-- So those three are counted over a WINDOW instead — the last thirty days,
-- beside an all-time total — which is the same shape 0085 already chose for
-- the notifications, and for the same reason.

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
  v_central jsonb;
  v_notifications jsonb;
  v_reference jsonb;
  v_permissions jsonb;
  v_tasks jsonb;
  v_complaints jsonb;
  v_evaluations jsonb;
  v_checkin jsonb;
  v_incidents jsonb;
  v_can_people boolean;
  v_can_modules boolean;
begin
  if not is_approved() then
    return jsonb_build_object('season', null);
  end if;

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
    has_permission('modules.view_all') or has_permission('modules.members');

  if v_can_people then
    select jsonb_build_object(
             'participants', count(*) filter (where sp.status = 'active'),
             'withdrawn', count(*) filter (where sp.status = 'withdrawn'),
             'internal', count(*) filter
               (where sp.status = 'active' and not pr.is_external),
             'external', count(*) filter
               (where sp.status = 'active' and pr.is_external),
             'by_mission', coalesce((
               select jsonb_agg(row_to_json(t)::jsonb order by t.n desc)
               from (
                 select mi.name_ar as label_ar,
                        mi.name_en as label_en,
                        count(*) as n
                 from season_participants sp2
                 join profiles p2 on p2.id = sp2.profile_id
                 join reference_items mi on mi.id = p2.mission_type_id
                 where sp2.season_id = v_season_id and sp2.status = 'active'
                 group by mi.id, mi.name_ar, mi.name_en
               ) t
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
             'by_job_title', coalesce((
               select jsonb_agg(row_to_json(t)::jsonb order by t.n desc)
               from (
                 select jt.name_ar as label_ar,
                        jt.name_en as label_en,
                        count(*) as n
                 from season_participants sp4
                 join profiles p4 on p4.id = sp4.profile_id
                 join reference_items jt on jt.id = p4.job_title_id
                 where sp4.season_id = v_season_id and sp4.status = 'active'
                 group by jt.id, jt.name_ar, jt.name_en
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

  if has_permission('approvals.view') then
    select jsonb_build_object(
             'pending', count(*) filter (where account_status = 'pending'),
             'approved', count(*) filter (where account_status = 'approved'),
             'rejected', count(*) filter (where account_status = 'rejected'),
             'incomplete', count(*) filter (where account_status = 'incomplete')
           )
      into v_approvals
    from profiles;
  end if;

  if v_can_modules then
    select jsonb_build_object(
             'total', count(*),
             'active', count(*) filter (where m.is_active),
             'draft', count(*) filter (where not m.is_active),
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

  -- ------------------------------------------------- the central reports
  -- Scoped the way the reports screen scopes itself: this season's, plus the
  -- general ones (season_id null), because a general report applies here too.
  if has_permission('reports.view_all') then
    select jsonb_build_object(
             'total', count(*),
             'published', count(*) filter (where cr.is_published),
             'drafts', count(*) filter (where not cr.is_published),
             'general', count(*) filter (where cr.season_id is null),
             'by_type', coalesce((
               select jsonb_agg(row_to_json(t)::jsonb order by t.n desc)
               from (
                 select rt.name_ar as label_ar,
                        rt.name_en as label_en,
                        count(*) as n
                 from reports cr2
                 join report_types rt on rt.id = cr2.report_type_id
                 where cr2.season_id = v_season_id or cr2.season_id is null
                 group by rt.id, rt.name_ar, rt.name_en
                 order by count(*) desc
                 limit 8
               ) t
             ), '[]'::jsonb)
           )
      into v_central
    from reports cr
    where cr.season_id = v_season_id or cr.season_id is null;
  end if;

  -- ----------------------------------------------------- the notifications
  -- Not season-scoped — a notification belongs to a moment, not a season — so
  -- the window is the last thirty days, beside an all-time message count.
  if has_permission('notifications.send')
     or has_permission('notifications.broadcast_module')
     or has_permission('notifications.broadcast_all') then
    select jsonb_build_object(
             'messages', count(distinct nf.group_id) filter
               (where nf.created_at >= current_date - 29),
             'recipients', count(*) filter
               (where nf.created_at >= current_date - 29),
             'read', count(*) filter
               (where nf.created_at >= current_date - 29
                  and nf.read_at is not null),
             'total_messages', count(distinct nf.group_id),
             'series', coalesce((
               select jsonb_agg(row_to_json(d)::jsonb order by d.day)
               from (
                 select nf2.created_at::date as day,
                        count(distinct nf2.group_id) as n
                 from notifications nf2
                 where nf2.created_at >= current_date - 29
                 group by 1
               ) d
             ), '[]'::jsonb)
           )
      into v_notifications
    from notifications nf;
  end if;

  -- -------------------------------------------------------- the master data
  -- Items counted over what this season actually works with: its own items
  -- plus the general (non-seasonal) ones, the same set its screens read.
  if has_permission('reference.view') then
    select jsonb_build_object(
             'sets', (select count(*) from reference_sets),
             'items', count(*),
             'active', count(*) filter (where ri.is_active),
             'season_items', count(*) filter
               (where ri.season_id = v_season_id),
             'general_items', count(*) filter (where ri.season_id is null),
             'by_set', coalesce((
               select jsonb_agg(row_to_json(t)::jsonb order by t.n desc)
               from (
                 select rs.name_ar as label_ar,
                        rs.name_en as label_en,
                        count(ri2.id) as n
                 from reference_sets rs
                 left join reference_items ri2
                   on ri2.set_id = rs.id
                  and (ri2.season_id = v_season_id or ri2.season_id is null)
                 group by rs.id, rs.name_ar, rs.name_en
                 order by count(ri2.id) desc
                 limit 8
               ) t
             ), '[]'::jsonb)
           )
      into v_reference
    from reference_items ri
    where ri.season_id = v_season_id or ri.season_id is null;
  end if;

  -- -------------------------------------------------------- the permissions
  -- Who can do what, in the aggregate. The grants themselves stay on their
  -- own screen; this is the shape of the keyring, not the keys.
  if has_permission('permissions.view') then
    select jsonb_build_object(
             'admins', (select count(*) from profiles where is_admin),
             'grantees', (
               select count(distinct up.user_id) from user_permissions up
             ),
             'grants', (select count(*) from user_permissions),
             'by_section', coalesce((
               select jsonb_agg(jsonb_build_object('key', key, 'count', n)
                                order by n desc)
               from (
                 select parent.code as key, count(*) as n
                 from user_permissions up2
                 join permissions p on p.id = up2.permission_id
                 join permissions parent on parent.id = p.parent_id
                 group by parent.code
               ) s
             ), '[]'::jsonb)
           )
      into v_permissions;
  end if;

  -- ============================================================ NEW IN 0123
  --
  -- ------------------------------------------------------------- the tasks
  --
  -- Behind `tasks.view_all` and nothing weaker. `tasks.assign` is the right to
  -- give work OUT; this card is the shape of everybody's list at once, which
  -- is the trust 0117 created a separate code for. A man's own notebook is not
  -- in here at all and cannot be: `created_by <> profile_id` is the guard the
  -- row policy puts in front of every branch that grant touches, and it is
  -- repeated here rather than inherited, because this function is SECURITY
  -- DEFINER and inherits nothing.
  --
  -- Not season-scoped: the table has no season and should not. `late` is asked
  -- of the same three columns 0119's server-side bucket asks — a task is late
  -- when it has a due date behind us and has not reached an ending state.
  if has_permission('tasks.view_all') then
    select jsonb_build_object(
             'total', count(*),
             'open', count(*) filter
               (where t.state not in ('done', 'cancelled')),
             'late', count(*) filter (
               where t.due_on is not null
                 and t.due_on < current_date
                 and t.state not in ('done', 'cancelled')
             ),
             'awaiting_review', count(*) filter (where t.state = 'submitted'),
             'blocked', count(*) filter (where t.state = 'blocked'),
             'escalated', count(*) filter (where t.escalation_rung > 0),
             'assignees', count(distinct t.profile_id),
             'recent', count(*) filter
               (where t.created_at >= current_date - 29),
             'by_state', coalesce((
               select jsonb_agg(jsonb_build_object('key', key, 'count', n)
                                order by n desc)
               from (
                 select t2.state::text as key, count(*) as n
                 from personal_tasks t2
                 where t2.created_by <> t2.profile_id
                 group by 1
               ) s
             ), '[]'::jsonb),
             'by_priority', coalesce((
               select jsonb_agg(jsonb_build_object('key', key, 'count', n)
                                order by n desc)
               from (
                 select t3.priority::text as key, count(*) as n
                 from personal_tasks t3
                 where t3.created_by <> t3.profile_id
                   and t3.state not in ('done', 'cancelled')
                 group by 1
               ) s
             ), '[]'::jsonb)
           )
      into v_tasks
    from personal_tasks t
    where t.created_by <> t.profile_id;
  end if;

  -- -------------------------------------------------------- the complaints
  --
  -- Counts only, and that is not laziness. 0079 made the register structurally
  -- secret — the accused cannot learn who complained — and a dashboard is the
  -- easiest place in an application to undo that by accident. So: no target
  -- names, no complainant anything, and the breakdown is by TARGET TYPE, which
  -- says "eleven about employees" and names nobody.
  --
  -- Not season-scoped: a complaint is about conduct, not about a season.
  if has_permission('complaints.view') then
    select jsonb_build_object(
             'total', count(*),
             'open', count(*) filter
               (where c.locked_at is null and c.dismissed_at is null),
             'locked', count(*) filter
               (where c.locked_at is not null and c.dismissed_at is null),
             'dismissed', count(*) filter (where c.dismissed_at is not null),
             'recent', count(*) filter
               (where c.created_at >= current_date - 29),
             'by_target', coalesce((
               select jsonb_agg(jsonb_build_object('key', key, 'count', n)
                                order by n desc)
               from (
                 select c2.target_type::text as key, count(*) as n
                 from complaints c2
                 group by 1
               ) s
             ), '[]'::jsonb)
           )
      into v_complaints
    from complaints c;
  end if;

  -- ------------------------------------------------------- the evaluations
  --
  -- Season-scoped: `evaluations.season_id` is stamped at assignment.
  --
  -- `average_pct` rather than an average score, because the scores are not
  -- comparable to one another: 0084 freezes `score` beside `max_score` on
  -- purpose, since the form they were earned against will be edited afterwards
  -- and "38" without its "out of 50" means nothing a year later. A percentage
  -- is the only figure that can be averaged across sheets from different forms
  -- without lying, and it is computed from the two frozen columns.
  if has_permission('evaluations.view') then
    select jsonb_build_object(
             'total', count(*),
             'submitted', count(*) filter (where e.status = 'submitted'),
             'draft', count(*) filter (where e.status = 'draft'),
             'late', count(*) filter (
               where e.status = 'draft'
                 and e.due_on is not null
                 and e.due_on < current_date
             ),
             'evaluators', count(distinct e.evaluator_id),
             'average_pct', (
               select round(avg(e2.score / e2.max_score) * 100, 1)
               from evaluations e2
               where e2.season_id = v_season_id
                 and e2.status = 'submitted'
                 and e2.max_score is not null
                 and e2.max_score > 0
             ),
             'by_target', coalesce((
               select jsonb_agg(jsonb_build_object('key', key, 'count', n)
                                order by n desc)
               from (
                 select e3.target_type::text as key, count(*) as n
                 from evaluations e3
                 where e3.season_id = v_season_id
                 group by 1
               ) s
             ), '[]'::jsonb)
           )
      into v_evaluations
    from evaluations e
    where e.season_id = v_season_id;
  end if;

  -- ---------------------------------------------------------- the check-ins
  --
  -- Season-scoped: `place_check_ins.season_id` is stamped at insert by 0098
  -- precisely so this kind of question does not have to join back through a
  -- list whose scoping has already changed twice.
  --
  -- `today` is the number the operations room actually asks for, and it is
  -- deliberately not derived from the series below: the series is capped at
  -- thirty days for the chart, and a card that reads its headline figure off
  -- the end of a chart is a card that breaks the day somebody shortens it.
  if has_permission('checkin.board') then
    select jsonb_build_object(
             'total', count(*),
             'people', count(distinct ci.profile_id),
             'places', count(distinct ci.item_id),
             'today', count(*) filter
               (where ci.created_at >= current_date),
             'recent', count(*) filter
               (where ci.created_at >= current_date - 29),
             'series', coalesce((
               select jsonb_agg(row_to_json(d)::jsonb order by d.day)
               from (
                 select ci2.created_at::date as day, count(*) as n
                 from place_check_ins ci2
                 where ci2.season_id = v_season_id
                   and ci2.created_at >= current_date - 29
                 group by 1
               ) d
             ), '[]'::jsonb)
           )
      into v_checkin
    from place_check_ins ci
    where ci.season_id = v_season_id;
  end if;

  -- ---------------------------------------------------------- the incidents
  --
  -- Not season-scoped: an emergency belongs to the hour it happened in, and
  -- `incidents` carries no season by design.
  --
  -- `avg_minutes_to_handle` is the one figure on this whole page that measures
  -- the ROOM rather than the mission — how long an emergency sat before
  -- somebody picked it up. Computed off `handled_at`, which 0088 stamps on the
  -- first person to take it on and never overwrites, exactly so this question
  -- has an answer.
  --
  -- `open` is the number worth acting on and is why this card sits high.
  if has_permission('incidents.receive') then
    select jsonb_build_object(
             'total', count(*),
             'open', count(*) filter (where i.state = 'open'),
             'in_progress', count(*) filter (where i.state = 'in_progress'),
             'closed', count(*) filter (where i.state = 'closed'),
             'recent', count(*) filter
               (where i.created_at >= current_date - 29),
             'avg_minutes_to_handle', (
               select round(avg(
                 extract(epoch from (i2.handled_at - i2.created_at)) / 60
               )::numeric, 1)
               from incidents i2
               where i2.handled_at is not null
                 and i2.created_at >= current_date - 29
             ),
             'series', coalesce((
               select jsonb_agg(row_to_json(d)::jsonb order by d.day)
               from (
                 select i3.created_at::date as day, count(*) as n
                 from incidents i3
                 where i3.created_at >= current_date - 29
                 group by 1
               ) d
             ), '[]'::jsonb)
           )
      into v_incidents
    from incidents i;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'season', v_season,
    'people', v_people,
    'approvals', v_approvals,
    'modules', v_modules,
    'reports', v_reports,
    'ratings', v_ratings,
    'central_reports', v_central,
    'notifications', v_notifications,
    'reference', v_reference,
    'permissions', v_permissions,
    'tasks', v_tasks,
    'complaints', v_complaints,
    'evaluations', v_evaluations,
    'checkin', v_checkin,
    'incidents', v_incidents
  ));
end;
$$;

notify pgrst, 'reload schema';
