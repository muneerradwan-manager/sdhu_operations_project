-- المجموعات, and one more team of the Madinah office.

-- --------------------------------------------------------------- المجموعات
--
-- A تكتل is a body of pilgrims, and it is made up of مجموعات: each with a name,
-- a number of pilgrims, a مشرف, and a نائب when it has one. The cluster is
-- entered first and the group names the cluster it falls under, which is the
-- order the work actually happens in.
--
-- A reference SET rather than a table of its own. Everything a group needs is
-- already what master data does — season scoping (a group is contracted for one
-- year), the shared editor, the in-use guard that refuses to delete an entry
-- something points at, and the copy-forward of 0043. A table would have bought
-- nothing and cost a screen.
--
-- Which gives the تكتل two numbers that mean different things:
--
--   العدد الكلي        what it can take — a ceiling, written down here
--   the groups' sum   what has actually been put in it
--
-- The second is deliberately NOT stored. It is the sum of the groups pointing
-- at the cluster, computed where it is shown; a column would be a second place
-- for it to be wrong the moment a group is edited. The detail screen shows both
-- together and says so when the ceiling has been passed.

insert into reference_sets (code, name_ar, name_en, is_season_scoped)
values ('groups', 'المجموعات', 'Groups', true)
on conflict (code) do nothing;

insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, reference_set_id, is_required, sort_order)
select rs.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
       target.id, v.is_required, v.sort_order
from (values
  -- The cluster is required and comes first: a group that belongs to no تكتل
  -- is the one thing this list must not be able to hold.
  ('cluster',     'التكتل',      'Cluster',        'reference', 'clusters', true,  1),
  ('total_count', 'العدد الكلي', 'Total pilgrims', 'number',    null,       true,  2),
  ('supervisor',  'اسم المشرف',  'Supervisor',     'text',      null,       true,  3),
  ('deputy',      'نائب المشرف', 'Deputy',         'text',      null,       false, 4)
) as v(key, label_ar, label_en, kind, target_code, is_required, sort_order)
join reference_sets rs on rs.code = 'groups'
left join reference_sets target on target.code = v.target_code
on conflict (set_id, key) do nothing;

-- ------------------------------- فريق متابعة ترحيل وسفر الحجاج، ومحاسب المكتب
--
-- 3190 forms one more team of the office 3179 already formed, and names its
-- محاسب in a clause of its own. It is signed by that office's own director and
-- staffed from the same people, so it joins the Madinah file rather than
-- opening a second file for the same office in the same season.
--
-- These are the first roles of this type to carry duties: 0057 seeded none
-- because 3179 wrote none, and 3190 writes four. So the two team roles take the
-- menu the rest of the catalog uses and the older roles are left as they were.
-- The محاسب gets no menu — the decision gives him no list.

insert into module_type_roles
  (module_type_id, code, name_ar, name_en, description_ar, description_en,
   allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.description_ar, v.description_en,
       v.allows_multiple, false, v.code <> 'accountant', v.sort_order
from (values
  ('departures_supervisor', 'مشرف فريق متابعة ترحيل وسفر الحجاج',
   'Departures follow-up supervisor',
   'يقود متابعة ترحيل الحجاج من المدينة المنورة وسفرهم، ويوزّع المهام على الفريق ويرفع تقاريره إلى إدارة المكتب.',
   'Leads the follow-up of pilgrim departures from Madinah, hands the duties out and files the team''s reports.',
   false, 11),
  ('departures_member', 'عضو فريق متابعة ترحيل وسفر الحجاج',
   'Departures follow-up member',
   'يتولى ما يُسند إليه من متابعة الترحيل ميدانياً، في الفنادق ومقار السكن وبالتنسيق مع فريق المطار.',
   'Carries whatever departure duties are handed to him, on the ground and with the airport team.',
   true, 12),
  ('accountant', 'محاسب المكتب الإداري', 'Office accountant',
   'يتولى محاسبة المكتب الإداري في المدينة المنورة.',
   'Keeps the accounts of the Madinah administrative office.',
   false, 13)
) as v(code, name_ar, name_en, description_ar, description_en,
       allows_multiple, sort_order)
cross join module_types mt
where mt.code = 'madinah_admin_office'
on conflict (module_type_id, code) do nothing;

insert into module_type_task_groups
  (module_type_id, code, name_ar, name_en, sort_order)
select mt.id, 'departures', 'متابعة ترحيل وسفر الحجاج', 'Departures follow-up', 1
from module_types mt
where mt.code = 'madinah_admin_office'
on conflict (module_type_id, code) do nothing;

insert into module_type_tasks
  (module_type_id, group_id, title_ar, title_en, sort_order)
select mt.id, g.id, v.title_ar, v.title_en, v.sort_order
from (values
  ('متابعة عملية ترحيل الحجاج من المدينة، والتنسيق المستمر مع فريق مكتب الخدمة الميدانية',
   'Follow the departure of the pilgrims from Madinah, in constant coordination with the field service office team', 1),
  ('التواجد المباشر والإشراف الميداني على عمليات ترحيل الحجاج من الفنادق ومقار سكنهم في المدينة المنورة',
   'Be present for and supervise the departures from the hotels and residences in Madinah', 2),
  ('رفع إشعار الترحيل الفوري إلى فريق المطار فور مغادرة الحجاج للفندق، مع استمرار التواصل والتنسيق معهم لضمان سلاسة الاستقبال',
   'Notify the airport team the moment a group leaves its hotel, and stay in contact so the reception runs smoothly', 3),
  ('إعداد وإرسال تقارير يومية مفصلة ترفع للإدارة مباشرة توضّح مسار عمليات الترحيل وأي تحديات يتم رصدها',
   'File a detailed daily report to the administration on how the departures are going and anything that got in the way', 4)
) as v(title_ar, title_en, sort_order)
join module_types mt on mt.code = 'madinah_admin_office'
join module_type_task_groups g
  on g.module_type_id = mt.id and g.code = 'departures'
where not exists (
  select 1 from module_type_tasks t
   where t.module_type_id = mt.id and t.title_ar = v.title_ar
);

-- The type's description enumerates its teams, so it has to learn the new ones.
update module_types set
  description_ar =
    'تشكيل الفرق واللجان العاملة في بعثة الحج السورية ضمن المكتب الإداري في '
    'المدينة المنورة: تسكين الحجاج، وشركات الخدمة بأدلائها، والمطار، والطيران '
    'المركزي، وشحن الحقائب ومتابعتها، ومتابعة ترحيل وسفر الحجاج، ومنسق عمل '
    'المكتب، ومنسق سفر البعثات والإداريين والفرادى، ومحاسب المكتب.',
  description_en =
    'The teams and committees of the Syrian Hajj Mission inside the Madinah '
    'administrative office: housing the pilgrims, the service companies and '
    'their guides, the airport, central aviation, baggage forwarding, the '
    'follow-up of pilgrim departures, the office coordinator, the coordinator '
    'for the travel of missions, administrators and individuals, and the '
    'office accountant.'
where code = 'madinah_admin_office';
