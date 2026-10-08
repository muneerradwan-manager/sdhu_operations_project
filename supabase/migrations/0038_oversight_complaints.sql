-- The ninth operational file: الرقابة والشكاوى في مكة المكرمة والمدينة المنورة.
--
-- A roster with no tree, nine duties on the file, INSERTs only — and one thing
-- worth stating plainly, because it is the first file to invert something every
-- file before it took for granted.
--
-- In the other eight the مشرف comes first and the أعضاء after him: he directs,
-- they carry out, and the role sort_order has quietly been seniority. Here it is
-- not. الأعضاء are the file — they receive the complaints, verify them in the
-- field and issue the decisions — and المنسق exists to serve them. So العضو is
-- ordered first and المنسق second, and everywhere the app lists roles, in the
-- editor and on the roster alike, the members lead.
--
-- Nothing in the schema had to change for that. sort_order was never defined as
-- rank; it is the order the file is read in, and this file is read members
-- first.

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'oversight_complaints',
  'الرقابة والشكاوى في مكة المكرمة والمدينة المنورة',
  'Oversight & Complaints in Makkah & Madinah',
  'ملف تشغيلي لاستقبال شكاوى الحجاج واعتراضاتهم ودراستها والتحقق منها '
  'ميدانياً، والسعي للصلح الودي، وتوثيق كل ما يُتخذ بشأنها، حتى إصدار القرارات '
  'وفق اللوائح المعتمدة.',
  'Receiving pilgrim complaints and objections, studying them and verifying '
  'them in the field, seeking amicable settlement, recording everything done '
  'about them, through to issuing decisions under the approved regulations.',
  'يستمر العمل حتى الانتهاء من جميع الأعمال ضمن مراحله المختلفة',
  'Runs until all the work of its several stages is complete',
  9
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'oversight_complaints'
on conflict (module_type_id, key) do nothing;

-- العضو first, المنسق second. See the note at the top: in this file the members
-- hold the work and the coordinator supports them, which is the reverse of
-- every file before it and is expressed entirely in this ordering.
insert into module_type_roles
  (module_type_id, code, name_ar, name_en,
   allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en,
       v.allows_multiple, false, true, v.sort_order
from (values
  ('member',      'عضو',  'Member',      true,  1),
  ('coordinator', 'منسق', 'Coordinator', false, 2)
) as v(code, name_ar, name_en, allows_multiple, sort_order)
cross join module_types mt
where mt.code = 'oversight_complaints'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the duties
--
-- In the order a complaint travels: the form it is written on, the box it is
-- put in, receiving it, following it, recording it, settling it, and — for the
-- ones that settle nowhere — the decision at the end.

insert into module_type_tasks
  (module_type_id, title_ar, title_en, sort_order)
select mt.id, v.title_ar, v.title_en, v.sort_order
from (values
  (
    'إعداد نموذج موحد ورقي وإلكتروني لتقديم الشكاوى وتسهيل إجراءاتها',
    'Producing one complaint form, on paper and electronically, and making it easy to submit',
    1
  ),
  (
    'متابعة جاهزية الفنادق بصناديق الشكاوى والنماذج والملصقات المعتمدة',
    'Checking the hotels are ready with complaint boxes, forms and the approved notices',
    2
  ),
  (
    'استقبال الشكاوى والاعتراضات ودراستها والتحقق منها ميدانياً',
    'Receiving complaints and objections, studying them and verifying them in the field',
    3
  ),
  (
    'متابعة الشكاوى خلال مرحلة السفر والعمل على معالجتها وفق الإجراءات المعتمدة',
    'Following complaints through the travel stage and resolving them under the approved procedure',
    4
  ),
  (
    'توثيق جميع الشكاوى والإجراءات المتخذة بشأنها',
    'Recording every complaint and everything done about it',
    5
  ),
  (
    'معالجة الشكاوى والسعي للصلح الودي بين الأطراف متى أمكن',
    'Resolving complaints and seeking an amicable settlement between the parties wherever possible',
    6
  ),
  (
    'استكمال متابعة الشكاوى غير المحسومة بعد العودة',
    'Carrying on with the unresolved complaints after the return',
    7
  ),
  (
    'اتخاذ الإجراءات الاحترازية اللازمة قبل إصدار القرار النهائي',
    'Taking the necessary precautionary steps before the final decision is issued',
    8
  ),
  (
    'إصدار القرارات وفق لائحة المكافآت والعقوبات والسوابق الجزائية المعتمدة',
    'Issuing decisions under the approved regulations on rewards, penalties and prior offences',
    9
  )
) as v(title_ar, title_en, sort_order)
join module_types mt on mt.code = 'oversight_complaints'
where not exists (
  select 1 from module_type_tasks t
  where t.module_type_id = mt.id and t.title_ar = v.title_ar
);
