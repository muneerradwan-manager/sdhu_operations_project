-- الوصف الوظيفي was seeded once, in 0010, from the pilgrimage itself: رئيس
-- البعثة, مرشد ديني, عامل خدمات — titles that describe a POST on a mission,
-- not a desk at إدارة الحج والعمرة. A data-entry clerk, an accountant, an
-- informatics engineer — the people who staff the directorate the rest of the
-- year — had nowhere on the list that named what they actually do.
--
-- The list is replaced with one built for the office rather than the trip.
-- Titles that also describe a real permanent post — سائق, مترجم, طبيب,
-- ممرض, مرشد ديني — are kept; the ones that only made sense as a role held
-- ON a mission (رئيس البعثة, نائب رئيس البعثة, مشرف) move to where that
-- belongs already, `module_type_roles`, and are retired here.
--
-- Retired rather than deleted: `profiles.job_title_id` is `on delete
-- restrict`, and real employees are already pointed at several of these rows
-- (see `reference_item_in_use()`, 0085). Deactivating removes a title from
-- every dropdown — `fetchChoices` reads `is_active = true` only — without
-- disturbing a single profile that already carries one.
--
-- Upserted against `uq_reference_items_name_per_season`
-- (set_id, name_ar, coalesce(season_id, …), coalesce(variant, …)) so a name
-- job_titles already has is reactivated and relabelled in place rather than
-- duplicated, and running this file twice changes nothing the second time.

with target as (
  select id from reference_sets where code = 'job_titles'
),
wanted (name_ar, name_en, sort_order) as (
  values
    -- الإدارة والتنظيم
    ('مدير عام',                       'Director General',            10),
    ('مدير إدارة',                     'Department Director',         20),
    ('نائب مدير',                      'Deputy Director',             30),
    ('مدير مكتب',                      'Office Manager',              40),
    ('رئيس قسم',                       'Section Head',                50),
    ('مساعد إداري',                    'Administrative Assistant',    60),
    ('أمين سر',                        'Executive Secretary',         70),
    -- الشؤون المالية
    ('محاسب',                          'Accountant',                  80),
    ('محاسب أول',                      'Senior Accountant',           90),
    ('أمين صندوق',                     'Cashier',                    100),
    ('مدقق حسابات',                    'Auditor',                    110),
    -- الموارد البشرية
    ('مسؤول موارد بشرية',              'HR Officer',                 120),
    ('أخصائي توظيف',                   'Recruitment Specialist',     130),
    -- تقنية المعلومات
    ('مهندس معلوماتية',                'IT Engineer',                140),
    ('مطور نظم',                       'Systems Developer',          150),
    ('مسؤول شبكات',                    'Network Administrator',      160),
    ('فني دعم تقني',                   'IT Support Technician',      170),
    -- اللوجستيات والخدمات
    ('مسؤول لوجستي',                   'Logistics Officer',          180),
    ('مسؤول مخازن',                    'Warehouse Officer',          190),
    ('سائق',                           'Driver',                     200),
    ('مسؤول صيانة',                    'Maintenance Officer',        210),
    ('عامل خدمات عامة',                'General Services Worker',    220),
    -- الشؤون القانونية
    ('مستشار قانوني',                  'Legal Advisor',              230),
    -- الإعلام والعلاقات العامة
    ('مسؤول إعلام وعلاقات عامة',       'Media & PR Officer',         240),
    ('مصمم جرافيك',                    'Graphic Designer',           250),
    -- الأرشفة والبيانات
    ('أمين أرشيف ووثائق',              'Archives & Records Officer', 260),
    ('مدخل بيانات',                    'Data Entry Clerk',           270),
    -- التخطيط والجودة
    ('مسؤول تخطيط ومتابعة',            'Planning & Follow-up Officer', 280),
    ('مسؤول جودة',                     'Quality Officer',            290),
    -- المشتريات
    ('مسؤول مشتريات وتموين',           'Procurement & Supply Officer', 300),
    -- خدمة الجمهور
    ('موظف خدمة جمهور',                'Public Service Officer',     310),
    ('موظف استقبال',                   'Receptionist',                320),
    -- الترجمة
    ('مترجم',                          'Interpreter',                 330),
    -- الشؤون الطبية
    ('طبيب',                           'Doctor',                      340),
    ('ممرض',                           'Nurse',                       350),
    -- الإرشاد الديني
    ('مرشد ديني',                      'Religious Guide',             360),
    -- الأمن والسلامة
    ('مسؤول أمن وسلامة',               'Security & Safety Officer',   370),
    ('حارس أمن',                       'Security Guard',              380)
)
insert into reference_items (set_id, name_ar, name_en, sort_order, is_active)
select target.id, wanted.name_ar, wanted.name_en, wanted.sort_order, true
  from wanted, target
on conflict (
  set_id,
  name_ar,
  (coalesce(season_id, '00000000-0000-0000-0000-000000000000'::uuid)),
  (coalesce(variant, ''))
)
do update set
  name_en    = excluded.name_en,
  sort_order = excluded.sort_order,
  is_active  = true;

-- Whatever the office list above did not ask for is retired, not deleted.
update reference_items
   set is_active = false
  from reference_sets rs
 where rs.id = reference_items.set_id
   and rs.code = 'job_titles'
   and reference_items.name_ar not in (
     'مدير عام','مدير إدارة','نائب مدير','مدير مكتب','رئيس قسم','مساعد إداري',
     'أمين سر','محاسب','محاسب أول','أمين صندوق','مدقق حسابات',
     'مسؤول موارد بشرية','أخصائي توظيف',
     'مهندس معلوماتية','مطور نظم','مسؤول شبكات','فني دعم تقني',
     'مسؤول لوجستي','مسؤول مخازن','سائق','مسؤول صيانة','عامل خدمات عامة',
     'مستشار قانوني','مسؤول إعلام وعلاقات عامة','مصمم جرافيك',
     'أمين أرشيف ووثائق','مدخل بيانات',
     'مسؤول تخطيط ومتابعة','مسؤول جودة','مسؤول مشتريات وتموين',
     'موظف خدمة جمهور','موظف استقبال','مترجم','طبيب','ممرض','مرشد ديني',
     'مسؤول أمن وسلامة','حارس أمن'
   );
