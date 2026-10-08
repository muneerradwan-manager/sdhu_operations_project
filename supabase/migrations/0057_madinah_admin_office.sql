-- The fourteenth operational file: فرق ولجان المكتب الإداري في المدينة المنورة.
--
-- Six teams and two coordinators, all held once for the file — and one team
-- that is not like the others.
--
-- فريق شركة الخدمة is not a list of people. It is a list of COMPANIES, each
-- with its own أدلاء, and the الدليل belongs to his company rather than to the
-- team at large: asking "who are the guides" without asking "of which company"
-- is not a question this office ever has. So the companies are a level, each
-- one a node, and the أدلاء are held on it. Every other team here is a role on
-- the file, and reads as one.
--
-- Which makes this the second file with a tree of one rung and a roster beside
-- it (تشكيل فرق المشاعر was the first) — three steps: the file, its شركات, and
-- everyone else.
--
-- The company is typed rather than chosen. It could have been a list — the same
-- companies return each season — but a list is a thing somebody must maintain
-- before the file can be built, and this file is built by writing down what was
-- agreed. If the names start being retyped and misspelt, a list is the answer,
-- and moving to one is what 0050 did in reverse.
--
-- No مشرف over the أدلاء: stated, and meant. The other five teams have one
-- where the Administration named one.
--
-- No duties are seeded — the Administration has not written them for this file.
-- Each role carries its job description instead (0048 says why the flag is
-- false rather than true).

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   start_condition_ar, start_condition_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'madinah_admin_office',
  'فرق ولجان المكتب الإداري في المدينة المنورة',
  'Teams & committees of the Madinah administrative office',
  'تشكيل الفرق واللجان العاملة في بعثة الحج السورية ضمن المكتب الإداري في '
  'المدينة المنورة: تسكين الحجاج، وشركات الخدمة بأدلائها، والمطار، والطيران '
  'المركزي، وشحن الحقائب ومتابعتها، ومنسق عمل المكتب، ومنسق سفر البعثات '
  'والإداريين والفرادى.',
  'The teams and committees of the Syrian Hajj Mission inside the Madinah '
  'administrative office: housing the pilgrims, the service companies and '
  'their guides, the airport, central aviation, baggage forwarding and its '
  'follow-up, the office coordinator, and the coordinator for the travel of '
  'missions, administrators and individuals.',
  'يبدأ العمل بتشكيل فرق المكتب قبل وصول أول فوج إلى المدينة المنورة',
  'Begins when the office''s teams are formed, before the first group reaches Madinah',
  'ينتهي العمل بمغادرة آخر فوج من المدينة المنورة',
  'Ends when the last group leaves Madinah',
  14
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'madinah_admin_office'
  and not exists (
    select 1 from module_type_fields f
     where f.module_type_id = mt.id and f.level_id is null
       and f.key = 'official_pdf'
  );

-- ------------------------------------------------------------- the companies

insert into module_type_levels
  (module_type_id, code, name_ar, name_en, depth, reference_set_id)
select mt.id, 'service_company', 'شركة الخدمة (الأدلاء)', 'Service company (guides)',
       1, null
from module_types mt
where mt.code = 'madinah_admin_office'
on conflict (module_type_id, code) do nothing;

insert into module_type_roles
  (module_type_id, code, name_ar, name_en, description_ar, description_en,
   level_id, allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, 'guide', 'دليل', 'Guide',
       'العمل مع حجاج المكتب من خلال شركة الخدمة التي ينتمي إليها، ومتابعة ما '
       'يخصّهم لديها.',
       'Works with the office''s pilgrims through the service company he belongs '
       'to, and follows their affairs with it.',
       lv.id, true, false, false, 1
from module_types mt
join module_type_levels lv
  on lv.module_type_id = mt.id and lv.code = 'service_company'
where mt.code = 'madinah_admin_office'
on conflict (module_type_id, code) do nothing;

-- ---------------------------------------------------------- the office's teams
--
-- All held once for the whole file — `level_id` null. Ordered as the
-- Administration listed them, teams first and the two coordinators last.

insert into module_type_roles
  (module_type_id, code, name_ar, name_en, description_ar, description_en,
   level_id, allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.description_ar, v.description_en,
       null, v.allows_multiple, false, false, v.sort_order
from (values
  (
    'housing_supervisor',
    'مشرف فريق تسكين الحجاج',
    'Housing team supervisor',
    'الإشراف على تسكين حجاج البعثة في المدينة المنورة ومتابعة أعضاء الفريق.',
    'Oversees the housing of the mission''s pilgrims in Madinah and follows his '
    'team.',
    false, 1
  ),
  (
    'housing_member',
    'عضو فريق تسكين الحجاج',
    'Housing team member',
    'تسكين الحجاج في مقارّهم بالمدينة المنورة ومعالجة ما يطرأ عليه.',
    'Houses the pilgrims in their quarters in Madinah and handles whatever '
    'arises.',
    true, 2
  ),
  (
    'airport_supervisor',
    'مشرف فريق المطار',
    'Airport team supervisor',
    'الإشراف على استقبال الحجاج وتوديعهم في مطار المدينة المنورة ومتابعة أعضاء '
    'الفريق.',
    'Oversees receiving and seeing off the pilgrims at Madinah airport, and '
    'follows his team.',
    false, 3
  ),
  (
    'airport_member',
    'عضو فريق المطار',
    'Airport team member',
    'استقبال الحجاج وتوديعهم في المطار ومتابعة إجراءاتهم.',
    'Receives and sees off the pilgrims at the airport and follows their '
    'formalities.',
    true, 4
  ),
  (
    'aviation_supervisor',
    'مشرف فريق الطيران المركزي',
    'Central aviation team supervisor',
    'الإشراف على شؤون الطيران المركزي الخاصة بالمكتب ومتابعة أعضاء الفريق.',
    'Oversees the office''s central aviation affairs and follows his team.',
    false, 5
  ),
  (
    'aviation_member',
    'عضو فريق الطيران المركزي',
    'Central aviation team member',
    'متابعة مواعيد الرحلات وأفواجها مع الطيران المركزي.',
    'Follows the flight times and their groups with central aviation.',
    true, 6
  ),
  (
    'baggage_member',
    'عضو فريق شحن ومتابعة الحقائب',
    'Baggage forwarding team member',
    'شحن حقائب الحجاج ومتابعتها حتى تسليمها، ومعالجة المفقود منها.',
    'Forwards the pilgrims'' baggage and follows it through to delivery, and '
    'deals with whatever goes missing.',
    true, 7
  ),
  (
    'office_coordinator',
    'منسق عمل المكتب الإداري',
    'Administrative office coordinator',
    'تنسيق عمل فرق المكتب الإداري في المدينة المنورة وربطها بإدارة البعثة.',
    'Coordinates the work of the Madinah office''s teams and ties them to the '
    'mission''s administration.',
    false, 8
  ),
  (
    'travel_coordinator',
    'منسق ومتابع لسفر البعثات والإداريين والفرادى',
    'Travel coordinator for missions, administrators and individuals',
    'تنسيق ومتابعة سفر البعثات والإداريين والفرادى من المدينة المنورة وإليها.',
    'Coordinates and follows the travel of the missions, the administrators and '
    'the individuals to and from Madinah.',
    false, 9
  )
) as v(code, name_ar, name_en, description_ar, description_en,
       allows_multiple, sort_order)
cross join module_types mt
where mt.code = 'madinah_admin_office'
on conflict (module_type_id, code) do nothing;
