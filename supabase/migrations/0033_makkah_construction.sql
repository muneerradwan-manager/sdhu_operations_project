-- The fourth operational file: الإنشاءات في مكة المكرمة.
--
-- Nothing new in it, and that is the point. It is the same shape as الإعاشة
-- المركزية — a roster with no tree, three اختصاصات, and one list of duties
-- belonging to the FILE rather than to any one of them — so it is INSERTs and
-- nothing else. No table, no column, no screen. 0017 said adding a kind of file
-- should be data entry; four files in, it is.
--
-- The one difference from catering is what it does NOT have: the Administration
-- grouped the catering duties into three stages and left these twelve as a
-- single run, so this type declares no stages and the app renders one list.
-- That falls out of the model rather than needing a case in it.

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'makkah_construction',
  'الإنشاءات في مكة المكرمة',
  'Construction in Makkah',
  'ملف تشغيلي لإنشاء مخيمات منى وعرفات وتجهيزها: متابعة عقد شركة الخدمة '
  'واعتماد المخططات وتحديد مواقع الخدمات، والجولات الميدانية، حتى استلام '
  'المخيمات بمحاضر رسمية وتسليمها لفريق المشاعر.',
  'Building and fitting out the camps at Mina and Arafat: following the service '
  'company contract, approving the plans and siting the services, daily field '
  'rounds, through to taking the camps over under formal receipts and handing '
  'them to the Mashaaer team.',
  'يستمر العمل حتى الانتهاء من جميع الأعمال ضمن مراحله المختلفة',
  'Runs until all the work of its several stages is complete',
  4
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'makkah_construction'
on conflict (module_type_id, key) do nothing;

-- One مشرف, one مسؤول للمواقع والمخيمات, and as many أعضاء as the work needs.
-- No level: the file has no tree, so its people sit on the file itself, and
-- each one is handed his share of the list below.
insert into module_type_roles
  (module_type_id, code, name_ar, name_en,
   allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en,
       v.allows_multiple, false, true, v.sort_order
from (values
  ('supervisor',     'مشرف',                     'Supervisor',              false, 1),
  ('sites_officer',  'مسؤول المواقع والمخيمات',  'Sites & camps officer',   false, 2),
  ('member',         'عضو',                      'Member',                  true,  3)
) as v(code, name_ar, name_en, allows_multiple, sort_order)
cross join module_types mt
where mt.code = 'makkah_construction'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the duties
--
-- The twelve from the Administration, hanging off the type: whichever اختصاص a
-- member holds, this is the list he is handed his share of. No group_id — this
-- file states its work as one sequence.

insert into module_type_tasks
  (module_type_id, title_ar, title_en, sort_order)
select mt.id, v.title_ar, v.title_en, v.sort_order
from (values
  (
    'استلام الشروط الكمية والنوعية بالعقد المبرم مع شركة الخدمة ومتابعة الالتزام بها',
    'Taking receipt of the quantity and quality terms in the service company contract, and holding them to it',
    1
  ),
  (
    'عقد اجتماع تنسيقي مع شركة الخدمة وتحديد مسؤول التواصل',
    'Holding a coordination meeting with the service company and naming the point of contact',
    2
  ),
  (
    'التنسيق لاعتماد مخطط الإنشاءات وتحديد مواقع الخدمات والعمالة والمستودعات والمطابخ والنقاط الطبية ومكتب المطوف',
    'Coordinating approval of the construction plan and siting the services, the labour, the warehouses, the kitchens, the medical points and the mutawwif office',
    3
  ),
  (
    'متابعة تنفيذ وتجهيز مخيمات منى وعرفات وفق المواصفات المعتمدة',
    'Following the building and fitting out of the Mina and Arafat camps against the approved specification',
    4
  ),
  (
    'تنفيذ جولات ميدانية يومية ورفع تقارير دورية عن سير العمل',
    'Making daily field rounds and filing regular reports on how the work is going',
    5
  ),
  (
    'التأكد من تخصيص وفصل دورات المياه للرجال والنساء وتجهيز سواتر لحمامات النساء',
    'Confirming the washrooms are assigned and separated for men and women, and that screening is fitted to the women bathrooms',
    6
  ),
  (
    'توثيق أي نقص أو خلل في التنفيذ والتنسيق مع إدارة البعثة لمعالجته',
    'Recording any shortfall or fault in the work and coordinating with the mission administration to put it right',
    7
  ),
  (
    'تحديد الجهات المسؤولة عن الصيانة (التكييف، السباكة، الكهرباء) للتواصل عند الحاجة',
    'Establishing who is responsible for maintenance (air conditioning, plumbing, electrics), to be reached when needed',
    8
  ),
  (
    'إشعار إدارة الحج بأي نواقص مع توثيقها لضمان تداركها',
    'Notifying the Hajj administration of anything missing, recorded so it is made good',
    9
  ),
  (
    'استلام المخيمات ميدانياً بعد اكتمال الإنشاء وفق الأعداد والمساحات المتفق عليها بمحاضر رسمية',
    'Taking the camps over on the ground once building is complete, against the agreed numbers and areas, under formal receipts',
    10
  ),
  (
    'تسليم المخيمات الجاهزة لفريق المشاعر مع المخططات والمساحات المعتمدة',
    'Handing the finished camps to the Mashaaer team together with the approved plans and areas',
    11
  ),
  (
    'تنفيذ أي مهام أخرى مرتبطة بطبيعة العمل',
    'Carrying out any other duty the work calls for',
    12
  )
) as v(title_ar, title_en, sort_order)
join module_types mt on mt.code = 'makkah_construction'
where not exists (
  select 1 from module_type_tasks t
  where t.module_type_id = mt.id and t.title_ar = v.title_ar
);
