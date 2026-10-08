-- The sixth operational file: إدارة شؤون مكاتب البعثة.
--
-- A roster with no tree, two اختصاصات, and one list of duties belonging to the
-- file — so far, 0033 and 0034 again. What it also has is the thing 0028 built
-- for الإعاشة المركزية and 0033 and 0034 did not need: STAGES. The
-- Administration set these thirteen duties out under five headings — اللوجستية,
-- إدارة البيانات, السكن والإقامة, الحجوزات والسفر, النقل والتنقل — and they are
-- not a sequence in time so much as five different jobs that happen to be held
-- by the same office.
--
-- Which is the case the grouping was written for. Thirteen duties read in one
-- run tell you far less than five short lists, and the member handed two of
-- them can see at a glance which side of the office he is on.
--
-- Still INSERTs only. Six files in, no file has yet needed a schema change it
-- did not bring with it.

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'mission_offices_affairs',
  'إدارة شؤون مكاتب البعثة',
  'Mission Offices Affairs',
  'ملف تشغيلي لشؤون أعضاء البعثات أنفسهم: احتياجاتهم اللوجستية، وبياناتهم '
  'الشخصية وجوازاتهم وبطاقات نسك، وسكنهم في مكة والمدينة، وحجوزات سفرهم '
  'وتأشيراتهم، وتنقلهم بين المطار والمشاعر والمدينتين.',
  'The affairs of the mission members themselves: what they need on the ground, '
  'their personal records, passports and Nusuk cards, their accommodation in '
  'Makkah and Madinah, their travel bookings and visas, and their movement '
  'between the airport, the holy sites and the two cities.',
  'يستمر العمل حتى عودة آخر شخص من أعضاء البعثات',
  'Runs until the last mission member has returned',
  6
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'mission_offices_affairs'
on conflict (module_type_id, key) do nothing;

insert into module_type_roles
  (module_type_id, code, name_ar, name_en,
   allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en,
       v.allows_multiple, false, true, v.sort_order
from (values
  ('supervisor', 'مشرف', 'Supervisor', false, 1),
  ('member',     'عضو',  'Member',     true,  2)
) as v(code, name_ar, name_en, allows_multiple, sort_order)
cross join module_types mt
where mt.code = 'mission_offices_affairs'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the stages
--
-- Five sides of one office, in the order the Administration set them out.

insert into module_type_task_groups
  (module_type_id, code, name_ar, name_en, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.sort_order
from (values
  ('logistics',     'اللوجستية',        'Logistics',           1),
  ('data',          'إدارة البيانات',   'Records',             2),
  ('accommodation', 'السكن والإقامة',   'Accommodation',       3),
  ('travel',        'الحجوزات والسفر',  'Bookings & travel',   4),
  ('transport',     'النقل والتنقل',    'Transport & movement', 5)
) as v(code, name_ar, name_en, sort_order)
cross join module_types mt
where mt.code = 'mission_offices_affairs'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the duties

insert into module_type_tasks
  (module_type_id, group_id, title_ar, title_en, sort_order)
select mt.id, g.id, v.title_ar, v.title_en, v.sort_order
from (values
  (
    'logistics',
    'تحديد وتجهيز احتياجات أعضاء البعثات وتسليمها لمشرفي القطاعات',
    'Working out what the mission members need, preparing it, and handing it to the sector supervisors',
    1
  ),
  (
    'data',
    'جمع واستكمال البيانات الشخصية لأعضاء البعثات',
    'Collecting the personal records of the mission members and filling in what is missing',
    2
  ),
  (
    'data',
    'تحديد حالة النسك لكل عضو (حاج لأول مرة)',
    'Establishing each member Nusuk status (whether this is a first Hajj)',
    3
  ),
  (
    'data',
    'التنسيق مع فريقي الطوافة والنقل لاستلام وتسليم جوازات السفر',
    'Coordinating with the Tawafa and transport teams over taking in and handing back passports',
    4
  ),
  (
    'data',
    'التنسيق مع شركة الخدمة لاستلام بطاقات نسك',
    'Coordinating with the service company to collect the Nusuk cards',
    5
  ),
  (
    'accommodation',
    'توزيع السكن لأعضاء البعثات في مكة المكرمة والمدينة المنورة',
    'Allocating accommodation to the mission members in Makkah and Madinah',
    6
  ),
  (
    'accommodation',
    'تخصيص سكن مركزي للفرق الدائمة بالمدينة المنورة',
    'Setting aside central accommodation in Madinah for the standing teams',
    7
  ),
  (
    'accommodation',
    'التنسيق مع شركة الخدمة في مكة والمدينة، ومع فريق الطيران',
    'Coordinating with the service company in Makkah and Madinah, and with the aviation team',
    8
  ),
  (
    'travel',
    'تنظيم مواعيد السفر والعودة بالتنسيق مع رئيس المكتب الإداري',
    'Arranging the outbound and return dates with the head of the administrative office',
    9
  ),
  (
    'travel',
    'متابعة التأشيرات بالتنسيق مع مشرف المسار الإلكتروني',
    'Following the visas with the supervisor of the electronic track',
    10
  ),
  (
    'travel',
    'إدارة وأرشفة بيانات السفر والعودة',
    'Keeping and archiving the travel and return records',
    11
  ),
  (
    'transport',
    'تنظيم تنقل أعضاء المكاتب الأربعة بين المطار ومقار السكن في مكة والمدينة',
    'Arranging movement for the members of the four offices between the airport and their accommodation in Makkah and Madinah',
    12
  ),
  (
    'transport',
    'متابعة التنقل بين مكة المكرمة والمدينة المنورة (قطار، نقل خاص، حافلات)',
    'Following movement between Makkah and Madinah, by train, private transport or coach',
    13
  )
) as v(group_code, title_ar, title_en, sort_order)
join module_types mt on mt.code = 'mission_offices_affairs'
join module_type_task_groups g
  on g.module_type_id = mt.id and g.code = v.group_code
where not exists (
  select 1 from module_type_tasks t
  where t.module_type_id = mt.id and t.title_ar = v.title_ar
);
