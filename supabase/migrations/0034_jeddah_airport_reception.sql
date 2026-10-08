-- The fifth operational file: استقبال الحجاج في مطار جدة.
--
-- A roster with no tree, two اختصاصات, and one list of duties belonging to the
-- file. INSERTs only, like 0033 before it.
--
-- This one is where the season starts. It is also the file that talks to every
-- other one — الطوافة والنقل for the buses and the luggage, the tower
-- supervisors for who is going where — which is why its duties name those teams
-- by name and why nobody in it works alone.

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'jeddah_airport_reception',
  'استقبال الحجاج في مطار جدة',
  'Pilgrim Reception at Jeddah Airport',
  'ملف تشغيلي لاستقبال الحجاج عند وصولهم: متابعة جداول الرحلات، وفرز الحجاج '
  'حسب الفنادق والتكتلات وتوزيعهم على الحافلات، ومتابعة الحقائب، والتنسيق مع '
  'فرق الطوافة والنقل والجهات المختصة بالمطار.',
  'Receiving the pilgrims as they arrive: following the flight schedules, '
  'sorting pilgrims by hotel and cluster and putting them on their buses, '
  'following the luggage, and coordinating with the Tawafa and transport teams '
  'and the airport authorities.',
  'يستمر العمل حتى ترحيل آخر حاج',
  'Runs until the last pilgrim has departed',
  5
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'jeddah_airport_reception'
on conflict (module_type_id, key) do nothing;

-- One مشرف and as many أعضاء as the arrivals need — an airport file runs in
-- shifts, so its membership is the largest of any of them.
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
where mt.code = 'jeddah_airport_reception'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the duties

insert into module_type_tasks
  (module_type_id, title_ar, title_en, sort_order)
select mt.id, v.title_ar, v.title_en, v.sort_order
from (values
  (
    'إعداد وتنفيذ الخطة التشغيلية لاستقبال الحجاج بالمطار، وتوزيع المهام والورديات ومتابعة جاهزية الفريق والتصاريح والاحتياجات التشغيلية',
    'Drawing up and running the operational plan for receiving pilgrims at the airport: assigning duties and shifts, and keeping the team, its permits and its operational needs ready',
    1
  ),
  (
    'متابعة جداول الرحلات ومواعيد الوصول الفعلية، وإرسال الإشعارات الفورية لغرفة العمليات التشغيلية والجهات المعنية بأي مستجدات أو تأخير أو ملاحظات تشغيلية',
    'Following the flight schedules and the actual arrival times, and notifying the operations room and the bodies concerned at once of any development, delay or operational observation',
    2
  ),
  (
    'استقبال الحجاج والبعثات الرسمية والشخصيات الهامة وإرشادهم وتنظيم انتقالهم إلى الحافلات ومقار السكن وفق الخطط المعتمدة',
    'Receiving the pilgrims, the official delegations and the VIPs, guiding them and organising their move to the buses and their accommodation, against the approved plans',
    3
  ),
  (
    'تنظيم عمليات فرز الحجاج حسب الفنادق والتكتلات، والإشراف على توزيعهم على الحافلات ومتابعة نقل الحقائب وتسليمها لشاحنات النقل',
    'Sorting the pilgrims by hotel and cluster, overseeing how they are distributed across the buses, and following the luggage through to the freight trucks',
    4
  ),
  (
    'التنسيق المستمر مع فرق الطوافة والنقل والفنادق ومشرفي الأبراج والجهات المختصة بالمطار لضمان انسيابية الحركة وسلامة الإجراءات',
    'Coordinating continuously with the Tawafa and transport teams, the hotels, the tower supervisors and the airport authorities, so movement flows and the procedures hold',
    5
  ),
  (
    'تقديم الدعم المباشر للحجاج ومعالجة الاستفسارات والحالات الخاصة أو القانونية ومتابعة مشاكل الدخول والمبعدين بالتنسيق مع الجهات المختصة',
    'Supporting the pilgrims directly: answering questions, handling special or legal cases, and following entry problems and deportations with the authorities concerned',
    6
  ),
  (
    'توثيق الحالات التشغيلية والاستثنائية ورفع التقارير والتقييمات الدورية والختامية عن أداء المجموعات والتكتلات والفريق والإجراءات التشغيلية',
    'Recording operational and exceptional cases, and filing the regular and closing reports and appraisals on the groups, the clusters, the team and the procedures',
    7
  )
) as v(title_ar, title_en, sort_order)
join module_types mt on mt.code = 'jeddah_airport_reception'
where not exists (
  select 1 from module_type_tasks t
  where t.module_type_id = mt.id and t.title_ar = v.title_ar
);
