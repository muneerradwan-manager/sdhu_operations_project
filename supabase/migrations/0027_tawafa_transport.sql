-- The second operational file: الطوافة والنقل في مكة المكرمة.
--
-- It is a different SHAPE of file from the first, and that is the point of the
-- exercise. "قطاعات وأبراج" is a tree: the file is divided into sectors, the
-- sectors into towers, and a person is placed at one of those places. This file
-- has no tree at all. People are picked for it one by one, each is put on one of
-- the two teams — الطوافة or النقل — and each is then handed the duties that are
-- actually his. He may be handed none: being on the team is itself the posting.
--
-- Which is a duty that this catalog could not yet express. `module_type_role_tasks`
-- has always been a STANDING list: define it once on the role and every holder of
-- that role carries all of it, in every file of that type. Here the same list is a
-- MENU — thirteen duties from the Administration, six of الطوافة and seven of
-- النقل — and each member is given a subset of the one his team owns.
--
-- So the role now says which of the two its list is (`tasks_are_assigned`), and
-- what was handed to a particular person is recorded per membership
-- (`module_assigned_tasks`). No level, no node, no new screen for the tree that
-- does not exist here: the file is its roster.

-- ------------------------------------------------------- a task that is handed out

-- False — the meaning every existing role has — is the standing list: the role's
-- duties are the same for everyone holding it. True makes the list a menu, from
-- which each holder is given his own share, possibly nothing.
alter table module_type_roles
  add column if not exists tasks_are_assigned boolean not null default false;

-- One duty, handed to one person, in one file. It hangs off the MEMBERSHIP rather
-- than the person: the same employee may serve in two files, and dropping him from
-- one must take his duties there with him and leave the others standing.
--
-- Both kinds of membership are catered for. This file assigns on the file itself,
-- but nothing about the idea is flat — a tower supervisor could be handed three of
-- his level's duties the same way — so the tree is not shut out of it.
create table if not exists module_assigned_tasks (
  id uuid primary key default gen_random_uuid(),
  member_id uuid references module_members (id) on delete cascade,
  node_member_id uuid references module_node_members (id) on delete cascade,
  task_id uuid not null references module_type_role_tasks (id) on delete cascade,
  assigned_by uuid references profiles (id),
  created_at timestamptz not null default now(),
  constraint assigned_task_has_one_membership
    check (num_nonnulls(member_id, node_member_id) = 1)
);

-- A duty is handed to someone once. Partial indexes: a row fills in exactly one
-- of the two membership columns, and a null never collides in a plain unique.
create unique index if not exists uq_assigned_task_member
  on module_assigned_tasks (member_id, task_id)
  where member_id is not null;

create unique index if not exists uq_assigned_task_node_member
  on module_assigned_tasks (node_member_id, task_id)
  where node_member_id is not null;

create index if not exists idx_assigned_tasks_task
  on module_assigned_tasks (task_id);

alter table module_assigned_tasks enable row level security;

-- A handed-out duty is visible exactly when the membership it hangs off is: that
-- row's own policy is the single source of truth, so this one defers to it rather
-- than restating who may see what.
drop policy if exists module_assigned_tasks_select on module_assigned_tasks;
create policy module_assigned_tasks_select on module_assigned_tasks for select
  using (
    exists (
      select 1 from module_members m
       where m.id = module_assigned_tasks.member_id
    )
    or exists (
      select 1 from module_node_members m
       where m.id = module_assigned_tasks.node_member_id
    )
  );

-- Handing out duties is assigning, and goes with the permission to assign.
drop policy if exists module_assigned_tasks_write on module_assigned_tasks;
create policy module_assigned_tasks_write on module_assigned_tasks for all
  using (is_admin() or has_permission('modules.members') or has_permission('modules.manage'))
  with check (is_admin() or has_permission('modules.members') or has_permission('modules.manage'));

-- ---------------------------------------------------------------- seed: the type

insert into module_types
  (code, name_ar, name_en, description_ar, description_en,
   end_condition_ar, end_condition_en, sort_order)
values (
  'makkah_tawafa_transport',
  'الطوافة والنقل في مكة المكرمة',
  'Tawafa & Transport in Makkah',
  'ملف تشغيلي لأعمال الطوافة مع المطوف ومندوبيه، وأعمال النقل مع لجان التكتلات '
  'وشركة النقل. يُختار أعضاؤه فرداً فرداً، ويوضع كل منهم في أحد الفريقين، '
  'وتُسند إليه مهامه منه.',
  'The Tawafa work with the mutawwif and his delegates, and the transport work '
  'with the cluster committees and the bus company. Members are picked one by '
  'one, placed on one of the two teams, and handed their duties from it.',
  'ينتهي العمل بانتهاء كافة عمليات التفويج والترحيل إلى المدينة المنورة والمطار، '
  'وفق الدليل التشغيلي لبعثة الحج السورية',
  'Ends when every grouping and departure movement to Madinah and the airport is '
  'complete, per the Syrian Hajj Mission operational guide',
  2
)
on conflict (code) do nothing;

-- The official decision that opened the file. The same attachment the first type
-- carries, and the only thing this file holds beyond its roster.
insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select mt.id, 'official_pdf', 'الملف الرسمي (PDF)', 'Official PDF',
       'pdf'::module_field_kind, false, 1
from module_types mt
where mt.code = 'makkah_tawafa_transport'
on conflict (module_type_id, key) do nothing;

-- Two roles, no level: this file has no tree, so its people sit on the file
-- itself. Both hold many, neither is required — a file may be opened with one
-- team staffed and the other still being chosen.
insert into module_type_roles
  (module_type_id, code, name_ar, name_en, description_ar, description_en,
   allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.description_ar, v.description_en,
       true, false, true, v.sort_order
from (values
  (
    'tawafa_member',
    'عضو فريق الطوافة',
    'Tawafa team member',
    'متابعة أعمال الطوافة مع المطوف ومندوبيه: جاهزية الأبراج وخدماتها في مرحلة '
    'التجهيز، وجوازات الحجاج وحقائبهم وملصقات المشاعر، ومعالجة الإشكالات '
    'الطارئة، حتى تفويج آخر حاج إلى المدينة المنورة.',
    'Follows the Tawafa work with the mutawwif and his delegates: tower and '
    'service readiness during preparation, the pilgrims'' passports, luggage and '
    'Mashaaer stickers, and urgent incidents — through to the last pilgrim '
    'leaving for Madinah.',
    1
  ),
  (
    'transport_member',
    'عضو فريق النقل',
    'Transport team member',
    'متابعة أعمال النقل مع لجان التكتلات وشركة النقل: تسليم الحافلات بمحاضر '
    'رسمية، والتحقق من جاهزيتها الفنية ومن سائقيها، ومعالجة أعطالها وإيجاد '
    'البدائل، ورفع التقارير اليومية لمدير الفريق ولإدارة العمليات.',
    'Follows the transport work with the cluster committees and the bus company: '
    'handing over buses under formal receipts, verifying their technical '
    'readiness and their drivers, handling breakdowns and finding replacements, '
    'and filing the daily reports to the team manager and operations.',
    2
  )
) as v(code, name_ar, name_en, description_ar, description_en, sort_order)
cross join module_types mt
where mt.code = 'makkah_tawafa_transport'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------- seed: the duties
--
-- The thirteen from the Administration, verbatim. Not a starting point to be
-- edited like the placeholders 0017 shipped — this is the text itself, and it is
-- the menu each member is handed his share of.

insert into module_type_role_tasks (role_id, title_ar, title_en, sort_order)
select r.id, v.title_ar, v.title_en, v.sort_order
from (values
  (
    'tawafa_member',
    'المتابعة الميدانية لجاهزية الأبراج والخدمات فيها مع المطوف خلال مرحلة التجهيز',
    'Field follow-up, with the mutawwif, on tower and service readiness during preparation',
    1
  ),
  (
    'tawafa_member',
    'التواصل والتنسيق المباشر مع مندوبي المطوفين في حالات الإشكالات الطارئة',
    'Direct contact and coordination with the mutawwif delegates on urgent incidents',
    2
  ),
  (
    'tawafa_member',
    'الإشراف على استلام وتسليم جوازات سفر الحجاج من قبل المطوف عند الوصول',
    'Overseeing the mutawwif taking in and handing back pilgrim passports on arrival',
    3
  ),
  (
    'tawafa_member',
    'تنسيق استلام التكتلات للحقائب القادمة من المطار عبر غرفة العمليات المشتركة لمنع الضياع',
    'Coordinating the clusters receiving luggage from the airport through the joint operations room, so none is lost',
    4
  ),
  (
    'tawafa_member',
    'استلام وتوزيع الملصقات الخاصة بالمشاعر من مندوبي المطوف',
    'Collecting the Mashaaer stickers from the mutawwif delegates and distributing them',
    5
  ),
  (
    'tawafa_member',
    'متابعة تفويج الحجاج للمدينة المنورة حتى مغادرة آخر حاج',
    'Following the grouping of pilgrims to Madinah until the last one has left',
    6
  ),
  (
    'transport_member',
    'تسليم الحافلات للجان الإركاب في التكتلات بمحاضر استلام رسمية بإشراف مدير الفريق',
    'Handing buses to the boarding committees in the clusters under formal receipts, supervised by the team manager',
    1
  ),
  (
    'transport_member',
    'مراقبة مندوبي لجان النقل في التكتلات التي تعمل على تفقد حافلات المشاعر والتأكد من جاهزيتها الفنية قبل استلامها رسمياً',
    'Overseeing the cluster transport delegates as they inspect the Mashaaer buses and confirm their technical readiness before formal handover',
    2
  ),
  (
    'transport_member',
    'التأكد من مندوبي التكتلات للتعرف على سائقي الحافلات وأخذ المعلومات الخاصة لضمان عدم هروبهم',
    'Making sure the cluster delegates identify the bus drivers and take their details, so none absconds',
    3
  ),
  (
    'transport_member',
    'متابعة المشاكل الفنية للحافلات (تعطل، ضياع) والعمل على إيجاد البدائل الفورية بالتنسيق مع شركة النقل',
    'Following bus faults (breakdown, going missing) and finding immediate replacements with the bus company',
    4
  ),
  (
    'transport_member',
    'التأكد ميدانياً من وجود مقاعد مخصصة للبعثات ضمن حافلات المجموعات',
    'Confirming on the ground that seats are reserved for the mission inside the group buses',
    5
  ),
  (
    'transport_member',
    'رفع تقارير يومية شاملة عن سير العمليات لمدير الفريق',
    'Filing full daily reports on the operations to the team manager',
    6
  ),
  (
    'transport_member',
    'إعلام إدارة العمليات بكافة المستجدات الميدانية أولاً بأول',
    'Keeping the operations administration informed of every field development as it happens',
    7
  )
) as v(role_code, title_ar, title_en, sort_order)
join module_types mt on mt.code = 'makkah_tawafa_transport'
join module_type_roles r on r.module_type_id = mt.id and r.code = v.role_code
where not exists (
  select 1 from module_type_role_tasks t
  where t.role_id = r.id and t.title_ar = v.title_ar
);
