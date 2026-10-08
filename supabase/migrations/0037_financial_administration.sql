-- The eighth operational file: الإدارة المالية في مكة المكرمة والمدينة المنورة.
--
-- A roster with no tree, مشرف وأعضاء, thirteen duties on the file under two
-- headings. INSERTs only, like the four before it.
--
-- Two things about it are its own. It is the first file that spans both cities
-- rather than sitting in one — money follows the mission wherever it goes, and
-- the type says so in its name rather than by being opened twice.
--
-- And its two groups are neither stages of a sequence nor sides of an office:
-- المهام الإشرافية and المهام التنفيذية are two LEVELS of the same work, the one
-- approving what the other carries out. The grouping does not care which of the
-- three it is being used for, which is why it has fitted every file since 0028
-- without being touched.

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'financial_administration',
  'الإدارة المالية في مكة المكرمة والمدينة المنورة',
  'Financial Administration in Makkah & Madinah',
  'ملف تشغيلي للعمليات المالية للبعثة: الإشراف على عقود الخدمات وسداد '
  'مستحقاتها، وتنظيم الصرف وتدقيق الفواتير والمطالبات، ومتابعة السلف، وضبط '
  'الإيرادات والمصروفات، حتى التقرير المالي الختامي.',
  'The financial side of the mission: overseeing the service contracts and '
  'paying what is due on them, organising disbursement, auditing invoices and '
  'claims, following advances, controlling income and expenditure, through to '
  'the closing financial report.',
  'يستمر العمل حتى استكمال جميع الأعمال المالية المتعلقة بموسم الحج',
  'Runs until every financial matter of the Hajj season is settled',
  8
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'financial_administration'
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
where mt.code = 'financial_administration'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the groups

insert into module_type_task_groups
  (module_type_id, code, name_ar, name_en, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.sort_order
from (values
  ('supervisory', 'المهام الإشرافية', 'Supervisory', 1),
  ('executive',   'المهام التنفيذية', 'Executive',   2)
) as v(code, name_ar, name_en, sort_order)
cross join module_types mt
where mt.code = 'financial_administration'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the duties

insert into module_type_tasks
  (module_type_id, group_id, title_ar, title_en, sort_order)
select mt.id, g.id, v.title_ar, v.title_en, v.sort_order
from (values
  (
    'supervisory',
    'إعداد الخطة التشغيلية للفريق ورفعها للاعتماد ومتابعة تنفيذها',
    'Drawing up the operational plan for the team, submitting it for approval and following it through',
    1
  ),
  (
    'supervisory',
    'الإشراف العام على كافة العمليات المالية لبعثة الحج',
    'General oversight of every financial operation of the Hajj mission',
    2
  ),
  (
    'supervisory',
    'التنسيق مع رؤساء الفرق وتقديم الدعم والمشورة في الجوانب المالية',
    'Coordinating with the team heads and advising them on financial matters',
    3
  ),
  (
    'supervisory',
    'متابعة تنفيذ عقود الخدمات (السكن، الإعاشة، النقل ...إلخ) وضمان سداد مستحقاتها في مواعيدها',
    'Following performance of the service contracts (accommodation, catering, transport and the rest) and making sure what is due on them is paid on time',
    4
  ),
  (
    'supervisory',
    'اعتماد التقارير المالية الدورية ورفعها للجهات المختصة',
    'Approving the periodic financial reports and filing them with the authorities concerned',
    5
  ),
  (
    'supervisory',
    'الإشراف على إعداد التقرير المالي الختامي متضمناً النتائج والملاحظات والتوصيات',
    'Overseeing the closing financial report, with its findings, observations and recommendations',
    6
  ),
  (
    'executive',
    'تنظيم عمليات الصرف وفق الأنظمة والتعليمات المالية المعتمدة',
    'Organising disbursement under the approved financial rules and instructions',
    7
  ),
  (
    'executive',
    'تدقيق الفواتير والمطالبات المالية والتأكد من استيفائها للإجراءات النظامية',
    'Auditing invoices and financial claims and confirming they meet the required procedure',
    8
  ),
  (
    'executive',
    'متابعة السلف المالية الممنوحة وتسويتها ضمن المدة المحددة',
    'Following the advances that were granted and settling them within the set period',
    9
  ),
  (
    'executive',
    'ضبط حركة الإيرادات والمصروفات التشغيلية وتوثيقها بشكل يومي',
    'Controlling the movement of operational income and expenditure and recording it daily',
    10
  ),
  (
    'executive',
    'إعداد السجلات المالية وحفظ المستندات المحاسبية وفق الأصول',
    'Keeping the financial records and filing the accounting documents properly',
    11
  ),
  (
    'executive',
    'تقديم الدعم المالي الميداني للفرق لضمان حسن سير العمل',
    'Giving the teams financial support in the field so the work runs as it should',
    12
  ),
  (
    'executive',
    'معالجة الإشكالات المالية الطارئة ورفعها للجهات المختصة عند الحاجة',
    'Dealing with urgent financial problems and escalating them to the authorities concerned when needed',
    13
  )
) as v(group_code, title_ar, title_en, sort_order)
join module_types mt on mt.code = 'financial_administration'
join module_type_task_groups g
  on g.module_type_id = mt.id and g.code = v.group_code
where not exists (
  select 1 from module_type_tasks t
  where t.module_type_id = mt.id and t.title_ar = v.title_ar
);
