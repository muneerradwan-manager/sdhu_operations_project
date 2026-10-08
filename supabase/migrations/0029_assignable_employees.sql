-- Choosing who goes into a file, from the database rather than from memory.
--
-- Until now the editor pulled every active participant of the season in one go
-- and filtered them in the app. That is fine at fifty people and wrong at five
-- hundred: the whole roster crosses the wire so that someone can type three
-- letters into a bottom sheet.
--
-- So the question moves to where the data is. One call answers all of it —
-- search by name or by job title, narrow to external or internal, a page at a
-- time — and carries back the one fact the person choosing actually needs and
-- could not see before: whether this employee is already serving in another
-- file, and which. Somebody already running a tower is not free to also run the
-- kitchens, and that has to be visible at the moment of choosing, not after.
--
-- SECURITY DEFINER, and it must be. `profiles_select` shows an ordinary
-- employee only himself, the people he shares a file with, and nobody else; a
-- manager assigning people would see almost no one. The permission to assign is
-- what is checked here instead, and it is checked before a single row is read.

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
  phone_sy text,
  phone_sa text,
  account_status text,
  -- The files this employee already holds a role in, newest season first:
  -- [{module_id, name_ar, name_en, hijri_year}]. Empty array, never null, so
  -- the app has one shape to read.
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
      p.phone_sy, p.phone_sa, p.account_status::text as account_status
    from season_participants sp
    join profiles p on p.id = sp.profile_id
    left join job_titles jt on jt.id = p.job_title_id
    where (select ok from permitted)
      and sp.season_id = p_season_id
      and sp.status = 'active'
      and not p.is_suspended
      and (p_is_external is null or p.is_external = p_is_external)
      -- A name is three columns, and nobody searching types them apart. The
      -- job title is searched with them: "من هم المطوفون" is the same question.
      and (
        nullif(btrim(coalesce(p_query, '')), '') is null
        or concat_ws(' ', p.first_name, p.father_name, p.surname)
             ilike '%' || btrim(p_query) || '%'
        or coalesce(jt.name, '') ilike '%' || btrim(p_query) || '%'
      )
  )
  select
    c.id, c.first_name, c.father_name, c.surname, c.photo_url,
    c.is_external, c.external_organization, c.external_title,
    c.job_title_name, c.phone_sy, c.phone_sa, c.account_status,
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
      -- A role held on the file itself, and a role held somewhere in its tree,
      -- are the same fact here. `union` folds away the person who holds three
      -- towers in one file: it is one file either way.
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

-- No index on the search, deliberately. It matches anywhere inside a name, so
-- only a trigram index could serve it — and it is never asked of the whole
-- table: `season_id` and `status` cut the candidates down to one season's
-- participants first, on indexes that already exist, and the pattern is then
-- tried against those few hundred rows. Indexing that is paying for a scan
-- which does not happen.
