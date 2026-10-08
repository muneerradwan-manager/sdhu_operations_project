-- What the 1447 decisions say that the catalog did not.
--
-- Fifteen official decisions of the Syrian Hajj Mission for 1447هـ were entered
-- into the app (assets/docs). Fourteen of them fit the catalog as it stood.
-- Where they did not, the decision is the authority and the catalog is what
-- changes — these are issued, signed records of who serves where, not a data
-- entry exercise that can be talked into the existing shape.
--
-- Four places where they did not fit, and one file the catalog had no type for.

-- ------------------------------------------------- a برج houses several تكتلات
--
-- 0051 tied a برج to ONE تكتل and made it unique across the file. 3142 breaks
-- that on four of its twenty towers: 'القصواء/الإجابة' share عفراء, and
-- 'الضياء/ارتقاء/البراق' share بركة اليقين. A تكتل is a body of pilgrims, and
-- more than one of them is housed in the same tower — the column in the
-- decision is 'اسم التكتل' precisely because it can name more than one.
--
-- So the تكتل stops being an attribute of the tower and becomes a rung beneath
-- it. Several fit under one برج; `uq_module_nodes_entry` still allows each
-- تكتل into the file exactly once, which is the rule worth keeping; and the
-- editor already draws whatever depth a type declares, so nothing else moves.
--
-- The alternative was a join table. This is the same fact with no new DDL and
-- no second way of saying where a تكتل sits.

insert into module_type_levels
  (module_type_id, code, name_ar, name_en, depth, reference_set_id)
select mt.id, 'cluster', 'التكتل', 'Cluster', 3, rs.id
from module_types mt
join reference_sets rs on rs.code = 'clusters'
where mt.code = 'makkah_sectors_towers'
on conflict (module_type_id, code) do nothing;

-- The tower no longer names a cluster of its own; the rung below does.
update module_type_levels lv
   set secondary_reference_set_id = null
  from module_types mt
 where mt.id = lv.module_type_id
   and mt.code = 'makkah_sectors_towers'
   and lv.code = 'tower';

-- ------------------------------------------------------- a مخيم and its خيمة
--
-- 0050 and 0052 gave a camp a الطاقة الاستيعابية and made it REQUIRED, on the
-- reasoning that the distribution is made against it. 3172 and 3173 distribute
-- without it: every camp is written as 'رقم المخيم: 16 / رقم الخيمة: 154' and
-- no capacity appears anywhere in either decision. A required field the source
-- document does not have does not make the data better — it makes the file
-- impossible to enter honestly.
--
-- So the tent number is added, and capacity becomes optional: recorded when it
-- is known, and not invented when it is not.

update module_type_fields f
   set is_required = false
  from module_types mt, module_type_levels lv
 where mt.id = f.module_type_id
   and lv.id = f.level_id
   and mt.code in ('arafat_camp_assignment', 'mina_camp_assignment')
   and lv.code = 'camp'
   and f.key = 'capacity';

insert into module_type_fields
  (module_type_id, level_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, lv.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
       false, v.sort_order
from (values
  ('tents',  'رقم الخيمة',   'Tent number',     'text',     1),
  -- مخيم 16 allots space to الإدارة الصحية and أعضاء اللجنة الاعتبارية beside
  -- its named members. Those are real allocations and not men: they belong on
  -- the camp, and must never be invented as accounts.
  ('bodies', 'جهات مخصّصة',  'Allotted bodies', 'textarea', 4)
) as v(key, label_ar, label_en, kind, sort_order)
join module_types mt
  on mt.code in ('arafat_camp_assignment', 'mina_camp_assignment')
join module_type_levels lv
  on lv.module_type_id = mt.id and lv.code = 'camp'
where not exists (
  select 1 from module_type_fields f
   where f.module_type_id = mt.id and f.level_id = lv.id and f.key = v.key
);

-- --------------------------------------------- a مركز may have two مشرفين
--
-- 3173 runs مركز 10 and مركز 12 as one, and heads that table 'مشرفو المراكز:
-- المقداد مهلهل / صبحي مصطفى اصطيف' — plural, two men. The role admitted one,
-- which would have meant dropping a supervisor the decision names.

update module_type_roles r
   set allows_multiple = true
  from module_types mt
 where mt.id = r.module_type_id
   and mt.code = 'mina_camp_assignment'
   and r.code = 'center_supervisor';

-- ------------------------------------------ the fifteenth file: لجنة 5 نجوم
--
-- 3197 forms a committee to price what five-star pilgrims were promised against
-- what they received. It is not an office and has no tree: a رئيس and his
-- أعضاء, held once for the file, with the duties المادة (2) states. It is the
-- first file in the catalog that ends on a COUNT of days rather than an event,
-- which is why its end condition says fifteen days rather than naming one.

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   start_condition_ar, start_condition_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'five_star_services_review',
  'لجنة دراسة الخدمات المقدمة لحجاج مستوى (5 نجوم)',
  'Five-star pilgrim services review committee',
  'لجنة تدرس الخدمات المقدَّمة لحجاج مستوى (5 نجوم) وتتحقق من مطابقتها للعقود '
  'المبرمة، وتقدّر قيمة ما لم يُستلم من خدمات تمهيداً لاقتراح التعويض المالي '
  'للحجاج المتضررين.',
  'Studies the services delivered to five-star pilgrims against the signed '
  'contracts, and prices what was not delivered so that compensation can be '
  'proposed for the pilgrims affected.',
  'يبدأ عمل اللجنة من تاريخ صدور القرار',
  'Begins on the date the decision was issued',
  'ينتهي العمل بعد خمسة عشر يوماً برفع التقرير الختامي والتوصيات إلى إدارة '
  'الحج والعمرة',
  'Ends after fifteen days, when the final report and recommendations reach '
  'the Hajj and Umrah Administration',
  15
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'five_star_services_review'
  and not exists (
    select 1 from module_type_fields f
     where f.module_type_id = mt.id and f.level_id is null
       and f.key = 'official_pdf'
  );

insert into module_type_roles
  (module_type_id, code, name_ar, name_en, description_ar, description_en,
   allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.description_ar, v.description_en,
       v.allows_multiple, v.is_required, true, v.sort_order
from (values
  ('chair', 'رئيس اللجنة', 'Committee chair',
   'يرأس اللجنة ويوجّه عملها ويرفع تقريرها الختامي والتوصيات إلى إدارة الحج والعمرة.',
   'Chairs the committee and files its closing report and recommendations.',
   false, true, 1),
  ('member', 'عضو', 'Member',
   'يشارك في الدراسة الميدانية والمالية للخدمات المقدَّمة ويوثّق ما يرصده من قصور.',
   'Takes part in the field and financial study and documents what falls short.',
   true, false, 2)
) as v(code, name_ar, name_en, description_ar, description_en,
       allows_multiple, is_required, sort_order)
cross join module_types mt
where mt.code = 'five_star_services_review'
on conflict (module_type_id, code) do nothing;

insert into module_type_task_groups
  (module_type_id, code, name_ar, name_en, sort_order)
select mt.id, 'duties', 'مهام اللجنة', 'Committee duties', 1
from module_types mt
where mt.code = 'five_star_services_review'
on conflict (module_type_id, code) do nothing;

insert into module_type_tasks
  (module_type_id, group_id, title_ar, title_en, sort_order)
select mt.id, g.id, v.title_ar, v.title_en, v.sort_order
from (values
  ('دراسة ومتابعة كفاية الخدمات المقدَّمة للحجاج والتحقق من مطابقتها للمواصفات والعقود المبرمة',
   'Study the services delivered to the pilgrims and check them against the specifications and the signed contracts', 1),
  ('تقييم جودة الخدمات المقدَّمة على أرض الواقع مقابل المبالغ المالية الإجمالية المدفوعة من الحجاج، وتحديد أي قصور أو خلل في التنفيذ',
   'Assess the quality actually delivered against the total paid by the pilgrims, and identify any shortfall in delivery', 2),
  ('إعداد دراسة مالية دقيقة ومستفيضة لتحديد قيمة التعويض المقترح للحجاج المتضررين بناءً على فارق الجودة والخدمات غير المستلمة',
   'Produce a detailed financial study setting the compensation to be proposed for the pilgrims affected', 3),
  ('إرسال التقرير الختامي والتوصيات ذات الصلة إلى إدارة الحج والعمرة',
   'Send the closing report and its recommendations to the Hajj and Umrah Administration', 4)
) as v(title_ar, title_en, sort_order)
join module_types mt on mt.code = 'five_star_services_review'
join module_type_task_groups g
  on g.module_type_id = mt.id and g.code = 'duties'
where not exists (
  select 1 from module_type_tasks t
   where t.module_type_id = mt.id and t.title_ar = v.title_ar
);

-- ----------------------------------------- correcting and removing an employee
--
-- The section could open a record, make one, freeze one and read its documents,
-- but never CORRECT one and never remove one. A roster entered from paper is
-- exactly the case where a name is going to be wrong, so the two actions are
-- given codes of their own rather than being folded into `employees.create`:
-- being allowed to add somebody is not the same as being allowed to delete him.

insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('employees.edit',   'Edit employee records',   6),
  ('employees.delete', 'Delete employee records', 7)
) as v(code, description, sort_order)
join permissions p on p.code = 'employees'
on conflict (code) do nothing;
