-- The eleventh operational file: تشكيل فرق المشاعر.
--
-- The second file in the whole catalog with a TREE. Every file since 0028 has
-- been a roster — مشرف وعدة أعضاء on the file itself — and قطاعات وأبراج (0024)
-- has been the only one divided into places. This one is divided the same way,
-- and into THE SAME places: its قطاعات are the قطاعات of the towers file, the
-- same name and the same مشرف and the same معاون. 0049 is what lets one file
-- take them from the other.
--
-- But it stops at the sector. The towers file goes on to divide a sector into
-- its hotels; here the sector is the whole of the tree, and inside it are three
-- teams — التروية, عرفات, منى أيام التشريق — which are not places at all. A team
-- has no name of its own to enter and nobody running it: it is the capacity a
-- man serves in during those days, and one man may serve in all three. So the
-- teams are ROLES on the sector rather than a level below it. A place you can
-- point at gets a node; a capacity gets a role.
--
-- And two teams belong to no sector: الكوسترات, which moves between all of them,
-- and مراقبة إعاشة المشاعر. Those sit on the file itself — which makes this the
-- first type to carry both shapes at once, sectors AND a file-level roster. The
-- editor has to learn that; the schema already knew it (0024 wrote `level_id`
-- nullable for exactly this reason).
--
-- No duties are seeded. The Administration has not written them for this file
-- yet, and inventing them here would put words in their mouth. Each role
-- carries its job description instead, which is what the post IS, and the app
-- says nothing further rather than apologising for a list that does not exist.
--
-- Hence `tasks_are_assigned = false` on all nine, against the habit of every
-- file since 0028. That flag means "the duties of this post are handed out one
-- by one", and with it set the detail screen tells every member "لم تُسند إليك
-- مهام بعد" — which claims there is a menu he was given none of. There is no
-- menu. The day the Administration writes one, the migration that inserts it
-- flips the flag in the same breath.

-- ---------------------------------------------------------------- seed: the type

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   start_condition_ar, start_condition_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'mashaaer_teams',
  'تشكيل فرق المشاعر (منى يوم التروية، عرفات، منى أيام التشريق)',
  'Mashaaer Teams (Mina on Tarwiyah, Arafat, Mina on the days of Tashreeq)',
  'ملف تشغيلي لتشكيل الفرق العاملة في المشاعر المقدسة: يُقسم إلى قطاعات، لكل '
  'قطاع مشرفه ومعاونه وثلاثة فرق — التروية وعرفات ومنى أيام التشريق — ومعه فريق '
  'الكوسترات وفريق مراقبة إعاشة المشاعر على مستوى الملف.',
  'The teams working in the holy sites: divided into sectors, each with its '
  'supervisor, his deputy and three teams — Tarwiyah, Arafat and Mina on the '
  'days of Tashreeq — alongside the coasters team and the Mashaaer catering '
  'monitors, who serve the file as a whole.',
  'يبدأ العمل بتشكيل الفرق قبل التوجه إلى منى يوم التروية',
  'Begins when the teams are formed, before the move to Mina on the day of Tarwiyah',
  'ينتهي العمل بعودة آخر حاج من منى بعد أيام التشريق',
  'Ends when the last pilgrim returns from Mina after the days of Tashreeq',
  11
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'mashaaer_teams'
on conflict (module_type_id, key) do nothing;

-- --------------------------------------------------------------- seed: the tree
--
-- One level and no more. `reference_set_id` null is what makes a sector named by
-- hand — it exists inside this file only, exactly as it does in the towers file,
-- and is not drawn from any master list.

insert into module_type_levels
  (module_type_id, code, name_ar, name_en, depth, reference_set_id)
select mt.id, 'sector', 'القطاع', 'Sector', 1, null
from module_types mt
where mt.code = 'mashaaer_teams'
on conflict (module_type_id, code) do nothing;

-- -------------------------------------------------------------- seed: the roles
--
-- The first five are held per قطاع. The codes of the first two are deliberately
-- the SAME codes the towers file uses (`sector_supervisor`, `sector_deputy`):
-- `module_type_roles` is unique per (type, code), so a code may repeat across
-- types, and 0049 maps a role from one file to the other by matching it. Two
-- posts that are the same post should answer to the same name.

insert into module_type_roles
  (module_type_id, code, name_ar, name_en, description_ar, description_en,
   level_id, allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.description_ar, v.description_en,
       lv.id, v.allows_multiple, v.is_required, false, v.sort_order
from (values
  (
    'sector_supervisor',
    'مشرف القطاع',
    'Sector supervisor',
    'الإشراف على فرق القطاع في المشاعر المقدسة، وتوزيع أعضائه على فرق التروية '
    'وعرفات ومنى أيام التشريق، ومتابعة عملهم حتى عودة آخر حاج.',
    'Oversees the sector''s teams in the holy sites, places its members on the '
    'Tarwiyah, Arafat and Tashreeq teams, and follows their work through to the '
    'last pilgrim''s return.',
    false, true, 1
  ),
  (
    'sector_deputy',
    'معاون مشرف القطاع',
    'Sector deputy',
    'يعاون مشرف القطاع في متابعة فرقه، وينوب عنه عند غيابه.',
    'Assists the sector supervisor in following his teams, and stands in for him '
    'in his absence.',
    false, false, 2
  ),
  (
    'tarwiyah_member',
    'عضو فريق التروية',
    'Tarwiyah team member',
    'العمل مع حجاج القطاع في منى يوم التروية.',
    'Serves the sector''s pilgrims in Mina on the day of Tarwiyah.',
    true, false, 3
  ),
  (
    'arafat_member',
    'عضو فريق عرفات',
    'Arafat team member',
    'العمل مع حجاج القطاع في عرفات يوم الوقوف.',
    'Serves the sector''s pilgrims at Arafat on the day of standing.',
    true, false, 4
  ),
  (
    'tashreeq_member',
    'عضو فريق منى أيام التشريق',
    'Mina (Tashreeq) team member',
    'العمل مع حجاج القطاع في منى أيام التشريق حتى النفير.',
    'Serves the sector''s pilgrims in Mina through the days of Tashreeq, until '
    'the departure.',
    true, false, 5
  )
) as v(code, name_ar, name_en, description_ar, description_en,
       allows_multiple, is_required, sort_order)
cross join module_types mt
join module_type_levels lv
  on lv.module_type_id = mt.id and lv.code = 'sector'
where mt.code = 'mashaaer_teams'
on conflict (module_type_id, code) do nothing;

-- The two teams that belong to no قطاع. `level_id` null is the convention 0024
-- set for a role held once for the whole file — الكوسترات move between every
-- sector, and the إعاشة monitors watch the المشاعر as one.

insert into module_type_roles
  (module_type_id, code, name_ar, name_en, description_ar, description_en,
   level_id, allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.description_ar, v.description_en,
       null, v.allows_multiple, false, false, v.sort_order
from (values
  (
    'coasters_manager',
    'مدير فريق الكوسترات',
    'Coasters team manager',
    'إدارة فريق الكوسترات في المشاعر: توزيع الحافلات على القطاعات ومتابعة '
    'حركتها بين منى وعرفات، ومعالجة ما يطرأ عليها.',
    'Runs the coasters team in the holy sites: allotting the buses to the '
    'sectors, following their movement between Mina and Arafat, and handling '
    'whatever befalls them.',
    false, 6
  ),
  (
    'coasters_deputy',
    'معاون مدير فريق الكوسترات',
    'Deputy coasters team manager',
    'يعاون مدير فريق الكوسترات وينوب عنه عند غيابه.',
    'Assists the coasters team manager and stands in for him in his absence.',
    false, 7
  ),
  (
    'coasters_member',
    'عضو فريق الكوسترات',
    'Coasters team member',
    'متابعة حافلات الكوسترات ميدانياً في المشاعر ونقل الحجاج بين مواقعها.',
    'Follows the coaster buses on the ground in the holy sites and moves the '
    'pilgrims between their places.',
    true, 8
  ),
  (
    'catering_monitor',
    'عضو فريق مراقبة إعاشة المشاعر',
    'Mashaaer catering monitor',
    'مراقبة إعاشة الحجاج في المشاعر المقدسة: وصول الوجبات ومواعيدها وسلامتها، '
    'ورفع ما يخالف ذلك.',
    'Watches the pilgrims'' catering in the holy sites — that the meals arrive, '
    'on time and sound — and reports whatever falls short.',
    true, 9
  )
) as v(code, name_ar, name_en, description_ar, description_en,
       allows_multiple, sort_order)
cross join module_types mt
where mt.code = 'mashaaer_teams'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------- معاون, in both files
--
-- 0024 renamed معاون مشرف القطاع to نائب مشرف القطاع and let a sector hold
-- several. The Administration says معاون, and says one — so both files say it
-- now, and the post means the same thing in each, which is also what lets 0049
-- carry it across.
--
-- Nobody is removed. `allows_multiple` is a rule the picker keeps, not one the
-- database enforces, and no sector today holds a second deputy; if one ever
-- did, both holders stay standing and the next edit settles it. A migration
-- does not delete people.

update module_type_roles r
   set name_ar = 'معاون مشرف القطاع',
       name_en = 'Sector deputy',
       allows_multiple = false
  from module_types mt
 where mt.id = r.module_type_id
   and mt.code = 'makkah_sectors_towers'
   and r.code = 'sector_deputy';
