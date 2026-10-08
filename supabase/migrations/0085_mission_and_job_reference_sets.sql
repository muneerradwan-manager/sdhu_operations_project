-- نوع البعثة and الوصف الوظيفي become master data, like everything else.
--
-- Both were the two lists the admin could NOT edit. The job description lived in
-- its own table (0002) with no screen anywhere in the app — a list only somebody
-- with the database in front of them could change. The mission type was worse: a
-- Postgres enum, three values fixed in 0001, so adding a fourth was a migration
-- rather than a decision.
--
-- Neither is different in kind from the cities of 0023 or the hotels of 0019.
-- They are lists the office owns, chosen from a dropdown, and the catalog built
-- for exactly that is already there and already has a screen. So they move into
-- it:
--
--   reference_sets 'job_titles'    الوصف الوظيفي
--   reference_sets 'mission_types' نوع البعثة
--
-- and البيانات المرجعية gains two cards without a line of screen code, which is
-- the whole point of a generic catalog.
--
-- The job descriptions keep their ids. `profiles.job_title_id` holds them, and
-- every module, decision and report that named a person by their post keeps
-- naming them: the row moved tables, it did not become a different row.

-- ------------------------------------------------------------------- the lists

insert into reference_sets (code, name_ar, name_en) values
  ('job_titles',    'الوصف الوظيفي', 'Job description'),
  ('mission_types', 'نوع البعثة',    'Mission type')
on conflict (code) do nothing;

-- ------------------------------------------------- الوصف الوظيفي moves across
--
-- Same ids, so `profiles.job_title_id` needs no rewriting — only a new target
-- for its foreign key.
--
-- `on conflict do nothing` covers the one shape the old table allowed and the
-- new one does not: its unique index was on the ACTIVE names only, so two rows
-- could share a name if one was retired. The retired twin is dropped and the
-- profiles that pointed at it are moved onto the surviving row below.
--
-- Wrapped so the file can be run twice. The old table is gone after the first
-- pass, and a bare statement naming it would not even parse; inside a branch
-- that is never taken, PL/pgSQL never looks at it.

do $$
begin
  if to_regclass('public.job_titles') is null then
    raise notice '0085: job_titles already moved into the catalog';
    return;
  end if;

  insert into reference_items (id, set_id, name_ar, name_en, is_active)
  select jt.id, rs.id, jt.name, jt.name_en, jt.is_active
    from job_titles jt
    join reference_sets rs on rs.code = 'job_titles'
  on conflict do nothing;

  update profiles p
     set job_title_id = ri.id
    from job_titles jt
    join reference_sets rs on rs.code = 'job_titles'
    join reference_items ri on ri.set_id = rs.id and ri.name_ar = jt.name
   where p.job_title_id = jt.id
     and ri.id <> jt.id;
end
$$;

alter table profiles drop constraint if exists profiles_job_title_id_fkey;
alter table profiles
  add constraint profiles_job_title_id_fkey
  foreign key (job_title_id) references reference_items (id) on delete restrict;

create index if not exists idx_profiles_job_title on profiles (job_title_id);

-- ---------------------------------------------------- نوع البعثة becomes a row
--
-- The three the enum held, worded exactly as the app worded them, so nothing a
-- reader sees changes on the day this runs. What changes is that a fourth can be
-- added by an admin instead of by a migration.

insert into reference_items (set_id, name_ar, name_en, sort_order)
select rs.id, v.name_ar, v.name_en, v.sort_order
  from (values
    ('البعثة الإدارية', 'Administrative mission', 1),
    ('البعثة الدينية',  'Religious mission',      2),
    ('البعثة الطبية',   'Medical mission',        3)
  ) as v(name_ar, name_en, sort_order)
  join reference_sets rs on rs.code = 'mission_types'
-- Untargeted: 0040 traded the (set_id, name_ar) constraint for an expression
-- index over the season as well, and no column list names that.
on conflict do nothing;

-- The view is `select *` expanded once at creation (see 0032), so it holds the
-- old `mission_type` column by name and would refuse to let it be dropped. It is
-- rebuilt at the end of this file against the table as it stands then.
drop view if exists permanent_employees;

alter table profiles
  add column if not exists mission_type_id uuid
    references reference_items (id) on delete restrict;

create index if not exists idx_profiles_mission_type on profiles (mission_type_id);

-- Guarded for the same reason the move above is: on a second run the enum
-- column this reads is already gone.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public'
       and table_name = 'profiles'
       and column_name = 'mission_type'
  ) then
    raise notice '0085: profiles.mission_type already retired';
    return;
  end if;

  update profiles p
     set mission_type_id = ri.id
    from reference_items ri
    join reference_sets rs on rs.id = ri.set_id
    join (values
      ('administrative', 'البعثة الإدارية'),
      ('religious',      'البعثة الدينية'),
      ('medical',        'البعثة الطبية')
    ) as m(legacy, name_ar) on m.name_ar = ri.name_ar
   where rs.code = 'mission_types'
     and p.mission_type::text = m.legacy;
end
$$;

alter table profiles drop column if exists mission_type;
drop type if exists mission_type_enum;

drop table if exists job_titles;

create view permanent_employees
  with (security_invoker = true) as
  select *
  from profiles
  where is_external = false
    and account_status = 'approved';

-- ------------------------------------------------------------ readable at signup
--
-- Both lists are answered by somebody who is not approved yet — they are the
-- registration form itself. `job_titles` carried that exception on its own table
-- from 0007; `syrian_cities` was given it on the catalog in 0030. Now three lists
-- share one policy, for the one reason: a form field is not a secret.

drop policy if exists reference_sets_select_signup on reference_sets;
create policy reference_sets_select_signup on reference_sets for select
  to authenticated using (
    code in ('syrian_cities', 'job_titles', 'mission_types')
  );

drop policy if exists reference_items_select_signup on reference_items;
create policy reference_items_select_signup on reference_items for select
  to authenticated using (
    exists (
      select 1 from reference_sets s
      where s.id = reference_items.set_id
        and s.code in ('syrian_cities', 'job_titles', 'mission_types')
    )
  );

-- ------------------------------------------------------------------- in use
--
-- A post somebody holds, and a mission somebody is on, cannot be deleted from
-- the list. Both foreign keys would refuse it anyway; naming them here is what
-- lets the app show the translated explanation instead of a constraint error —
-- the same argument 0030 made for the city.

create or replace function reference_item_in_use(p_item_id uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select
    exists (
      select 1
      from modules m
      join module_type_fields f on f.module_type_id = m.module_type_id
      where f.kind = 'reference'
        and m.data ->> f.key = p_item_id::text
    )
    or exists (
      select 1 from module_nodes where reference_item_id = p_item_id
    )
    or exists (
      select 1
      from reference_items i
      join reference_set_fields f on f.set_id = i.set_id
      where f.kind = 'reference'
        and i.data ->> f.key = p_item_id::text
    )
    or exists (
      select 1 from profiles
      where city_id = p_item_id
         or job_title_id = p_item_id
         or mission_type_id = p_item_id
    );
$$;

-- ------------------------------------------------------ the functions that read
--
-- Three joined `job_titles`. Same query, one table to the left.

-- The picker serves staffing, and staffing is modules.members. (0073, repointed.)
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
    select is_admin() or has_permission('modules.members') as ok
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

-- Who may be handed the errand. (0084, repointed — and the column name it asked
-- `job_titles` for, `name_ar`, is the one the catalog actually has.)
create or replace function evaluation_evaluators(
  p_query text default null,
  p_limit int default 100
)
returns table (id uuid, name text, photo_url text, job_title text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 200);
begin
  if not can_assign_evaluation() then
    return;
  end if;

  return query
  select p.id,
         nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
         p.photo_url,
         (select j.name_ar from reference_items j where j.id = p.job_title_id)
    from profiles p
   where p.account_status = 'approved'
     and not p.is_suspended
     and (v_query is null
          or concat_ws(' ', p.first_name, p.father_name, p.surname)
               ilike '%' || v_query || '%')
   order by 2
   limit v_limit;
end;
$$;

-- The dashboard. (0075, repointed.)
--
-- `by_mission` changes shape with the column: it used to hand back the enum key
-- and let the app word it, and there is no longer an enum for the app to know
-- the wording of. It now carries the two names the list holds, like `by_job_title`
-- and `by_type` beside it — the reader picks a language, the database does not.
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

-- profiles now points at reference_items three times over — the city, the post
-- and the mission — so every embed of it must name the column it means. The
-- schema cache is what decides whether it can.
notify pgrst, 'reload schema';
