-- The job description (الوصف الوظيفي) of each role.
--
-- 0017 seeded each role with a short invented task list, flagged there as a
-- starting point rather than final. This is the real text from the
-- Administration, and it is a description — one paragraph stating the whole
-- remit of the post — not a checklist. So it lives on the role itself.
--
-- `module_type_role_tasks` stays: a description says what the post IS, while a
-- task list says what is due this season, and the two are edited by different
-- people at different times. The invented entries are cleared out for every
-- role that now has an authoritative description; أعضاء البعثة keeps its list,
-- having been given no description.

alter table module_type_roles
  add column if not exists description_ar text,
  add column if not exists description_en text;

update module_type_roles r
   set description_ar = v.description_ar
  from (values
  (
    'sector_supervisor',
    'قيادة وإدارة القطاع بالكامل من خلال التخطيط المسبق، والإشراف على الأبراج '
    'والتسكين والمخيمات، ومتابعة أداء الفرق، والتنسيق بين الإدارات (الخدمية، '
    'الصحية، الدينية)، إضافةً إلى معالجة المشكلات الميدانية، وضمان جودة الخدمات '
    'والالتزام بالتعليمات، وتدقيق البيانات، وإعداد التقارير والتقييمات النهائية.'
  ),
  (
    'sector_deputy',
    'مساندة مشرف القطاع في جميع المهام التنفيذية، عبر المتابعة الميدانية '
    'للأعمال، ودعم التنسيق بين الفرق، والمساهمة في حل المشكلات، وضمان تنفيذ '
    'الخطط والتعليمات بكفاءة وفق التوجيهات المعتمدة.'
  ),
  (
    'tower_supervisor',
    'الإشراف على إدارة وتشغيل البرج بشكل مباشر، ابتداءً من متابعة تجهيز الفندق '
    'وتنظيم التسكين، مروراً بالإشراف على استقبال الحجاج ومتابعة راحتهم وخدماتهم '
    '(الإعاشة، النظافة، النقل)، وانتهاءً بالإشراف على التفويج والترحيل، مع '
    'معالجة المشكلات اليومية، ورفع التقارير، وتقييم الأداء.'
  ),
  (
    'tower_deputy',
    'دعم مشرف البرج في التنفيذ الميداني اليومي، من خلال متابعة التسكين '
    'والخدمات، ومراقبة الالتزام داخل البرج، والمساهمة في التفويج والترحيل، '
    'وتنفيذ المهام التشغيلية المباشرة لضمان سير العمل بسلاسة.'
  )
) as v(role_code, description_ar),
  module_types mt
 where mt.code = 'makkah_sectors_towers'
   and r.module_type_id = mt.id
   and r.code = v.role_code;

update module_type_roles r
   set description_en = v.description_en
  from (values
  (
    'sector_supervisor',
    'Leads and runs the whole sector: advance planning, oversight of the '
    'towers, accommodation and camps, tracking team performance, coordinating '
    'between the service, medical and religious departments, resolving issues '
    'on the ground, assuring service quality and compliance, auditing the data, '
    'and producing the closing reports and evaluations.'
  ),
  (
    'sector_deputy',
    'Backs the sector supervisor across every executive duty: following the '
    'work in the field, supporting coordination between teams, helping resolve '
    'problems, and making sure plans and instructions are carried out '
    'efficiently and as approved.'
  ),
  (
    'tower_supervisor',
    'Runs the tower directly — from preparing the hotel and organising '
    'accommodation, through receiving the pilgrims and looking after their '
    'comfort and services (catering, cleaning, transport), to overseeing '
    'grouping and departure — handling day-to-day problems, filing reports and '
    'appraising performance.'
  ),
  (
    'tower_deputy',
    'Supports the tower supervisor in the daily field work: following '
    'accommodation and services, watching compliance inside the tower, helping '
    'with grouping and departure, and carrying out the hands-on operational '
    'tasks that keep the tower running.'
  )
) as v(role_code, description_en),
  module_types mt
 where mt.code = 'makkah_sectors_towers'
   and r.module_type_id = mt.id
   and r.code = v.role_code;

-- The placeholder duties those four roles were seeded with are superseded.
delete from module_type_role_tasks t
 using module_type_roles r, module_types mt
 where r.id = t.role_id
   and mt.id = r.module_type_id
   and mt.code = 'makkah_sectors_towers'
   and r.description_ar is not null;
