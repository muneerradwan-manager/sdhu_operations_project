-- The third operational file: الإعاشة المركزية في مكة المكرمة.
--
-- It is a roster like الطوافة والنقل — no sectors, no towers, just the people in
-- it — and its duties are handed out one by one, which 0027 built. What it adds
-- is where those duties LIVE.
--
-- In 0027 each team owned its own list: six duties of الطوافة, seven of النقل,
-- and a member drew from the list of his own team. Here the Administration names
-- four اختصاصات — مشرف، معاون، مسؤول سلامة غذائية، مختص إعاشة — and then one list of
-- fifteen duties for the file, tying none of them to any one اختصاص. So the
-- duties belong to the FILE, and any of the four may be handed any of them.
-- Which is the honest reading: inventing a split the document does not make
-- would put a wall between people who work the same kitchens.
--
-- And they arrive in three stages — التخطيط والإعداد, then مكة المكرمة, then
-- المشاعر — which is not decoration. It is when the work happens, and a list of
-- fifteen read in one run tells you far less than three lists of six, four and
-- five.
--
-- Both facts are catalog, so both are data: a task may hang off the type instead
-- of a role, and a type may declare the stages its duties fall into.

-- ------------------------------------------------------------ a duty of the FILE

-- The table is renamed first. It has held nothing but role duties since 0017 and
-- is about to hold duties that belong to no role at all, and a name that lies is
-- worse than a name that changes. Everything else — its primary key, the index on
-- role_id, the foreign key `module_assigned_tasks` points at it with — follows the
-- rename on its own.
do $$
begin
  if to_regclass('public.module_type_role_tasks') is not null
     and to_regclass('public.module_type_tasks') is null then
    alter table module_type_role_tasks rename to module_type_tasks;
    alter policy module_type_role_tasks_select on module_type_tasks
      rename to module_type_tasks_select;
    alter policy module_type_role_tasks_write on module_type_tasks
      rename to module_type_tasks_write;
  end if;
end
$$;

-- The stages that the duties of a type fall into. Named per type rather than
-- globally: the catering file works التخطيط ثم مكة ثم المشاعر, and the next file
-- will divide its work somewhere else entirely.
create table if not exists module_type_task_groups (
  id uuid primary key default gen_random_uuid(),
  module_type_id uuid not null references module_types (id) on delete cascade,
  code text not null,
  name_ar text not null,
  name_en text not null,
  sort_order int not null default 0,
  unique (module_type_id, code)
);

create index if not exists idx_task_groups_type
  on module_type_task_groups (module_type_id);

-- A duty now belongs to exactly one of two things: a role, as every duty has
-- until now, or the file itself, which is new. Never both, and never neither —
-- a duty nobody could be handed is a duty that should not have been written.
alter table module_type_tasks
  add column if not exists module_type_id uuid
    references module_types (id) on delete cascade,
  add column if not exists group_id uuid
    references module_type_task_groups (id) on delete set null;

alter table module_type_tasks alter column role_id drop not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'task_belongs_to_role_or_type'
  ) then
    alter table module_type_tasks
      add constraint task_belongs_to_role_or_type
        check (num_nonnulls(role_id, module_type_id) = 1);
  end if;
end
$$;

create index if not exists idx_module_type_tasks_type
  on module_type_tasks (module_type_id);

alter table module_type_task_groups enable row level security;

-- Stages are catalog, and read and write like the rest of it.
drop policy if exists module_type_task_groups_select on module_type_task_groups;
create policy module_type_task_groups_select on module_type_task_groups for select
  using (is_admin() or is_approved());

drop policy if exists module_type_task_groups_write on module_type_task_groups;
create policy module_type_task_groups_write on module_type_task_groups for all
  using (is_admin() or has_permission('modules.types'))
  with check (is_admin() or has_permission('modules.types'));

-- ---------------------------------------------------------------- seed: the type

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'makkah_central_catering',
  'الإعاشة المركزية في مكة المكرمة',
  'Central Catering in Makkah',
  'ملف تشغيلي للإعاشة المركزية: التخطيط مع شركات الإعاشة ومتابعة عقودها '
  'ومستودعاتها، وتشغيل مطابخ الفنادق في مكة المكرمة، واستلام الوجبات وتوزيعها '
  'في المشاعر.',
  'Central catering: planning with the catering companies and following their '
  'contracts and warehouses, running the hotel kitchens in Makkah, and receiving '
  'and distributing meals in the holy sites.',
  'ينتهي العمل بالانتهاء من جميع الأعمال ضمن مراحله المختلفة، وفق الدليل '
  'التشغيلي لبعثة الحج السورية',
  'Ends when all the work of its several stages is complete, per the Syrian Hajj '
  'Mission operational guide',
  3
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'makkah_central_catering'
on conflict (module_type_id, key) do nothing;

-- The four اختصاصات. No level: this file has no tree, so its people sit on the
-- file itself. The duties of each are handed to him — from the list of the file,
-- which none of the four owns and all of them draw on.
insert into module_type_roles
  (module_type_id, code, name_ar, name_en,
   allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en,
       v.allows_multiple, false, true, v.sort_order
from (values
  ('supervisor',          'مشرف',                  'Supervisor',           false, 1),
  ('deputy',              'معاون',                 'Deputy',               true,  2),
  ('food_safety_officer', 'مسؤول سلامة غذائية',    'Food safety officer',  true,  3),
  ('catering_specialist', 'مختص إعاشة',            'Catering specialist',  true,  4)
) as v(code, name_ar, name_en, allows_multiple, sort_order)
cross join module_types mt
where mt.code = 'makkah_central_catering'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the stages

insert into module_type_task_groups
  (module_type_id, code, name_ar, name_en, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.sort_order
from (values
  ('planning', 'التخطيط والإعداد', 'Planning & preparation', 1),
  ('makkah',   'مهام مكة المكرمة', 'In Makkah',              2),
  ('mashaaer', 'مهام المشاعر',     'In the holy sites',      3)
) as v(code, name_ar, name_en, sort_order)
cross join module_types mt
where mt.code = 'makkah_central_catering'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the duties
--
-- The fifteen from the Administration, in the three stages it grouped them into.
-- They hang off the type rather than any role: whichever اختصاص a member holds,
-- this is the list he is handed his share of.

insert into module_type_tasks
  (module_type_id, group_id, title_ar, title_en, sort_order)
select mt.id, g.id, v.title_ar, v.title_en, v.sort_order
from (values
  (
    'planning',
    'إعداد ومشاركة خطة تشغيلية شاملة، والاطلاع عليها من جميع الأعضاء',
    'Drawing up a full operational plan, shared with and read by every member',
    1
  ),
  (
    'planning',
    'مراجعة عقود شركات الإعاشة والتأكد من الالتزام ببنودها، وطلب خططها التشغيلية لضمان توافقها مع الخطة العامة',
    'Reviewing the catering contracts and holding the companies to their terms, and calling for their operational plans so they line up with the general one',
    2
  ),
  (
    'planning',
    'تنفيذ زيارات ميدانية لمستودعات الشركات للتحقق من جودة المواد ومطابقتها للمواصفات',
    'Visiting the company warehouses in person to verify the quality of the goods and that they meet specification',
    3
  ),
  (
    'planning',
    'التنسيق مع الجهات ذات العلاقة لاستلام مواقع المطابخ والمستودعات في المشاعر',
    'Coordinating with the bodies concerned to take over the kitchen and warehouse sites in the holy sites',
    4
  ),
  (
    'planning',
    'إنشاء قنوات تواصل مباشرة مع الشركات لمعالجة التحديات بشكل فوري',
    'Opening direct lines to the companies so problems are dealt with as they arise',
    5
  ),
  (
    'planning',
    'حصر بيانات لجان الطعام في التكتلات، وتقييم أداء الفريق وفق النماذج المعتمدة',
    'Compiling the details of the cluster food committees, and appraising the team against the approved forms',
    6
  ),
  (
    'makkah',
    'الإشراف على تشغيل مطابخ الإعاشة في الفنادق ومتابعة جودة الأداء',
    'Overseeing the running of the hotel catering kitchens and the quality of their work',
    7
  ),
  (
    'makkah',
    'تنفيذ جولات تفقدية أثناء تجهيز الوجبات لرصد المخالفات وضمان الالتزام بالجودة والكمية',
    'Making inspection rounds while meals are being prepared, to catch breaches and hold to quality and quantity',
    8
  ),
  (
    'makkah',
    'التنسيق مع المشرفين لضمان الالتزام بالاشتراطات الفنية والصحية',
    'Coordinating with the supervisors so the technical and health requirements are met',
    9
  ),
  (
    'makkah',
    'إعداد أدوات وبنود تقييم شاملة للمطابخ ورفع التقارير بنهاية المرحلة',
    'Drawing up full appraisal instruments for the kitchens and filing the reports at the end of the stage',
    10
  ),
  (
    'mashaaer',
    'الإشراف على استلام الوجبات والتأكد من الالتزام بالكميات والتوقيت',
    'Overseeing the receipt of meals and confirming quantities and timing are kept to',
    11
  ),
  (
    'mashaaer',
    'متابعة عمليات توزيع الوجبات وفق الخطط والجداول المعتمدة',
    'Following the distribution of meals against the approved plans and schedules',
    12
  ),
  (
    'mashaaer',
    'التعامل الفوري مع أي نقص أو خلل عبر تفعيل الخطط البديلة',
    'Meeting any shortfall or failure at once by activating the fallback plans',
    13
  ),
  (
    'mashaaer',
    'تزويد الجهات المعنية بجداول وبيانات توزيع الوجبات بشكل دقيق',
    'Supplying the bodies concerned with exact meal distribution schedules and figures',
    14
  ),
  (
    'mashaaer',
    'إعداد التقييمات النهائية والتقارير ورفعها بنهاية المرحلة',
    'Producing the closing appraisals and reports and filing them at the end of the stage',
    15
  )
) as v(group_code, title_ar, title_en, sort_order)
join module_types mt on mt.code = 'makkah_central_catering'
join module_type_task_groups g
  on g.module_type_id = mt.id and g.code = v.group_code
where not exists (
  select 1 from module_type_tasks t
  where t.module_type_id = mt.id and t.title_ar = v.title_ar
);
