-- The seventh operational file: الطيران المركزي لحجاج سوريا.
--
-- A roster with no tree: مشرف واحد وعدة أعضاء, like the four files before it.
--
-- Its duties come written as paragraphs rather than lines, and each names the
-- part of the operation it covers — the central plan, a sector, an office, the
-- reception of returning pilgrims, the luggage. They are duties all the same,
-- handed out one by one, NOT posts with job descriptions: this file has two
-- اختصاصات and no more.
--
-- So each keeps its paragraph. `module_type_tasks` has carried a description
-- beside the title since 0017 and nothing has needed one until now: the title
-- says what the duty is, and the paragraph the Administration wrote says what
-- it involves, word for word. Summarising it in the title and throwing the rest
-- away would lose the only authoritative statement of the work there is.

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'central_aviation',
  'الطيران المركزي لحجاج سوريا',
  'Central Aviation',
  'ملف تشغيلي لخطة الطيران: توزيع الرحلات ومطابقة أعداد الحجاج وبياناتهم، '
  'ومتابعة سير الرحلات ميدانياً، واستقبال العائدين، وشحن الحقائب ومطابقتها '
  'مع الرحلات المغادرة.',
  'The flight plan: distributing the flights, reconciling pilgrim numbers and '
  'records, following the flights on the ground, receiving those returning, and '
  'the luggage freight against the departing flights.',
  'يستمر العمل حتى ترحيل آخر حاج',
  'Runs until the last pilgrim has departed',
  7
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'central_aviation'
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
where mt.code = 'central_aviation'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the duties
--
-- Title, then the Administration paragraph beneath it unchanged.

insert into module_type_tasks
  (module_type_id, title_ar, title_en, description_ar, description_en, sort_order)
select mt.id, v.title_ar, v.title_en, v.description_ar, v.description_en,
       v.sort_order
from (values
  (
    'إدارة خطة الطيران العامة والإشراف على توزيع الرحلات',
    'Running the general flight plan and overseeing how the flights are distributed',
    'إدارة وتنفيذ خطة الطيران العامة، والإشراف على توزيع الرحلات وتعيين المشرفين والتنسيق مع الفرق والجهات المعنية لضمان سير العمل بكفاءة، إضافة إلى معالجة الحالات الطارئة ومتابعة تقييم الأداء ورفع التقارير الختامية لرئيس المكتب الإداري.',
    'Running the general flight plan: distributing the flights, appointing the supervisors, coordinating with the teams and the bodies concerned so the work runs efficiently, handling emergencies, tracking performance and filing the closing reports to the head of the administrative office.',
    1
  ),
  (
    'الإشراف على تنفيذ خطة الطيران ضمن القطاع (حلب – دمشق)',
    'Overseeing the flight plan within a sector (Aleppo – Damascus)',
    'الإشراف على تنفيذ خطة الطيران ضمن القطاع، ومطابقة أعداد الحجاج وتوزيعهم على الرحلات، ومعالجة المشكلات التشغيلية ميدانياً، إضافة إلى متابعة أداء التكتلات وإعداد التقارير الدورية ورفعها لمدير الطيران المركزي.',
    'Overseeing the flight plan inside the sector, reconciling pilgrim numbers and their distribution across the flights, resolving operational problems on the ground, tracking how the clusters perform, and filing regular reports to the central aviation manager.',
    2
  ),
  (
    'متابعة بيانات الحجاج والإداريين وتنظيم توزيع الرحلات (الداخل والخارج)',
    'Following pilgrim and staff records and organising the flight distribution (inbound and outbound)',
    'متابعة بيانات الحجاج والإداريين ومطابقتها على النظام، وتنظيم توزيع الرحلات والتنسيق مع المنسقين، إضافة إلى متابعة الحالات الخاصة والإشراف الميداني على سير الرحلات وإعداد التقارير اليومية.',
    'Following the records of pilgrims and staff and reconciling them against the system, organising the flight distribution and coordinating with the coordinators, following special cases, supervising the flights on the ground, and producing the daily reports.',
    3
  ),
  (
    'مساندة مشرف المكتب في متابعة البيانات والرحلات',
    'Backing the office supervisor on records and flights',
    'مساندة مشرف المكتب في متابعة بيانات الحجاج والرحلات، والتنسيق مع المنسقين، ومتابعة الحالات الخاصة، والمساهمة في تسيير الرحلات وإعداد التقارير اليومية.',
    'Backing the office supervisor in following pilgrim records and flights, coordinating with the coordinators, following special cases, helping the flights run, and producing the daily reports.',
    4
  ),
  (
    'استقبال الحجاج العائدين ومتابعة إجراءات الوصول والحقائب',
    'Receiving returning pilgrims and following arrival and luggage',
    'استقبال الحجاج العائدين، ومتابعة إجراءات الوصول واستلام الحقائب، ومعالجة حالات الفقدان، إضافة إلى رفع الملاحظات والتقارير المتعلقة بمرحلة الاستقبال.',
    'Receiving the returning pilgrims, following the arrival procedures and the collection of luggage, dealing with anything lost, and filing the observations and reports for the reception stage.',
    5
  ),
  (
    'الإشراف على تجهيز وتحميل الأمتعة ومطابقتها مع الرحلات المغادرة',
    'Overseeing luggage preparation and loading against the departing flights',
    'الإشراف على تجهيز وتحميل أمتعة الحجاج ومطابقتها مع الرحلات المغادرة، والتنسيق مع الجهات المعنية لضمان سلامة نقل الحقائب ومعالجة أي مشكلات تتعلق بها.',
    'Overseeing the preparation and loading of pilgrim luggage and matching it to the departing flights, coordinating with the bodies concerned so the luggage travels safely, and dealing with any problem that arises with it.',
    6
  )
) as v(title_ar, title_en, description_ar, description_en, sort_order)
join module_types mt on mt.code = 'central_aviation'
where not exists (
  select 1 from module_type_tasks t
  where t.module_type_id = mt.id and t.title_ar = v.title_ar
);
