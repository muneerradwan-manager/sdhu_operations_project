-- Nothing is authored inside a file any more. A file is a tree of CHOICES.
--
-- Seven levels were still typed by hand: the قطاعات of مكة and of المشاعر, the
-- مراكز of عرفات and of منى, the مخيمات of منى, the شركات خدمة of المدينة —
-- and, unexpectedly, the مخيمات of عرفات, whose level 0050 wired to a list but
-- which the live catalog shows unwired, its `arafat_camps` set sitting empty
-- while the camps were typed in by hand. Whatever unwired it, the effect is the
-- drift this ends: the same thing in the world, entered afresh in every file and
-- every season, spelled a little differently each time.
--
-- ONE list per kind of thing. A first draft of this made two sector lists and
-- two centre lists, reasoning from the spellings: مكة writes القطاع الأول and
-- المشاعر writes القطاع 1, so they looked like two divisions. They are one
-- division written two ways, and the digits are normalised into the words
-- below. مكة runs five of the seven; المشاعر runs all seven.
--
-- Where a kind really does come in variants, the variant is a FIELD on the
-- entry and not a second list: a مخيم and a مركز each name their مشعر. That is
-- what "one list with a نوع" has to mean once you look at the names, because
-- المخيم رقم 11 exists at منى and again at عرفات and they are different ground.
-- The نوع is therefore part of the entry's identity, not a label on it — see
-- the uniqueness below — and a level draws the slice of the list that is its
-- own, through `reference_filter`.
--
-- What moves and what stays is decided by one question: does the fact belong to
-- the place, or to this office's share of it? The camp's موقع and طاقة belong to
-- the camp and move to the entry. The خيمة and the جهات مخصّصة are the share and
-- stay on the node. That split is what makes the next season a copy instead of a
-- retyping, and it is the leak 0052 left open for عرفات, whose camps drew their
-- identity from a list while their coordinates were rewritten per file.

-- ------------------------------------------------- a level draws its own slice
--
-- The one genuinely new mechanism here. Until now a level took a WHOLE list:
-- the tower level takes the hotels, all of them. One list with a نوع cannot
-- work that way — the منى file would offer عرفات's camps, and a camp entered in
-- the wrong مشعر is a mistake no later rule can catch, because the row is
-- perfectly well-formed and simply false.
--
-- A jsonb rather than a key/value pair of columns, so a second discriminator
-- costs no migration. Matched with `@>` against the entry's own `data`.

alter table module_type_levels
  add column if not exists reference_filter jsonb;

comment on column module_type_levels.reference_filter is
  'Narrows reference_set_id to the entries whose data contains this. '
  '{"site": "<uuid of منى>"} on the Mina camp level, so one مخيمات list serves '
  'both مشعرين. Null takes the whole list, which is every other level.';

-- ------------------------------------------------------ a name, within its نوع
--
-- 0040 made a name unique per (set, season) so that فندق الصفوة could be a row
-- in 1447 and again in 1448. The نوع needs the same allowance for the same
-- reason: المخيم رقم 11 is a row at منى and another at عرفات, in one list, in
-- one season, and they are two places a kilometre apart.
--
-- A generated column rather than an expression in the index, so that the fact
-- "the مشعر is part of what identifies a camp" is written on the table where a
-- reader meets it, rather than buried in an index definition.

alter table reference_items
  add column if not exists variant text
  generated always as (nullif(btrim(data ->> 'site'), '')) stored;

comment on column reference_items.variant is
  'The نوع that is part of an entry''s identity rather than a fact about it: '
  'the مشعر of a مخيم or a مركز. Null in every list that has no variants, '
  'which restores the plain per-season uniqueness. Read only by '
  'uq_reference_items_name_per_season.';

drop index if exists uq_reference_items_name_per_season;

create unique index uq_reference_items_name_per_season
  on reference_items (
    set_id,
    name_ar,
    coalesce(season_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(variant, '')
  );

-- ---------------------------------------------------------- an entry, twice
--
-- 0024 allowed an entry into a file exactly once, and 0050 called that the
-- point of the camps file: "a camp assigned twice is the mistake it exists to
-- prevent." The live data disagrees, and it is right to. عرفات holds
-- "المخيم رقم 16 — خيمة 154" and "المخيم رقم 16 — خيمة 158"; منى holds camp 16
-- as tents 32 and as tents 35+36. One camp, two allotments, different bodies
-- and different people in each.
--
-- So the node was never "the camp" — it is this office's share of the camp. The
-- camp is the entry, and the share is what distinguishes two nodes standing on
-- it. The tent number already records exactly that, so it becomes the
-- discriminator rather than a new column somebody must remember to fill.
--
-- Levels with no `tents` field leave it null and keep the old rule untouched: a
-- hotel still enters a file once, a تكتل still stands in one tower.

alter table module_nodes
  add column if not exists entry_slot text
  generated always as (nullif(btrim(data ->> 'tents'), '')) stored;

comment on column module_nodes.entry_slot is
  'What distinguishes two nodes standing on the same entry in one file: the '
  'tent allotment. Null wherever the level has no tents, which restores the '
  'plain "an entry once per file" rule. Read only by uq_module_nodes_entry.';

drop index if exists uq_module_nodes_entry;

create unique index uq_module_nodes_entry
  on module_nodes (
    module_id,
    level_id,
    reference_item_id,
    coalesce(entry_slot, '')
  )
  where reference_item_id is not null;

-- ------------------------------------------------------------------ the lists
--
-- Season-scoped only where the thing is contracted afresh each year. The
-- مخيمات are, exactly as 0050 argued — the plot is the same ground but the
-- capacity comes with the contract. A قطاع, a مركز and a شركة خدمة are not:
-- "القطاع الثالث" is the same name next season, and scoping it would mean
-- retyping the list every year to say so.

insert into reference_sets (code, name_ar, name_en, is_season_scoped)
values
  ('holy_sites',        'المشاعر',        'Holy sites',        false),
  ('sectors',           'القطاعات',       'Sectors',           false),
  ('centers',           'المراكز',        'Centers',           false),
  ('camps',             'المخيمات',       'Camps',             true),
  ('service_companies', 'شركات الخدمة',   'Service companies', false)
on conflict (code) do nothing;

-- The two that exist. مزدلفة is not seeded: the mission holds no camps there
-- and a list offering a مشعر nobody is stationed in invites the wrong pick.
insert into reference_items (set_id, name_ar, name_en, sort_order)
select rs.id, v.name_ar, v.name_en, v.sort_order
from (values
  ('منى',   'Mina',   1),
  ('عرفات', 'Arafat', 2)
) as v(name_ar, name_en, sort_order)
cross join reference_sets rs
where rs.code = 'holy_sites'
on conflict do nothing;

-- --------------------------------------------------- what an entry carries
--
-- The مشعر first, because it is the one a reader must answer before the rest
-- mean anything: a capacity belongs to a camp, and which camp depends on where.

insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, reference_set_id, is_required,
   sort_order)
select rs.id, 'site', 'المشعر', 'Holy site', 'reference'::module_field_kind,
       sites.id, true, 1
from reference_sets rs
cross join reference_sets sites
where rs.code in ('camps', 'centers')
  and sites.code = 'holy_sites'
on conflict (set_id, key) do nothing;

insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, is_required, sort_order)
select rs.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
       false, v.sort_order
from (values
  ('capacity', 'الطاقة الاستيعابية', 'Capacity', 'number',   2),
  ('location', 'موقع المخيم',        'Location', 'location', 3)
) as v(key, label_ar, label_en, kind, sort_order)
cross join reference_sets rs
where rs.code = 'camps'
on conflict (set_id, key) do nothing;

-- ------------------------------------------------- the typed names, made real
--
-- The mapping is repeated in each statement below rather than held in a temp
-- table. Supabase's SQL editor may run statements in separate transactions —
-- 0003 discovered that the hard way, when a temp table vanished between one
-- statement and the next.

-- What a typed label was really naming.
--
-- A function rather than the expression written out four times: the insert
-- below and the update after it must agree exactly, or a node finds no entry to
-- point at and is silently left holding a label at a level that now expects an
-- entry. Dropped at the end; it has no life beyond this migration.
--
--   1. "القطاع 3" is "القطاع الثالث". مكة writes the word, المشاعر the digit,
--      and until now nothing made them meet.
--   2. "المخيم رقم 16 — خيمة 154" is camp 16. The tail is the allotment.
--   3. A label that is nothing but a tail keeps itself, rather than becoming an
--      entry named '' onto which every such node in the file would collapse.
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

insert into reference_items (set_id, name_ar, season_id, data, sort_order)
with mapping (type_code, level_code, set_code, site_ar) as (values
  ('makkah_sectors_towers',  'sector',          'sectors',           null),
  ('mashaaer_teams',         'sector',          'sectors',           null),
  ('arafat_camp_assignment', 'center',          'centers',           'عرفات'),
  ('mina_camp_assignment',   'center',          'centers',           'منى'),
  ('arafat_camp_assignment', 'camp',            'camps',             'عرفات'),
  ('mina_camp_assignment',   'camp',            'camps',             'منى'),
  ('madinah_admin_office',   'service_company', 'service_companies', null)
)
select rs.id,
       entry_name_of(n.label),
       -- Grouped by the EFFECTIVE season, not by the module's. An unscoped list
       -- carries null for every season, so grouping by the module's season
       -- would make one group per season and hand the statement two identical
       -- rows to insert. Only one season exists today, which is exactly why
       -- this would have waited until 1448 to break.
       case when rs.is_season_scoped then m.season_id end,
       coalesce(
         jsonb_strip_nulls(jsonb_build_object(
           'site', site.id::text,
           -- max() over the group rather than an arbitrary row: where a camp
           -- was entered twice, one of the two may carry the coordinates and
           -- the other not, and the one that knows should win. max skips nulls.
           'location', max(n.data ->> 'location'),
           'capacity', max(n.data ->> 'capacity')
         )),
         '{}'::jsonb
       ),
       min(n.sort_order)
  from module_nodes n
  join module_type_levels lv on lv.id = n.level_id
  join module_types mt on mt.id = lv.module_type_id
  join modules m on m.id = n.module_id
  join mapping map
    on map.type_code = mt.code and map.level_code = lv.code
  join reference_sets rs on rs.code = map.set_code
  left join reference_sets sites on sites.code = 'holy_sites'
  left join reference_items site
    on site.set_id = sites.id and site.name_ar = map.site_ar
 where n.reference_item_id is null
   and entry_name_of(n.label) is not null
 group by rs.id,
          entry_name_of(n.label),
          case when rs.is_season_scoped then m.season_id end,
          site.id
on conflict do nothing;

-- ------------------------------------------------------ the nodes, repointed
--
-- `label` is cleared as the entry is taken up: `module_node_is_named` wants one
-- of the two, and leaving both would leave two names for one node, free to
-- drift apart. The moved keys leave the node's data for the same reason.

with mapping (type_code, level_code, set_code, site_ar) as (values
  ('makkah_sectors_towers',  'sector',          'sectors',           null),
  ('mashaaer_teams',         'sector',          'sectors',           null),
  ('arafat_camp_assignment', 'center',          'centers',           'عرفات'),
  ('mina_camp_assignment',   'center',          'centers',           'منى'),
  ('arafat_camp_assignment', 'camp',            'camps',             'عرفات'),
  ('mina_camp_assignment',   'camp',            'camps',             'منى'),
  ('madinah_admin_office',   'service_company', 'service_companies', null)
)
update module_nodes n
   set reference_item_id = ri.id,
       label = null,
       data = n.data - 'location' - 'capacity'
  from module_type_levels lv,
       module_types mt,
       modules m,
       mapping map,
       reference_sets rs,
       reference_items ri
 where lv.id = n.level_id
   and mt.id = lv.module_type_id
   and m.id = n.module_id
   and map.type_code = mt.code
   and map.level_code = lv.code
   and rs.code = map.set_code
   and ri.set_id = rs.id
   and ri.name_ar = entry_name_of(n.label)
   and ri.season_id is not distinct from
       (case when rs.is_season_scoped then m.season_id end)
   -- The نوع has to match too, or a منى node would find عرفات's camp 11 first
   -- and point at the wrong ground.
   and ri.variant is not distinct from (
     select site.id::text
       from reference_items site
       join reference_sets sites
         on sites.id = site.set_id and sites.code = 'holy_sites'
      where site.name_ar = map.site_ar
   )
   and n.reference_item_id is null
   and entry_name_of(n.label) is not null;

-- ------------------------------------------------ the levels, pointed at them
--
-- Last, deliberately. Until this runs, a level with no set and nodes carrying
-- labels is a consistent picture; after it, a level with a set and nodes
-- carrying entries is another. Doing it first would have put the catalog
-- between the two, showing an editor a list where its nodes still held text.

with mapping (type_code, level_code, set_code, site_ar) as (values
  ('makkah_sectors_towers',  'sector',          'sectors',           null),
  ('mashaaer_teams',         'sector',          'sectors',           null),
  ('arafat_camp_assignment', 'center',          'centers',           'عرفات'),
  ('mina_camp_assignment',   'center',          'centers',           'منى'),
  ('arafat_camp_assignment', 'camp',            'camps',             'عرفات'),
  ('mina_camp_assignment',   'camp',            'camps',             'منى'),
  ('madinah_admin_office',   'service_company', 'service_companies', null)
)
update module_type_levels lv
   set reference_set_id = rs.id,
       reference_filter = case
         when map.site_ar is null then null
         else jsonb_build_object('site', (
           select site.id::text
             from reference_items site
             join reference_sets sites
               on sites.id = site.set_id and sites.code = 'holy_sites'
            where site.name_ar = map.site_ar
         ))
       end
  from module_types mt, mapping map, reference_sets rs
 where mt.id = lv.module_type_id
   and map.type_code = mt.code
   and map.level_code = lv.code
   and rs.code = map.set_code
   and lv.reference_set_id is null;

-- ------------------------------------------- the level fields that moved out
--
-- Removed rather than left dormant. A location field on the node beside a
-- location field on the entry is two ways to say where a camp is, and the
-- second one to be filled would win on some screens and lose on others.
-- Nothing references module_type_fields, so the row is all there is to drop.

delete from module_type_fields f
 using module_type_levels lv, module_types mt
 where f.level_id = lv.id
   and mt.id = lv.module_type_id
   and mt.code in ('arafat_camp_assignment', 'mina_camp_assignment')
   and lv.code = 'camp'
   and f.key in ('location', 'capacity');

drop function if exists entry_name_of(text);

-- ----------------------------------------------------- the list nobody filled
--
-- 0050's `arafat_camps`, superseded by `camps`. Dropped only if it is genuinely
-- empty and genuinely unreferenced — the guards are the point, since the whole
-- reason it is here is that the catalog turned out not to match what 0050 said.

delete from reference_sets rs
 where rs.code = 'arafat_camps'
   and not exists (select 1 from reference_items ri where ri.set_id = rs.id)
   and not exists (
     select 1 from module_type_levels lv
      where lv.reference_set_id = rs.id
         or lv.secondary_reference_set_id = rs.id
   )
   and not exists (
     select 1 from reference_set_fields f where f.reference_set_id = rs.id
   );

-- ------------------------------------------------- the list that was misnamed
--
-- The fourteen entries were never really cities: a member belongs to the office
-- of إدارة الحج والعمرة in his governorate, and the city was only how the
-- office was being named. The CODE stays `syrian_cities` — Dart reads it
-- (`ReferenceSetCodes.syrianCities`) and the 0030 policy that lets any
-- authenticated account read the list matches on it — so only what a person
-- sees changes.

update reference_sets
   set name_ar = 'مكاتب إدارة الحج والعمرة',
       name_en = 'Hajj and Umrah Administration offices'
 where code = 'syrian_cities';

-- And an office, unlike a city, is a building somebody drives to. Same `location`
-- kind the camps and the hotels use, so it is entered with the same map picker
-- and read by the same parser — `node_location` matches location fields BY KIND
-- (0092) precisely so a list added later needs no code written for it.
insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, is_required, sort_order)
select rs.id, 'location', 'موقع المكتب', 'Office location',
       'location'::module_field_kind, false, 1
from reference_sets rs
where rs.code = 'syrian_cities'
on conflict (set_id, key) do nothing;

-- ------------------------------------------------------------------ the report

select rs.code as list,
       count(distinct ri.id) as entries,
       count(n.id) as nodes_pointed,
       string_agg(distinct ri.name_ar, ' · ' order by ri.name_ar) as names
  from reference_sets rs
  join reference_items ri on ri.set_id = rs.id
  left join module_nodes n on n.reference_item_id = ri.id
 where rs.code in ('sectors', 'centers', 'camps', 'service_companies',
                   'holy_sites')
 group by rs.code
 order by rs.code;
