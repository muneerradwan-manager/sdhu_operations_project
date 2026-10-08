-- The tenth operational file: المتابعة والتقييم.
--
-- A roster with no tree, مشرف وعدة أعضاء, eight duties on the file. That part is
-- 0033 again.
--
-- What is new is at the other end of the file. 0024 gave a type an
-- `end_condition` because a file ends on an EVENT rather than a date — the same
-- event every season — and left the start as a plain date entered per file.
-- That has held for nine files. It does not hold here: this one begins من تاريخ
-- اعتماد مجموعات الحج السوري, which is an event of exactly the same kind, and
-- الطوافة والنقل began من تاريخ صدور القرار, which was simply dropped at the time
-- for want of anywhere to put it.
--
-- So the type gains a `start_condition` beside its `end_condition`. The date on
-- the file stays and stays required — somebody still has to say when the work
-- actually began — and the condition says what that date is the date OF.

alter table module_types
  add column if not exists start_condition_ar text,
  add column if not exists start_condition_en text;

-- The one that was lost. Stated in the Administration text for الطوافة والنقل
-- and recorded nowhere until now.
update module_types
   set start_condition_ar = 'يبدأ عمل الفريق من تاريخ صدور القرار',
       start_condition_en = 'Begins on the date the decision is issued'
 where code = 'makkah_tawafa_transport'
   and start_condition_ar is null;

-- ---------------------------------------------------------------- seed: the type

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   start_condition_ar, start_condition_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'follow_up_evaluation',
  'المتابعة والتقييم',
  'Follow-up & Evaluation',
  'ملف تشغيلي لعمل فريق التقييم: وضع آلية تقييم موحدة والإشراف على تطبيقها، '
  'وتقييم المجموعات والتكتلات إدارياً وشرعياً، ومراجعة التوثيقات، ورفع '
  'التوصيات أثناء الموسم حتى التقرير الختامي للجنة التقييم المركزية.',
  'The evaluation team: setting one method of appraisal and overseeing its use, '
  'appraising the groups and clusters administratively and religiously, '
  'reviewing the records, and filing recommendations through the season up to '
  'the closing report to the central evaluation committee.',
  'يبدأ عمل الفريق من تاريخ اعتماد مجموعات الحج السوري',
  'Begins on the date the Syrian Hajj groups are approved',
  'يستمر العمل حتى انتهاء كافة أعمال موسم الحج',
  'Runs until all the work of the Hajj season is complete',
  10
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'follow_up_evaluation'
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
where mt.code = 'follow_up_evaluation'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the duties

insert into module_type_tasks
  (module_type_id, title_ar, title_en, sort_order)
select mt.id, v.title_ar, v.title_en, v.sort_order
from (values
  (
    'إعداد وتنفيذ الخطة التشغيلية لعمل فريق التقييم ومشاركتها مع الجهات المعنية',
    'Drawing up and running the operational plan for the evaluation team, and sharing it with the bodies concerned',
    1
  ),
  (
    'وضع آلية تقييم موحدة والإشراف على تطبيقها في جميع مراحل العمل',
    'Setting one method of appraisal and overseeing its use at every stage of the work',
    2
  ),
  (
    'عقد الاجتماعات والتنسيق مع مسؤولي التقييم والفرق واللجان لضمان وضوح الإجراءات وتوحيدها',
    'Holding meetings and coordinating with the evaluation officers, the teams and the committees so the procedures are clear and the same for everyone',
    3
  ),
  (
    'الإشراف على عمليات التقييم الإداري والشرعي للمجموعات والتكتلات بالتنسيق مع الجهات ذات العلاقة',
    'Overseeing the administrative and religious appraisal of the groups and clusters, with the bodies concerned',
    4
  ),
  (
    'إعداد الجداول الزمنية لمراحل التقييم وضمان إنجازها وفق المواعيد المحددة',
    'Drawing up the timetable for the appraisal stages and seeing them finished on time',
    5
  ),
  (
    'متابعة ومراقبة أعمال التقييم ومراجعة التوثيقات لضمان الدقة والموضوعية واستكمال المتطلبات',
    'Following and monitoring the appraisal work and reviewing the records, so they are accurate, impartial and complete',
    6
  ),
  (
    'رفع التقارير والتوصيات لمعالجة الملاحظات وتحسين الأداء أثناء الموسم',
    'Filing reports and recommendations to address findings and improve performance during the season',
    7
  ),
  (
    'إعداد ورفع التقرير الختامي للجنة التقييم المركزية',
    'Producing and filing the closing report to the central evaluation committee',
    8
  )
) as v(title_ar, title_en, sort_order)
join module_types mt on mt.code = 'follow_up_evaluation'
where not exists (
  select 1 from module_type_tasks t
  where t.module_type_id = mt.id and t.title_ar = v.title_ar
);
