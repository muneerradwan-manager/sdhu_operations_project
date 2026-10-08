-- The roster screen is the right screen; its door was the wrong door.
--
-- `assignable_employees` (0029, filtered in 0065, renamed columns in 0085) is
-- the page this mission actually chooses people on: it searches folded Arabic
-- across the three name columns and the job title, filters by post, by city,
-- by internal/external and by "free only", pages forty at a time, and — the
-- part nothing else offers — carries **the files each candidate already serves
-- in this season**, which is the fact that decides most of these choices.
--
-- 0105 gave task assignment a picker of its own rather than this one, and that
-- was a mistake twice over: it threw all of the above away, and it read
-- `profiles` directly, which lists people who are not in the season at all.
--
-- But this function could not simply be reused, because of one line:
--
--     select is_admin() or has_permission('modules.members') as ok
--
-- A holder of `tasks.assign` who runs no operational files holds neither, and
-- would have opened the roster to a silent empty list. So the door widens by
-- exactly one grant — and it is a narrow widening, not a loose one: what this
-- function returns is a season's participants with their names, posts, phones
-- and postings, and `tasks.assign` already requires `employees.view` (0105),
-- which opens all of that on the employees screen anyway.
--
-- Nothing else in the body changes. Restated whole because `create or replace`
-- has no way to edit one line of one CTE.

create or replace function assignable_employees(
  p_season_id uuid,
  p_query text default null,
  p_is_external boolean default null,
  p_limit int default 40,
  p_offset int default 0,
  p_job_title_id uuid default null,
  p_only_free boolean default false,
  p_city_id uuid default null
)
returns table (
  id uuid,
  first_name text,
  father_name text,
  surname text,
  photo_url text,
  is_external boolean,
  external_organization text,
  external_title text,
  job_title_name text,
  job_title_name_en text,
  phone_sy text,
  phone_sa text,
  account_status text,
  assignments jsonb
)
language sql stable security definer set search_path = public as $$
  with permitted as (
    -- The one changed line. `tasks.assign` reaches the roster because a task
    -- is assigned to a PERSON, and the person has to be found first.
    select is_admin()
        or has_permission('modules.members')
        or has_permission('tasks.assign') as ok
  ),
  busy as (
    select mm.profile_id
      from module_members mm
      join modules m on m.id = mm.module_id
     where m.season_id = p_season_id
    union
    select nm.profile_id
      from module_node_members nm
      join module_nodes n on n.id = nm.node_id
      join modules m on m.id = n.module_id
     where m.season_id = p_season_id
  ),
  candidates as (
    select
      p.id, p.first_name, p.father_name, p.surname, p.photo_url,
      p.is_external, p.external_organization, p.external_title,
      jt.name_ar as job_title_name,
      jt.name_en as job_title_name_en,
      p.phone_sy, p.phone_sa, p.account_status::text as account_status
    from season_participants sp
    join profiles p on p.id = sp.profile_id
    left join reference_items jt on jt.id = p.job_title_id
    where (select ok from permitted)
      and sp.season_id = p_season_id
      and sp.status = 'active'
      and not p.is_suspended
      and (p_is_external is null or p.is_external = p_is_external)
      and (p_job_title_id is null or p.job_title_id = p_job_title_id)
      and (p_city_id is null or p.city_id = p_city_id)
      and (not coalesce(p_only_free, false)
           or p.id not in (select profile_id from busy))
      and (
        nullif(btrim(coalesce(p_query, '')), '') is null
        or ar_fold(concat_ws(' ', p.first_name, p.father_name, p.surname))
             like '%' || ar_fold(btrim(p_query)) || '%'
        or ar_fold(coalesce(jt.name_ar, '')) like '%' || ar_fold(btrim(p_query)) || '%'
        or ar_fold(coalesce(jt.name_en, '')) like '%' || ar_fold(btrim(p_query)) || '%'
      )
  )
  select
    c.id, c.first_name, c.father_name, c.surname, c.photo_url,
    c.is_external, c.external_organization, c.external_title,
    c.job_title_name, c.job_title_name_en,
    c.phone_sy, c.phone_sa, c.account_status,
    coalesce(f.files, '[]'::jsonb) as assignments
  from candidates c
  left join lateral (
    select jsonb_agg(
             jsonb_build_object(
               'module_id',  a.module_id,
               'name_ar',    a.name_ar,
               'name_en',    a.name_en,
               'hijri_year', a.hijri_year
             )
             order by a.name_ar
           ) as files
    from (
      select m.id as module_id, mt.name_ar, mt.name_en, s.hijri_year
        from module_members mm
        join modules m       on m.id = mm.module_id
        join module_types mt on mt.id = m.module_type_id
        join seasons s       on s.id = m.season_id
       where mm.profile_id = c.id
         and m.season_id = p_season_id
      union
      select m.id, mt.name_ar, mt.name_en, s.hijri_year
        from module_node_members nm
        join module_nodes n  on n.id = nm.node_id
        join modules m       on m.id = n.module_id
        join module_types mt on mt.id = m.module_type_id
        join seasons s       on s.id = m.season_id
       where nm.profile_id = c.id
         and m.season_id = p_season_id
    ) a
  ) f on true
  order by concat_ws(' ', c.first_name, c.father_name, c.surname)
  limit greatest(coalesce(p_limit, 40), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$$;
