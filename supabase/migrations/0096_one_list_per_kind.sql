-- Folding 0095's first shape into its second.
--
-- 0095 was executed twice, in two different versions of itself. The first drew
-- the model from the spellings — مكة writes القطاع الأول and المشاعر writes
-- القطاع 1 — and so made a list per FILE: makkah_sectors, mashaaer_sectors,
-- arafat_centers, mina_centers, mina_camps. The second, which is the model
-- that stands, makes a list per KIND — sectors, centers, camps — and gives the
-- entry a نوع where a kind really has variants.
--
-- The second run could not undo the first. Every statement in it that migrates
-- data is guarded by `n.reference_item_id is null`, and by then the first run
-- had already pointed every node at an entry. So it created the new lists,
-- found nothing left to move into them, and left the catalog holding both
-- models at once: the levels pointing at the first run's lists, and the second
-- run's lists standing empty beside them. The one exception is عرفات's camps,
-- which the first run had not reached, and which are already in `camps` with
-- their مشعر — the only part of the season that needs nothing here.
--
-- The guards were right. A migration that overwrites regardless of what it
-- finds is a migration you cannot run twice, and this is the season being run.
-- What they could not do is recognise a DIFFERENT migration's work, which is
-- what this one is for.
--
-- Nothing is re-derived from labels: the names are taken from the entries the
-- first run built, so a name corrected by hand between the two runs is carried
-- rather than overwritten by whatever the node used to say.

-- The digit and the word are one sector. Same function 0095 used, restated
-- because it dropped itself at the end — and because here it is applied to an
-- ENTRY's name rather than a node's label, which is the same normalisation
-- asked of different text.
create or replace function entry_name_of(p_label text)
returns text language sql immutable as $$
  select coalesce(
    (select 'القطاع ' || o.word
       from (values ('1', 'الأول'),  ('2', 'الثاني'), ('3', 'الثالث'),
                    ('4', 'الرابع'), ('5', 'الخامس'), ('6', 'السادس'),
                    ('7', 'السابع'), ('8', 'الثامن'), ('9', 'التاسع'),
                    ('10', 'العاشر')) as o(n, word)
      where btrim(coalesce(p_label, '')) = 'القطاع ' || o.n),
    nullif(btrim(regexp_replace(coalesce(p_label, ''),
                                '\s*[—–-]\s*خيمة\s.*$', '')), ''),
    nullif(btrim(coalesce(p_label, '')), '')
  )
$$;

-- ------------------------------------------------------- the entries, merged
--
-- Two old lists become one, and the نوع that told them apart moves onto the
-- entry. مكة's five sectors and المشاعر's seven meet here for the first time:
-- normalised, القطاع الأول through القطاع الخامس are the SAME five rows, and
-- the union is seven.

insert into reference_items
  (set_id, name_ar, name_en, season_id, data, sort_order)
with merge (old_code, new_code, site_ar) as (values
  ('makkah_sectors',   'sectors', null),
  ('mashaaer_sectors', 'sectors', null),
  ('arafat_centers',   'centers', 'عرفات'),
  ('mina_centers',     'centers', 'منى'),
  ('mina_camps',       'camps',   'منى')
)
select tgt.id,
       entry_name_of(ri.name_ar),
       max(ri.name_en),
       case when tgt.is_season_scoped then ri.season_id end,
       coalesce(
         jsonb_strip_nulls(jsonb_build_object(
           'site', site.id::text,
           -- max() over the group, because two old lists may each hold a row
           -- for what is now one entry and only one of them may know where it
           -- stands. max skips nulls.
           'location', max(ri.data ->> 'location'),
           'capacity', max(ri.data ->> 'capacity')
         )),
         '{}'::jsonb
       ),
       min(ri.sort_order)
  from reference_items ri
  join reference_sets src on src.id = ri.set_id
  join merge mg on mg.old_code = src.code
  join reference_sets tgt on tgt.code = mg.new_code
  left join reference_sets sites on sites.code = 'holy_sites'
  left join reference_items site
    on site.set_id = sites.id and site.name_ar = mg.site_ar
 group by tgt.id,
          tgt.is_season_scoped,
          entry_name_of(ri.name_ar),
          case when tgt.is_season_scoped then ri.season_id end,
          site.id
on conflict do nothing;

-- --------------------------------------------------------- the nodes, moved
--
-- From the first run's entry to the one that replaces it. The نوع must match as
-- well as the name, or a منى node would find عرفات's مركز 11 — which is why the
-- نوع is part of the identity and not a note on it.

with merge (old_code, new_code, site_ar) as (values
  ('makkah_sectors',   'sectors', null),
  ('mashaaer_sectors', 'sectors', null),
  ('arafat_centers',   'centers', 'عرفات'),
  ('mina_centers',     'centers', 'منى'),
  ('mina_camps',       'camps',   'منى')
)
update module_nodes n
   set reference_item_id = fresh.id
  from reference_items stale,
       reference_sets src,
       merge mg,
       reference_sets tgt,
       reference_items fresh
 where stale.id = n.reference_item_id
   and src.id = stale.set_id
   and mg.old_code = src.code
   and tgt.code = mg.new_code
   and fresh.set_id = tgt.id
   and fresh.name_ar = entry_name_of(stale.name_ar)
   and fresh.season_id is not distinct from
       (case when tgt.is_season_scoped then stale.season_id end)
   and fresh.variant is not distinct from (
     select site.id::text
       from reference_items site
       join reference_sets sites
         on sites.id = site.set_id and sites.code = 'holy_sites'
      where site.name_ar = mg.site_ar
   );

-- ------------------------------------------------ the levels, pointed afresh
--
-- No `where reference_set_id is null` guard here, unlike 0095. That guard is
-- what stopped the second run from correcting the first, and the whole purpose
-- of this migration is to overwrite a pointer that is set and wrong. The map
-- names every level it touches, so the tower and the تكتل are not in reach.

with lvmap (type_code, level_code, set_code, site_ar) as (values
  ('makkah_sectors_towers',  'sector', 'sectors', null),
  ('mashaaer_teams',         'sector', 'sectors', null),
  ('arafat_camp_assignment', 'center', 'centers', 'عرفات'),
  ('mina_camp_assignment',   'center', 'centers', 'منى'),
  ('arafat_camp_assignment', 'camp',   'camps',   'عرفات'),
  ('mina_camp_assignment',   'camp',   'camps',   'منى')
)
update module_type_levels lv
   set reference_set_id = rs.id,
       reference_filter = case
         when m.site_ar is null then null
         else jsonb_build_object('site', (
           select site.id::text
             from reference_items site
             join reference_sets sites
               on sites.id = site.set_id and sites.code = 'holy_sites'
            where site.name_ar = m.site_ar
         ))
       end
  from module_types mt, lvmap m, reference_sets rs
 where mt.id = lv.module_type_id
   and m.type_code = mt.code
   and m.level_code = lv.code
   and rs.code = m.set_code;

-- --------------------------------------------------- the first run's lists
--
-- Guarded at every step, and the guards are the report: a list that refuses to
-- go is a list something still points at, which is worth seeing rather than
-- forcing. `module_nodes.reference_item_id` is `on delete restrict` anyway, so
-- an unguarded delete would raise instead of orphaning — but it would raise
-- without saying which of the five, and with the others already gone.

delete from reference_items ri
 using reference_sets rs
 where rs.id = ri.set_id
   and rs.code in ('makkah_sectors', 'mashaaer_sectors', 'arafat_centers',
                   'mina_centers', 'mina_camps')
   and not exists (
     select 1 from module_nodes n where n.reference_item_id = ri.id
   )
   and not exists (
     select 1 from module_nodes n
      where n.secondary_reference_item_id = ri.id
   );

delete from reference_sets rs
 where rs.code in ('makkah_sectors', 'mashaaer_sectors', 'arafat_centers',
                   'mina_centers', 'mina_camps')
   and not exists (select 1 from reference_items ri where ri.set_id = rs.id)
   and not exists (
     select 1 from module_type_levels lv
      where lv.reference_set_id = rs.id
         or lv.secondary_reference_set_id = rs.id
   )
   and not exists (
     select 1 from reference_set_fields f where f.reference_set_id = rs.id
   );

drop function if exists entry_name_of(text);

-- ------------------------------------------------------- the names that stuck
--
-- The first run named it «شركات الخدمة (المدينة)» and the second could not
-- rename it: `on conflict (code) do nothing` met a code that already existed
-- and left the row alone, name included. The parenthetical is wrong on its own
-- terms — the service companies have no relation to the city, and naming them
-- by where one file happens to use them is the same mistake as a list per file.
--
-- The `syrian_cities` rename and its location field are restated here for the
-- same reason: whether the second run reached them depends on where it stopped,
-- and both are idempotent.

update reference_sets
   set name_ar = 'شركات الخدمة', name_en = 'Service companies'
 where code = 'service_companies';

update reference_sets
   set name_ar = 'مكاتب إدارة الحج والعمرة',
       name_en = 'Hajj and Umrah Administration offices'
 where code = 'syrian_cities';

insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, is_required, sort_order)
select rs.id, 'location', 'موقع المكتب', 'Office location',
       'location'::module_field_kind, false, 1
from reference_sets rs
where rs.code = 'syrian_cities'
on conflict (set_id, key) do nothing;

-- ------------------------------------------------------------------ the report
--
-- Two questions, and the second is the one that matters: is anything still
-- standing on the first run's model. A row under "left over" means a list
-- refused to go, and names what is holding it.

select 'list' as part,
       rs.code as name,
       count(distinct ri.id)::text as entries,
       coalesce(string_agg(distinct ri.name_ar, ' · ' order by ri.name_ar), '—')
         as detail
  from reference_sets rs
  left join reference_items ri on ri.set_id = rs.id
 where rs.code in ('sectors', 'centers', 'camps', 'service_companies',
                   'holy_sites')
 group by rs.code

union all

select 'left over',
       rs.code,
       (select count(*) from reference_items ri where ri.set_id = rs.id)::text,
       coalesce(
         (select string_agg(distinct mt.code || '/' || lv.code, ' · ')
            from module_type_levels lv
            join module_types mt on mt.id = lv.module_type_id
           where lv.reference_set_id = rs.id),
         'entries still pointed at by nodes'
       )
  from reference_sets rs
 where rs.code in ('makkah_sectors', 'mashaaer_sectors', 'arafat_centers',
                   'mina_centers', 'mina_camps')

 order by 1, 2;
