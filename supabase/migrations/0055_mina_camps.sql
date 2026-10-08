-- The thirteenth operational file: توزيع أعضاء المكاتب على مخيمات منى.
--
-- The same shape as عرفات (0050, 0052): مراكز, each with its مشرف and its
-- مخيمات, each مخيم a number written down carrying الطاقة الاستيعابية it is
-- distributed against and where it stands. Written out rather than copied from
-- the other type — a seed that reads itself is worth more than one that is
-- clever, and منى will drift from عرفات the first time the Administration wants
-- it to.
--
-- What is new here is فريق الكوسترات, which belongs to no مركز: the buses move
-- between all of them. So it sits on the file, and this becomes the first type
-- with BOTH a tree of two rungs AND a roster beside it. Nothing had to be added
-- for that — the editor stopped counting its steps in 0048 and asks the type
-- what it has, so this file simply answers yes three times: مراكز, مخيمات, and
-- a فريق.
--
-- The مركز carries the same level CODE as عرفات's, deliberately. It is the same
-- division of the same offices, so a file can take its مراكز from the other
-- rather than have them typed twice (0049, narrowed by 0053 to levels that mean
-- the same thing). If they ever stop being the same division, the codes are
-- what to separate.

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   start_condition_ar, start_condition_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'mina_camp_assignment',
  'توزيع أعضاء مكاتب البعثة على مخيمات منى',
  'Mission office members across the Mina camps',
  'ملف تشغيلي لتوزيع أعضاء مكاتب بعثة الحج السورية على مخيمات مشعر منى وفق '
  'الطاقة الاستيعابية لكل مخيم: يُقسم إلى مراكز، لكل مركز مشرفه وعدة مخيمات، '
  'ولكل مخيم أعضاؤه، ومعه فريق الكوسترات على مستوى الملف.',
  'Distributing the members of the Syrian Hajj Mission offices across the Mina '
  'camps according to each camp''s capacity: divided into centers, each with '
  'its supervisor and several camps, each camp with its members, and the '
  'coasters team serving the file as a whole.',
  'يبدأ العمل باعتماد توزيع المخيمات على المراكز قبل التوجه إلى منى',
  'Begins when the camps have been allotted to the centers, before the move to Mina',
  'ينتهي العمل بمغادرة آخر حاج من منى بعد أيام التشريق',
  'Ends when the last pilgrim leaves Mina after the days of Tashreeq',
  13
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'mina_camp_assignment'
  and not exists (
    select 1 from module_type_fields f
     where f.module_type_id = mt.id and f.level_id is null
       and f.key = 'official_pdf'
  );

-- ---------------------------------------------------------------- the tree

insert into module_type_levels
  (module_type_id, code, name_ar, name_en, depth, reference_set_id)
select mt.id, v.code, v.name_ar, v.name_en, v.depth, null
from (values
  ('center', 'المركز', 'Center', 1),
  ('camp',   'المخيم', 'Camp',   2)
) as v(code, name_ar, name_en, depth)
cross join module_types mt
where mt.code = 'mina_camp_assignment'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------- what a camp carries

insert into module_type_fields
  (module_type_id, level_id, key, label_ar, label_en, kind, is_required,
   sort_order)
select mt.id, lv.id, v.key, v.label_ar, v.label_en,
       v.kind::module_field_kind, v.is_required, v.sort_order
from (values
  ('capacity', 'الطاقة الاستيعابية', 'Capacity', 'number',   true,  1),
  ('location', 'موقع المخيم',        'Location', 'location', false, 2)
) as v(key, label_ar, label_en, kind, is_required, sort_order)
cross join module_types mt
join module_type_levels lv
  on lv.module_type_id = mt.id and lv.code = 'camp'
where mt.code = 'mina_camp_assignment'
  and not exists (
    select 1 from module_type_fields f
     where f.module_type_id = mt.id and f.level_id = lv.id and f.key = v.key
  );

-- ---------------------------------------------------------------- the roles
--
-- Two on the tree, and two on the file. No duties are seeded: the Administration
-- has not written them, and each role carries its job description instead (0048
-- says why the flag is false rather than true).

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
    'الإشراف على مخيمات المركز في منى ومتابعة أعضائها، والتأكد من أن التوزيع '
    'قائم على الطاقة الاستيعابية لكل مخيم.',
    'Oversees the camps of his center at Mina and the members serving in them, '
    'and sees that the distribution holds to each camp''s capacity.',
    false, true, 1
  ),
  (
    'camp',
    'camp_member',
    'عضو المخيم',
    'Camp member',
    'العمل مع حجاج المخيم في منى أيام التشريق حتى النفير.',
    'Serves the camp''s pilgrims in Mina through the days of Tashreeq, until '
    'the departure.',
    true, false, 2
  )
) as v(level_code, code, name_ar, name_en, description_ar, description_en,
       allows_multiple, is_required, sort_order)
cross join module_types mt
join module_type_levels lv
  on lv.module_type_id = mt.id and lv.code = v.level_code
where mt.code = 'mina_camp_assignment'
on conflict (module_type_id, code) do nothing;

-- فريق الكوسترات belongs to no مركز — the buses move between all of them — so
-- it is held once for the whole file. `level_id` null is what says that.

insert into module_type_roles
  (module_type_id, code, name_ar, name_en, description_ar, description_en,
   level_id, allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.description_ar, v.description_en,
       null, v.allows_multiple, false, false, v.sort_order
from (values
  (
    'coasters_supervisor',
    'مشرف فريق الكوسترات',
    'Coasters team supervisor',
    'الإشراف على فريق الكوسترات في منى: توزيع الحافلات على المراكز ومتابعة '
    'حركتها بين المخيمات والمشاعر، ومعالجة ما يطرأ عليها.',
    'Oversees the coasters team at Mina: allotting the buses to the centers, '
    'following their movement between the camps and the holy sites, and '
    'handling whatever befalls them.',
    false, 3
  ),
  (
    'coasters_member',
    'عضو فريق الكوسترات',
    'Coasters team member',
    'متابعة حافلات الكوسترات ميدانياً في منى ونقل الحجاج بين مواقعها.',
    'Follows the coaster buses on the ground at Mina and moves the pilgrims '
    'between their places.',
    true, 4
  )
) as v(code, name_ar, name_en, description_ar, description_en,
       allows_multiple, sort_order)
cross join module_types mt
where mt.code = 'mina_camp_assignment'
on conflict (module_type_id, code) do nothing;
