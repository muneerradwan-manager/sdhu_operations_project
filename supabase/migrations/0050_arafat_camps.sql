-- The twelfth operational file: توزيع أعضاء المكاتب على مخيمات عرفات.
--
-- A tree again, and the first since 0024 to use both of its rungs: a مركز, and
-- the مخيمات inside it. Each مركز is a number with a مشرف over it; each مخيم is
-- a number with the members who serve in it. One man may serve in two camps of
-- the same center, which is why the members sit on the camp rather than on the
-- center.
--
-- The distribution is made وفق الطاقة الاستيعابية لكل مخيم — so the capacity has
-- to be somewhere a person can READ it while distributing, or the rule is only
-- a sentence in the file's name. It cannot live on the node: a node carries a
-- name and nothing else. So a camp is not typed in this file at all — it is an
-- entry of a list, exactly as a tower is a hotel, and the capacity is a field on
-- that entry.
--
-- The list is season-scoped, like the hotels and the clusters (0040): the camps
-- of عرفات are contracted afresh each year and their capacities change with the
-- contract. Which also means the list can be carried into the next season with
-- the import 0043 already provides.
--
-- One consequence worth stating, because it is a rule rather than an accident:
-- `uq_module_nodes_entry` allows an entry once per file, so a camp stands in
-- exactly one مركز. That is the point of the file — a camp assigned twice is
-- the mistake it exists to prevent.

-- ------------------------------------------------------------ the camps list

insert into reference_sets (code, name_ar, name_en)
values ('arafat_camps', 'مخيمات عرفات', 'Arafat camps')
on conflict (code) do nothing;

-- Contracted per season, so it belongs to a season — and can be copied forward
-- into the next one rather than retyped.
update reference_sets
   set is_season_scoped = true
 where code = 'arafat_camps';

-- The one fact the distribution turns on. Required: a camp whose capacity
-- nobody wrote down cannot be distributed against, and letting it through empty
-- would put the decision back where it was.
insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, is_required, sort_order)
select rs.id, 'capacity', 'الطاقة الاستيعابية', 'Capacity',
       'number'::module_field_kind, true, 1
from reference_sets rs
where rs.code = 'arafat_camps'
on conflict (set_id, key) do nothing;

-- No camps are seeded. They come from the season's contract and are entered by
-- whoever holds that contract, the same way the hotels are.

-- ---------------------------------------------------------------- the type

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   start_condition_ar, start_condition_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'arafat_camp_assignment',
  'توزيع أعضاء مكاتب البعثة على مخيمات عرفات',
  'Mission office members across the Arafat camps',
  'ملف تشغيلي لتوزيع أعضاء مكاتب بعثة الحج السورية على مخيمات عرفات وفق الطاقة '
  'الاستيعابية لكل مخيم: يُقسم إلى مراكز، لكل مركز مشرفه وعدة مخيمات، ولكل مخيم '
  'أعضاؤه.',
  'Distributing the members of the Syrian Hajj Mission offices across the '
  'Arafat camps according to each camp''s capacity: divided into centers, each '
  'with its supervisor and several camps, and each camp with its members.',
  'يبدأ العمل باعتماد توزيع المخيمات على المراكز قبل يوم عرفة',
  'Begins when the camps have been allotted to the centers, before the day of Arafat',
  'ينتهي العمل بمغادرة آخر حاج من عرفات إلى مزدلفة',
  'Ends when the last pilgrim leaves Arafat for Muzdalifah',
  12
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'arafat_camp_assignment'
on conflict (module_type_id, key) do nothing;

-- ---------------------------------------------------------------- the tree
--
-- The مركز is numbered by hand — it is a division of this file and of no other,
-- so it has no list. The مخيم is taken from the list above, which is what
-- carries its capacity onto the screen of the person distributing.

insert into module_type_levels
  (module_type_id, code, name_ar, name_en, depth, reference_set_id)
select mt.id, v.code, v.name_ar, v.name_en, v.depth, rs.id
from (values
  ('center', 'المركز', 'Center', 1, null),
  ('camp',   'المخيم', 'Camp',   2, 'arafat_camps')
) as v(code, name_ar, name_en, depth, set_code)
cross join module_types mt
left join reference_sets rs on rs.code = v.set_code
where mt.code = 'arafat_camp_assignment'
on conflict (module_type_id, code) do nothing;

-- ---------------------------------------------------------------- the roles
--
-- Two, and the file says no more: a مشرف over each مركز, and the members of
-- each مخيم. No duties are seeded — the Administration has not written them,
-- and each role carries its job description instead (see 0048 for why the flag
-- is false rather than true).

insert into module_type_roles
  (module_type_id, code, name_ar, name_en, description_ar, description_en,
   level_id, allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.description_ar, v.description_en,
       lv.id, v.allows_multiple, v.is_required, false, v.sort_order
from (values
  (
    'center',
    'center_supervisor',
    'مشرف المركز',
    'Center supervisor',
    'الإشراف على مخيمات المركز في عرفات ومتابعة أعضائها، والتأكد من أن التوزيع '
    'قائم على الطاقة الاستيعابية لكل مخيم.',
    'Oversees the camps of his center at Arafat and the members serving in '
    'them, and sees that the distribution holds to each camp''s capacity.',
    false, true, 1
  ),
  (
    'camp',
    'camp_member',
    'عضو المخيم',
    'Camp member',
    'العمل مع حجاج المخيم في عرفات يوم الوقوف حتى الدفع إلى مزدلفة.',
    'Serves the camp''s pilgrims at Arafat on the day of standing, through to '
    'the departure for Muzdalifah.',
    true, false, 1
  )
) as v(level_code, code, name_ar, name_en, description_ar, description_en,
       allows_multiple, is_required, sort_order)
cross join module_types mt
join module_type_levels lv
  on lv.module_type_id = mt.id and lv.code = v.level_code
where mt.code = 'arafat_camp_assignment'
on conflict (module_type_id, code) do nothing;
