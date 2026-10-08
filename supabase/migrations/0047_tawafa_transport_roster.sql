-- الطوافة والنقل, reshaped into the roster every other file uses.
--
-- It was the second file written (0027), before the shape settled. Its people
-- were divided into two TEAMS — عضو فريق الطوافة and عضو فريق النقل — and each
-- team owned its own list of duties. Every file written since (0028 onward)
-- landed somewhere else and stayed there: one مشرف and as many أعضاء as the
-- work needs, with the duties belonging to the FILE and grouped by the area of
-- work they fall in, each member handed his share.
--
-- The two-team split was never about who reports to whom — it was about which
-- work a duty belongs to. That distinction is worth keeping, and it survives
-- here as the two groups; what goes is the idea that a person IS a team. A
-- member can now be handed duties from both, which is what actually happens on
-- the ground when a man doing the buses also walks a tower.
--
-- The thirteen duties are not rewritten. The same rows are re-pointed — from
-- the role that owned them to the file — so the ids survive and anything
-- already handed out stays handed out.

-- ------------------------------------------------------------------ the groups

insert into module_type_task_groups
  (module_type_id, code, name_ar, name_en, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.sort_order
from (values
  ('tawafa',    'أعمال الطوافة', 'Tawafa work',    1),
  ('transport', 'أعمال النقل',   'Transport work', 2)
) as v(code, name_ar, name_en, sort_order)
cross join module_types mt
where mt.code = 'makkah_tawafa_transport'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------------------- the roles

insert into module_type_roles
  (module_type_id, code, name_ar, name_en, description_ar, description_en,
   allows_multiple, is_required, tasks_are_assigned, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.description_ar, v.description_en,
       v.allows_multiple, false, true, v.sort_order
from (values
  (
    'supervisor',
    'مشرف',
    'Supervisor',
    'الإشراف على أعمال الطوافة والنقل في مكة المكرمة، وتوزيع المهام على أعضاء '
    'الفريق ومتابعة تنفيذها، والتنسيق مع المطوف ولجان التكتلات وشركة النقل.',
    'Oversees the Tawafa and transport work in Makkah: hands the duties out to '
    'the members and follows them through, and coordinates with the mutawwif, '
    'the cluster committees and the bus company.',
    false,
    1
  ),
  (
    'member',
    'عضو',
    'Member',
    'يتولى ما يُسند إليه من مهام الطوافة والنقل، ميدانياً ومع الجهات المعنية، '
    'حتى ترحيل آخر حاج إلى المدينة المنورة.',
    'Carries whatever Tawafa and transport duties are handed to him, on the '
    'ground and with the parties concerned, through to the last pilgrim leaving '
    'for Madinah.',
    true,
    2
  )
) as v(code, name_ar, name_en, description_ar, description_en,
       allows_multiple, sort_order)
cross join module_types mt
where mt.code = 'makkah_tawafa_transport'
on conflict (module_type_id, code) do nothing;

-- ------------------------------------------------------- the duties change hands
--
-- Re-pointed, not rewritten: `role_id` goes null and `module_type_id` takes its
-- place, which the table's own check constraint requires to happen in one
-- statement. Whichever team owned a duty decides the group it lands in.

update module_type_tasks t
   set role_id = null,
       module_type_id = mt.id,
       group_id = g.id
  from module_type_roles r
  join module_types mt on mt.id = r.module_type_id
  join module_type_task_groups g
    on g.module_type_id = mt.id
   and g.code = case r.code
                  when 'tawafa_member'    then 'tawafa'
                  when 'transport_member' then 'transport'
                end
 where t.role_id = r.id
   and mt.code = 'makkah_tawafa_transport'
   and r.code in ('tawafa_member', 'transport_member');

-- ------------------------------------------------------------- the people follow
--
-- Nobody is dropped from a file over a change to its catalog. Everyone on
-- either team becomes an عضو, and whoever runs the file promotes one of them to
-- مشرف — a choice that belongs to a person, not to a migration.

-- A man on BOTH teams would become the same member twice, which the uniqueness
-- of (module, role, person) forbids. His duties are gathered onto the row that
-- survives before the other is dropped, so nothing he was handed is lost.
with duplicates as (
  select m.id,
         first_value(m.id) over (
           partition by m.module_id, m.profile_id order by m.created_at, m.id
         ) as keep_id
    from module_members m
    join module_type_roles r on r.id = m.role_id
    join module_types mt on mt.id = r.module_type_id
   where mt.code = 'makkah_tawafa_transport'
     and r.code in ('tawafa_member', 'transport_member')
)
update module_assigned_tasks a
   set member_id = d.keep_id
  from duplicates d
 where a.member_id = d.id
   and d.id <> d.keep_id
   -- Unless that duty is already on the surviving row, in which case the copy
   -- simply goes with the row it was on.
   and not exists (
     select 1 from module_assigned_tasks b
      where b.member_id = d.keep_id and b.task_id = a.task_id
   );

delete from module_members m
 using (
   select m2.id,
          first_value(m2.id) over (
            partition by m2.module_id, m2.profile_id order by m2.created_at, m2.id
          ) as keep_id
     from module_members m2
     join module_type_roles r on r.id = m2.role_id
     join module_types mt on mt.id = r.module_type_id
    where mt.code = 'makkah_tawafa_transport'
      and r.code in ('tawafa_member', 'transport_member')
 ) d
 where m.id = d.id and d.id <> d.keep_id;

update module_members m
   set role_id = newr.id
  from module_type_roles oldr
  join module_types mt on mt.id = oldr.module_type_id
  join module_type_roles newr
    on newr.module_type_id = mt.id and newr.code = 'member'
 where m.role_id = oldr.id
   and mt.code = 'makkah_tawafa_transport'
   and oldr.code in ('tawafa_member', 'transport_member');

-- ------------------------------------------------------------- the teams go
--
-- Safe to drop only now: the duties no longer point at these roles and neither
-- does anybody's membership, so the cascade has nothing left to take with it.

delete from module_type_roles r
 using module_types mt
 where r.module_type_id = mt.id
   and mt.code = 'makkah_tawafa_transport'
   and r.code in ('tawafa_member', 'transport_member');

-- ------------------------------------------------- the type says so out loud

update module_types set
  description_ar =
    'ملف تشغيلي لأعمال الطوافة مع المطوف ومندوبيه، وأعمال النقل مع لجان '
    'التكتلات وشركة النقل. يُختار أعضاؤه فرداً فرداً، وتُسند إلى كل منهم مهامه '
    'من أعمال الطوافة أو النقل أو منهما معاً.',
  description_en =
    'The Tawafa work with the mutawwif and his delegates, and the transport '
    'work with the cluster committees and the bus company. Members are picked '
    'one by one and handed their duties from either area of the work, or both.'
where code = 'makkah_tawafa_transport';
