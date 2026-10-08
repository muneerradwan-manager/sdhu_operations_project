-- A job title in the language the reader chose.
--
-- Everything else in this app that is content rather than interface — module
-- types, their fields, roles, the reference lists — carries both languages in
-- the row and resolves against the locale. Job titles never did: the column is
-- one `name`, seeded in Arabic (0010), and it is joined into the profile header,
-- the directory, the approval queue and every list of people. So an app switched
-- to English showed "أحمد الدائم" under an English heading with "مدير إداري"
-- beneath it.
--
-- `name` stays the Arabic one rather than being renamed to `name_ar`. It is the
-- source language, it is what the unique index and `assignable_employees` are
-- written against, and renaming a column that a live function reads buys
-- consistency with a risk that this change does not need.

alter table job_titles add column if not exists name_en text;

comment on column job_titles.name is
  'Arabic name — the source language, and what is shown when name_en is empty.';
comment on column job_titles.name_en is
  'English name. Optional: a title added without one falls back to Arabic.';

-- The eleven seeded in 0010. Matched on the Arabic rather than on an id, since
-- the ids are generated per environment.
update job_titles set name_en = v.en
from (values
  ('رئيس البعثة',       'Head of Mission'),
  ('نائب رئيس البعثة',  'Deputy Head of Mission'),
  ('مدير إداري',        'Administrative Manager'),
  ('مشرف',              'Supervisor'),
  ('موظف إداري',        'Administrative Officer'),
  ('مترجم',             'Interpreter'),
  ('مرشد ديني',         'Religious Guide'),
  ('طبيب',              'Doctor'),
  ('ممرض',              'Nurse'),
  ('سائق',              'Driver'),
  ('عامل خدمات',        'Service Worker')
) as v(ar, en)
where job_titles.name = v.ar
  and (job_titles.name_en is null or job_titles.name_en = '');

-- ------------------------------------------------------- assignable_employees
--
-- Recreated rather than replaced: the returned row gains a column, and that is
-- a different signature. The body is 0029's, unchanged except for carrying the
-- English name through and searching it alongside the Arabic — someone typing
-- "driver" into the picker of an English app is asking the same question as
-- someone typing "سائق".

drop function if exists assignable_employees(uuid, text, boolean, int, int);

create function assignable_employees(
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
             order by a.hijri_year desc nulls last, a.name_ar
           ) as files
    from (
      select m.id as module_id, mt.name_ar, mt.name_en, s.hijri_year
        from module_members mm
        join modules m       on m.id = mm.module_id
        join module_types mt on mt.id = m.module_type_id
        join seasons s       on s.id = m.season_id
       where mm.profile_id = c.id
      union
      select m.id, mt.name_ar, mt.name_en, s.hijri_year
        from module_node_members nm
        join module_nodes n  on n.id = nm.node_id
        join modules m       on m.id = n.module_id
        join module_types mt on mt.id = m.module_type_id
        join seasons s       on s.id = m.season_id
       where nm.profile_id = c.id
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
