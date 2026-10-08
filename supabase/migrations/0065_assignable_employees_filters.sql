-- Finding a man in the picker, whatever way his name was spelled.
--
-- The directory learned this in Dart: أ إ آ and ا are one letter, ة and ه are
-- one letter, ى and ي are one letter, and harakat are not typed into a search
-- box. The picker never learned it, because its search is not in Dart — it is
-- an `ilike` inside `assignable_employees`, running over a page of forty at a
-- time, so no amount of client-side folding can reach the rows it never sent.
--
-- The mission's own decisions spell the same man both ways in the same week —
-- 'أحمد' and 'احمد', 'نقاوة' and 'نقاوه' — and 158 people were seeded from
-- them. A picker that answers "no results" to a hamza is wrong about somebody
-- who is standing in the list.
--
-- And two filters the picker was reading but could not act on: it already SHOWS
-- what each candidate carries this season, which is the fact most of these
-- choices turn on, and it already shows his job title. Both become questions
-- you can ask rather than columns you have to scan.

-- ---------------------------------------------------------------- the folding
--
-- IMMUTABLE, so it may be indexed later if these lists ever grow past the point
-- where a scan is free. They are hundreds of rows today; this is not that day.
-- One `translate`: where the TO string runs out, the remaining FROM characters
-- are deleted rather than replaced, so folding and stripping are one pass. The
-- marks are written as chr() codes rather than as a literal regex class — a
-- range of combining characters typed into a .sql file is a thing no reviewer
-- can check and an editor can silently mangle.
create or replace function ar_fold(p text) returns text
  language sql immutable parallel safe as $$
  select lower(
    translate(
      coalesce(p, ''),
      -- folded to the letter beneath them ...
      'أإآٱةىؤئ'
      -- ... Arabic-Indic digits to ASCII ...
      || '٠١٢٣٤٥٦٧٨٩'
      || '۰۱۲۳۴۵۶۷۸۹'
      -- ... and everything past here has no counterpart below, so it is
      -- dropped: tatweel, then tanween, harakat, shadda, sukun, the hamza and
      -- maddah marks, and the superscript alef.
      || chr(1600)
      || chr(1611) || chr(1612) || chr(1613) || chr(1614) || chr(1615)
      || chr(1616) || chr(1617) || chr(1618) || chr(1619) || chr(1620)
      || chr(1621) || chr(1648),
      'ااااهيوي'
      || '0123456789' || '0123456789'
    )
  );
$$;

comment on function ar_fold(text) is
  'The comparable form of an Arabic string: hamza seats folded onto their '
  'letters, taa marbuta to haa, alif maqsura to yaa, harakat and tatweel '
  'dropped. Mirrors foldArabic() in lib/core/utils/arabic_search.dart — the two '
  'must agree, or the directory and the picker will disagree about a name.';

-- ------------------------------------------------------------ the picker
--
-- Two new parameters, both defaulted, so every existing caller keeps working:
--
--   p_job_title_id   only this post — "show me the مشرفون"
--   p_city_id        only people from this Syrian city
--   p_only_free      only people carrying nothing in this season yet
--
-- p_only_free is the picker's own question turned around. It is applied against
-- the same two tables the assignments column is built from, and against the
-- same season, so what it hides is exactly what would have shown a file badge.

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
    select is_admin()
        or has_permission('modules.members')
        or has_permission('modules.manage') as ok
  ),
  -- Everyone already carrying something in the season being staffed. Gathered
  -- once rather than asked per candidate.
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
      and (p_job_title_id is null or p.job_title_id = p_job_title_id)
      and (p_city_id is null or p.city_id = p_city_id)
      and (not coalesce(p_only_free, false)
           or p.id not in (select profile_id from busy))
      -- A name is three columns, and nobody searching types them apart. The
      -- job title is searched with them: "من هم المطوفون" is the same question.
      -- Both sides folded, so the spelling the reader used does not have to be
      -- the spelling the Administration filed.
      and (
        nullif(btrim(coalesce(p_query, '')), '') is null
        or ar_fold(concat_ws(' ', p.first_name, p.father_name, p.surname))
             like '%' || ar_fold(btrim(p_query)) || '%'
        or ar_fold(coalesce(jt.name, '')) like '%' || ar_fold(btrim(p_query)) || '%'
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

-- The old five-argument signature is gone: `create or replace` cannot change a
-- parameter list, so Postgres kept BOTH and a five-argument call would have
-- silently gone on reaching the un-folded version.
drop function if exists assignable_employees(uuid, text, boolean, int, int);

revoke execute on function
  assignable_employees(uuid, text, boolean, int, int, uuid, boolean, uuid)
  from public, anon;
grant execute on function
  assignable_employees(uuid, text, boolean, int, int, uuid, boolean, uuid)
  to authenticated;
