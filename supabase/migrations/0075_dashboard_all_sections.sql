-- The dashboard answers for the whole project, not most of it.
--
-- Four sections the app has screens for had no numbers here: the central
-- reports, the notifications, the master data, and the permissions. Same
-- contract as every existing block — the function computes freely (security
-- definer) and then hands back only the sections this reader's permissions
-- cover; an absent section is "you may not ask", which is not a zero.
--
-- Gates, following each section's own screen:
--   central_reports -> reports.view_all      (the office; drafts are theirs)
--   notifications   -> any of the three send permissions
--   reference       -> reference.view
--   permissions     -> permissions.view

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
             'by_job_title', coalesce((
               select jsonb_agg(row_to_json(t)::jsonb order by t.n desc)
               from (
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
    'permissions', v_permissions
  ));
end;
$$;
