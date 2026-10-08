-- What this person already carries THIS season.
--
-- The picker shows, beside every candidate, the files he already serves in —
-- the one fact that decides most of these choices, and the reason 0029 exists.
-- But it gathered them from every season the man has ever worked, so somebody
-- staffing 1448 was reading that a candidate is busy in 1443. Five years ago.
--
-- Nobody is busy in a season that has ended. The question the picker is asking
-- is "is he free NOW", and now is the season being staffed — which the function
-- already receives, and already uses to decide who is a candidate at all. It
-- simply was not applied to what they are carrying.
--
-- Everything else is 0046 unchanged. The `hijri_year` stays in the row: it costs
-- nothing, and a caller that one day wants the history will find the shape
-- waiting rather than needing another function.

create or replace function assignable_employees(
  p_season_id uuid,
  p_query text default null,
  p_is_external boolean default null,
  p_limit int default 40,
  p_offset int default 0
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
    select is_admin()
        or has_permission('modules.members')
        or has_permission('modules.manage') as ok
  ),
  candidates as (
    select
      p.id, p.first_name, p.father_name, p.surname, p.photo_url,
      p.is_external, p.external_organization, p.external_title,
      jt.name as job_title_name,
      jt.name_en as job_title_name_en,
      p.phone_sy, p.phone_sa, p.account_status::text as account_status
    from season_participants sp
    join profiles p on p.id = sp.profile_id
    left join job_titles jt on jt.id = p.job_title_id
    where (select ok from permitted)
      and sp.season_id = p_season_id
      and sp.status = 'active'
      and not p.is_suspended
      and (p_is_external is null or p.is_external = p_is_external)
      and (
        nullif(btrim(coalesce(p_query, '')), '') is null
        or concat_ws(' ', p.first_name, p.father_name, p.surname)
             ilike '%' || btrim(p_query) || '%'
        or coalesce(jt.name, '') ilike '%' || btrim(p_query) || '%'
        or coalesce(jt.name_en, '') ilike '%' || btrim(p_query) || '%'
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
      -- Both halves filtered to the season being staffed. A file of an earlier
      -- season is history, and history does not make a man unavailable.
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

revoke execute on function assignable_employees(uuid, text, boolean, int, int)
  from public, anon;
grant execute on function assignable_employees(uuid, text, boolean, int, int)
  to authenticated;
