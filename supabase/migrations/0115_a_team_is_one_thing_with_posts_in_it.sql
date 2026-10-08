-- فريق الكوسترات is one team, not three headings.
--
-- The roles held on the file itself — the ones with no `level_id` — have been a
-- flat list since 0017, and the file page draws one folding card per role. For
-- a قطاع that is right: a قطاع IS a thing, it has a name, and everyone under it
-- belongs to it. For تشكيل فرق المشاعر it produced this:
--
--     ▸ مدير فريق الكوسترات        (1)
--     ▸ معاون مدير فريق الكوسترات  (1)
--     ▸ عضو فريق الكوسترات         (14)
--     ▸ عضو فريق مراقبة إعاشة المشاعر (6)
--
-- Four headings for two teams. The manager, his deputy and the members are one
-- team with three posts in it, and the page said they were three separate
-- groups of people who happen to have similar names.
--
-- ------------------------------------------------------------ why not derive it
--
-- The codes share a prefix — `coasters_manager`, `coasters_deputy`,
-- `coasters_member` — and grouping on it would work today and be wrong the
-- first time somebody adds a role whose name merely starts the same way. The
-- same argument 0089 made for `is_place`: every way of working it out is wrong
-- somewhere, so it is STATED. A type declares its teams and each role names the
-- one it is in; a role that names none is a group of one and the page is
-- exactly what it was.
--
-- Nothing here is a rule about the tree. Roles held on a level already group
-- under the قطاع or the برج they are held at — that is what `level_id` does —
-- and this only concerns the roles held once for the whole file.

create table if not exists module_type_teams (
  id             uuid primary key default gen_random_uuid(),
  module_type_id uuid not null references module_types (id) on delete cascade,

  -- Stable across seasons and across types: `coasters` is the same idea in
  -- مخيمات منى and in تشكيل فرق المشاعر even though the posts differ.
  code           text not null,

  name_ar        text not null,
  name_en        text,

  unique (module_type_id, code)
);

comment on table module_type_teams is
  'A named group of the roles a type holds on the FILE itself — فريق الكوسترات '
  'and its manager, deputy and members. Deliberately carries no sort_order: '
  'the order teams appear in is the order their roles do, so there is no '
  'second ordering to disagree with module_type_roles.sort_order.';

alter table module_type_teams enable row level security;

-- Catalog, and read like the rest of it (0024). Written under reference.edit,
-- which is where 0073 put every table of the type catalog.
drop policy if exists module_type_teams_select on module_type_teams;
create policy module_type_teams_select on module_type_teams for select
  using (is_admin() or is_approved());

drop policy if exists module_type_teams_write on module_type_teams;
create policy module_type_teams_write on module_type_teams for all
  using (is_admin() or has_permission('reference.edit'))
  with check (is_admin() or has_permission('reference.edit'));

alter table module_type_roles
  add column if not exists team_id uuid
    references module_type_teams (id) on delete set null;

comment on column module_type_roles.team_id is
  'The team this post belongs to, for a role held on the file itself. Null is '
  'the ordinary case and means the post stands alone. Ignored for a role that '
  'names a level_id: such a role already groups under its node.';

create index if not exists idx_module_type_roles_team
  on module_type_roles (team_id) where team_id is not null;

-- ==================================================== the two types that have them

-- تشكيل فرق المشاعر: قطاعات on the tree, and TWO teams on the file — the
-- coasters, who move between every sector, and the catering monitors, who watch
-- the المشاعر as one. 0048 put all four roles side by side because there was
-- nowhere to say they were two groups.
insert into module_type_teams (module_type_id, code, name_ar, name_en)
select mt.id, v.code, v.name_ar, v.name_en
from (values
  ('coasters',          'فريق الكوسترات',              'Coasters team'),
  ('mashaaer_catering', 'فريق مراقبة إعاشة المشاعر',   'Mashaaer catering monitors')
) as v(code, name_ar, name_en)
cross join module_types mt
where mt.code = 'mashaaer_teams'
on conflict (module_type_id, code) do nothing;

-- مخيمات منى: مراكز and مخيمات on the tree, and the one coasters team on the
-- file — the buses move between all the centres, so they belong to none.
insert into module_type_teams (module_type_id, code, name_ar, name_en)
select mt.id, 'coasters', 'فريق الكوسترات', 'Coasters team'
from module_types mt
where mt.code = 'mina_camp_assignment'
on conflict (module_type_id, code) do nothing;

-- The posts, into the teams. Matched by role code within the same type, and
-- only where the role is held on the FILE — a role that names a level is
-- grouped by its node and must not be pulled out of it.
update module_type_roles r
   set team_id = t.id
  from module_type_teams t, module_types mt
 where t.module_type_id = mt.id
   and r.module_type_id = mt.id
   and r.level_id is null
   and (
     (mt.code = 'mashaaer_teams' and t.code = 'coasters'
      and r.code in ('coasters_manager', 'coasters_deputy', 'coasters_member'))
     or
     (mt.code = 'mashaaer_teams' and t.code = 'mashaaer_catering'
      and r.code in ('catering_monitor'))
     or
     (mt.code = 'mina_camp_assignment' and t.code = 'coasters'
      and r.code in ('coasters_supervisor', 'coasters_member'))
   );

-- Every other type is untouched, and that is the point. Ten of the fifteen have
-- no tree at all and their file-level roles ARE the whole file — الطوافة والنقل
-- is two posts and nothing else. Wrapping those in a team card would add a
-- frame that says nothing the page does not already say. A team is declared
-- where a team exists.
