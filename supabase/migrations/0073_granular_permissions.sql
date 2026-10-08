-- Granular permissions: one permission per action, and the dependencies between
-- them made real.
--
-- "Manage seasons" said nothing. Whoever read a grant sheet had to know that it
-- meant exactly one button (set as current), and whoever granted it could not
-- give the button without the word "manage". Every coarse code is split into
-- the actions the app actually offers:
--
--   seasons.manage        -> seasons.view + seasons.switch
--   seasons.participants  -> seasons.view + participants_view + participants_manage
--   modules.manage        -> view_all + create + edit + delete + activate (+ members, reports)
--   modules.types         -> reference.view + edit + delete + import  (a new section:
--                            the code never managed types, it managed master data)
--   reports.manage        -> view_all + create + edit + delete + publish
--   notifications.send    -> send (one person) + broadcast_module + broadcast_all
--   approvals.decide      -> approvals.view + approvals.decide
--   permissions.manage    -> permissions.view + permissions.manage
--
-- And the dependencies become rows: `permission_prerequisites` says that
-- assigning module members REQUIRES seeing employees, that deciding requests
-- REQUIRES seeing the queue. The database enforces it both ways — a grant
-- without its prerequisite is refused, and revoking a prerequisite takes its
-- dependents with it — so a grant sheet can never describe a person who cannot
-- actually do the thing.
--
-- Parent sections stop being grantable. They were a second way of saying "may
-- enter the section" beside the `.view` action that already says it; from here
-- they are headings, and the `.view` action is the door.
--
-- This migration also wires up permissions that never worked:
--   * approvals.decide could not approve  (guard trigger reverted account_status)
--   * employees.suspend could not suspend (same trigger)
--   * employees.external could not flag   (same trigger)
--   * seasons.participants could not write the roster (policy was admin-only)
--   * the permissions catalog was unreadable to a non-admin permission manager
--     (0063 fixed the grants table but not the catalog)
--   * dashboard/apex checks now name the new codes.

-- ================================================================ 1. catalog

-- The new section, between modules and reports.
insert into permissions (code, description, sort_order)
values ('reference', 'Master data section', 5)
on conflict (code) do nothing;

-- Section order: employees, approvals, seasons, modules, reference, reports,
-- notifications, permissions.
update permissions set sort_order = v.sort_order, description = v.description
from (values
  ('employees',     'Employees section',        1),
  ('approvals',     'Account approvals section', 2),
  ('seasons',       'Seasons section',           3),
  ('modules',       'Operational files section', 4),
  ('reference',     'Master data section',       5),
  ('reports',       'Reports section',           6),
  ('notifications', 'Notifications section',     7),
  ('permissions',   'Permissions section',       8)
) as v(code, description, sort_order)
where permissions.code = v.code;

-- New actions. Existing fine-grained codes (employees.*, approvals.decide,
-- modules.members, notifications.send, permissions.manage) keep their rows —
-- and therefore their grants — but their meaning is narrowed or re-described.
insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('approvals.view',              'View registration requests',            'approvals',     1),
  ('seasons.view',                'View seasons',                          'seasons',       1),
  ('seasons.switch',              'Set the current season',                'seasons',       2),
  ('seasons.participants_view',   'View season participants',              'seasons',       3),
  ('seasons.participants_manage', 'Add and withdraw season participants',  'seasons',       4),
  ('modules.view_all',            'View all files, including drafts',      'modules',       1),
  ('modules.create',              'Create an operational file',            'modules',       2),
  ('modules.edit',                'Edit a file and its structure',         'modules',       3),
  ('modules.delete',              'Delete an operational file',            'modules',       4),
  ('modules.activate',            'Activate and deactivate files',         'modules',       5),
  ('modules.reports',             'Read members'' file reports',           'modules',       7),
  ('reference.view',              'View master data',                      'reference',     1),
  ('reference.edit',              'Add and edit master data',              'reference',     2),
  ('reference.delete',            'Delete master data',                    'reference',     3),
  ('reference.import',            'Copy master data from another season',  'reference',     4),
  ('reports.view_all',            'View all reports, including drafts',    'reports',       1),
  ('reports.create',              'Create reports',                        'reports',       2),
  ('reports.edit',                'Edit reports',                          'reports',       3),
  ('reports.delete',              'Delete reports',                        'reports',       4),
  ('reports.publish',             'Publish and unpublish reports',         'reports',       5),
  ('notifications.broadcast_module', 'Notify a file''s members',           'notifications', 2),
  ('notifications.broadcast_all',    'Notify everyone',                    'notifications', 3),
  ('permissions.view',            'View granted permissions',              'permissions',   1)
) as v(code, description, parent_code, sort_order)
join permissions p on p.code = v.parent_code
on conflict (code) do nothing;

-- Kept codes: new place in the list, new description where the meaning moved.
update permissions set sort_order = v.sort_order, description = v.description
from (values
  ('employees.view',      'View employees and details',       1),
  ('employees.create',    'Add employees',                    2),
  ('employees.edit',      'Edit employee records',            3),
  ('employees.delete',    'Delete employee records',          4),
  ('employees.suspend',   'Suspend and reactivate accounts',  5),
  ('employees.external',  'Manage external status',           6),
  ('employees.documents', 'View employee documents',          7),
  ('employees.password',  'Reset an employee''s password',    8),
  ('approvals.decide',    'Approve and reject accounts',      2),
  ('modules.members',     'Assign members and duties',        6),
  ('notifications.send',  'Notify an individual employee',    1),
  ('permissions.manage',  'Grant and revoke permissions',     2)
) as v(code, description, sort_order)
where permissions.code = v.code;

-- ====================================================== 2. carrying grants over
--
-- Whoever could do a thing yesterday can do the same thing today, under its new
-- name — including the prerequisites the new rules will demand. A closure is
-- granted rather than assumed: seasons.participants always NEEDED employee
-- visibility to show a name, the schema just never said so.

with mapping (old_code, new_code) as (
  values
    -- prerequisites the old flat grants silently relied on
    ('employees.create',     'employees.view'),
    ('employees.edit',       'employees.view'),
    ('employees.delete',     'employees.view'),
    ('employees.suspend',    'employees.view'),
    ('employees.external',   'employees.view'),
    ('employees.documents',  'employees.view'),
    ('employees.password',   'employees.view'),
    ('approvals.decide',     'approvals.view'),
    -- the seasons parent was the one parent that DID something (the section door)
    ('seasons',              'seasons.view'),
    ('seasons.manage',       'seasons.view'),
    ('seasons.manage',       'seasons.switch'),
    ('seasons.participants', 'seasons.view'),
    ('seasons.participants', 'employees.view'),
    ('seasons.participants', 'seasons.participants_view'),
    ('seasons.participants', 'seasons.participants_manage'),
    ('modules.manage',       'modules.view_all'),
    ('modules.manage',       'modules.create'),
    ('modules.manage',       'modules.edit'),
    ('modules.manage',       'modules.delete'),
    ('modules.manage',       'modules.activate'),
    ('modules.manage',       'modules.members'),
    ('modules.manage',       'modules.reports'),
    ('modules.manage',       'employees.view'),
    ('modules.members',      'modules.view_all'),
    ('modules.members',      'employees.view'),
    ('modules.types',        'reference.view'),
    ('modules.types',        'reference.edit'),
    ('modules.types',        'reference.delete'),
    ('modules.types',        'reference.import'),
    ('reports.manage',       'reports.view_all'),
    ('reports.manage',       'reports.create'),
    ('reports.manage',       'reports.edit'),
    ('reports.manage',       'reports.delete'),
    ('reports.manage',       'reports.publish'),
    ('notifications.send',   'notifications.broadcast_module'),
    ('notifications.send',   'notifications.broadcast_all'),
    ('permissions.manage',   'permissions.view'),
    ('permissions.manage',   'employees.view')
)
insert into user_permissions (user_id, permission_id, granted_by)
select distinct up.user_id, np.id, up.granted_by
from user_permissions up
join permissions op on op.id = up.permission_id
join mapping m on m.old_code = op.code
join permissions np on np.code = m.new_code
on conflict (user_id, permission_id) do nothing;

-- The retired codes go, and their grants go with them (already carried over).
delete from permissions
where code in ('seasons.manage', 'seasons.participants',
               'modules.manage', 'modules.types', 'reports.manage');

-- Parents stop being grants. (Their rows stay — they are the section headings.)
delete from user_permissions up
using permissions p
where p.id = up.permission_id and p.parent_id is null;

-- ============================================================ 3. prerequisites
--
-- What a permission needs before it means anything. Enforced, not documented:
-- the app reads this table to explain itself, and the triggers below make it
-- impossible to hold a permission whose ground was never granted (or was later
-- pulled away).

create table if not exists permission_prerequisites (
  permission_id uuid not null references permissions (id) on delete cascade,
  requires_id   uuid not null references permissions (id) on delete cascade,
  primary key (permission_id, requires_id),
  constraint prerequisite_not_self check (permission_id <> requires_id)
);

alter table permission_prerequisites enable row level security;

drop policy if exists permission_prerequisites_select on permission_prerequisites;
create policy permission_prerequisites_select on permission_prerequisites
  for select using (is_admin() or is_approved());

drop policy if exists permission_prerequisites_write on permission_prerequisites;
create policy permission_prerequisites_write on permission_prerequisites
  for all using (is_admin()) with check (is_admin());

insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from (values
  ('employees.create',            'employees.view'),
  ('employees.edit',              'employees.view'),
  ('employees.delete',            'employees.view'),
  ('employees.suspend',           'employees.view'),
  ('employees.external',          'employees.view'),
  ('employees.documents',         'employees.view'),
  ('employees.password',          'employees.view'),
  ('approvals.decide',            'approvals.view'),
  ('seasons.switch',              'seasons.view'),
  ('seasons.participants_view',   'seasons.view'),
  ('seasons.participants_view',   'employees.view'),
  ('seasons.participants_manage', 'seasons.participants_view'),
  ('modules.create',              'modules.view_all'),
  ('modules.edit',                'modules.view_all'),
  ('modules.delete',              'modules.view_all'),
  ('modules.activate',            'modules.view_all'),
  ('modules.members',             'modules.view_all'),
  ('modules.members',             'employees.view'),
  ('modules.reports',             'modules.view_all'),
  ('reference.edit',              'reference.view'),
  ('reference.delete',            'reference.view'),
  ('reference.import',            'reference.edit'),
  ('reports.create',              'reports.view_all'),
  ('reports.edit',                'reports.view_all'),
  ('reports.delete',              'reports.view_all'),
  ('reports.publish',             'reports.view_all'),
  ('permissions.view',            'employees.view'),
  ('permissions.manage',          'permissions.view')
) as v(code, requires_code)
join permissions c on c.code = v.code
join permissions r on r.code = v.requires_code
on conflict do nothing;

-- A grant may not arrive before its ground.
create or replace function user_permissions_check_prerequisites() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if exists (
    select 1
    from permission_prerequisites pp
    where pp.permission_id = new.permission_id
      and not exists (
        select 1 from user_permissions up
        where up.user_id = new.user_id
          and up.permission_id = pp.requires_id
      )
  ) then
    raise exception 'missing prerequisite';
  end if;
  return new;
end;
$$;

drop trigger if exists user_permissions_prerequisites on user_permissions;
create trigger user_permissions_prerequisites
  before insert on user_permissions
  for each row execute function user_permissions_check_prerequisites();

-- ...and when the ground is pulled, what stood on it falls with it. The delete
-- inside the trigger fires the trigger again, so a whole chain folds in order.
create or replace function user_permissions_cascade_revoke() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  delete from user_permissions up
  using permission_prerequisites pp
  where pp.requires_id = old.permission_id
    and up.user_id = old.user_id
    and up.permission_id = pp.permission_id;
  return old;
end;
$$;

drop trigger if exists user_permissions_cascade on user_permissions;
create trigger user_permissions_cascade
  after delete on user_permissions
  for each row execute function user_permissions_cascade_revoke();

-- =========================================== 4. the permissions tables themselves

-- The catalog: readable by anyone approved. It is labels and structure, not
-- secrets — and the permission editor, the profile card and the prerequisite
-- hints all render from it. (0063 widened the grants table and left the catalog
-- admin-only; a non-admin permission manager saw an empty editor.)
drop policy if exists permissions_admin_only on permissions;
drop policy if exists permissions_select on permissions;
create policy permissions_select on permissions for select
  using (is_admin() or is_approved());

drop policy if exists permissions_write on permissions;
create policy permissions_write on permissions for all
  using (is_admin()) with check (is_admin());

-- Grants: seeing is permissions.view, changing is permissions.manage.
drop policy if exists user_permissions_select on user_permissions;
create policy user_permissions_select on user_permissions for select
  using (user_id = auth.uid() or has_permission('permissions.view'));

drop policy if exists user_permissions_write on user_permissions;
create policy user_permissions_write on user_permissions for all
  using (has_permission('permissions.manage'))
  with check (has_permission('permissions.manage'));

-- ======================================================= 5. profiles: the guard
--
-- The privileged-columns guard learns the new codes. Until now it knew only
-- "admin or not", which made approvals.decide, employees.suspend and
-- employees.external switches wired to nothing: the policy let the UPDATE
-- through and this trigger quietly reverted it.
--
-- The shape now: each privileged column moves only under its own permission,
-- an admin's row moves only under an admin's hand, and a caller who came with
-- a specialist permission (suspend, decide, external) does not get to rewrite
-- the base record on the way through.

create or replace function profiles_guard_privileged_columns() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  caller_is_admin boolean;
  v_status_ok boolean;
begin
  if auth.uid() is null then
    return new;
  end if;

  select p.is_admin and p.account_status = 'approved' and not p.is_suspended
    into caller_is_admin
  from public.profiles p
  where p.id = auth.uid();

  if coalesce(caller_is_admin, false) then
    return new;
  end if;

  -- Adminship is never handed out here.
  new.is_admin := old.is_admin;

  -- account_status: its owner may resubmit; a decider may decide.
  v_status_ok :=
    new.account_status is not distinct from old.account_status
    or (old.id = auth.uid()
        and old.account_status in ('incomplete', 'rejected')
        and new.account_status = 'pending')
    or (not old.is_admin
        and has_permission('approvals.decide')
        and old.account_status in ('pending', 'incomplete', 'rejected')
        and new.account_status in ('approved', 'rejected'));
  if not v_status_ok then
    new.account_status := old.account_status;
  end if;

  if not (not old.is_admin and has_permission('approvals.decide')) then
    new.rejection_reason := old.rejection_reason;
  end if;

  if not (not old.is_admin and has_permission('employees.suspend')) then
    new.is_suspended := old.is_suspended;
  end if;

  if not (not old.is_admin and has_permission('employees.external')) then
    new.is_external := old.is_external;
    new.external_organization := old.external_organization;
    new.external_title := old.external_title;
  end if;

  -- The base record (names, phones, titles…) belongs to its owner and to an
  -- employees.edit holder. Anyone else who reached this UPDATE came for one of
  -- the privileged columns above; everything else returns to what it was.
  if not (old.id = auth.uid() or has_permission('employees.edit')) then
    declare
      v_merged jsonb;
    begin
      v_merged := to_jsonb(old) || jsonb_build_object(
        'is_admin',              to_jsonb(new) -> 'is_admin',
        'account_status',        to_jsonb(new) -> 'account_status',
        'rejection_reason',      to_jsonb(new) -> 'rejection_reason',
        'is_suspended',          to_jsonb(new) -> 'is_suspended',
        'is_external',           to_jsonb(new) -> 'is_external',
        'external_organization', to_jsonb(new) -> 'external_organization',
        'external_title',        to_jsonb(new) -> 'external_title'
      );
      new := jsonb_populate_record(new, v_merged);
    end;
  end if;

  return new;
end;
$$;

-- Who may run an UPDATE at all. The trigger above decides what of it survives.
drop policy if exists profiles_update_self on profiles;
create policy profiles_update_self on profiles for update
  using (
    id = auth.uid()
    or is_admin()
    or has_permission('employees.edit')
    or has_permission('employees.suspend')
    or has_permission('employees.external')
    or has_permission('approvals.decide')
  )
  with check (
    id = auth.uid()
    or is_admin()
    or has_permission('employees.edit')
    or has_permission('employees.suspend')
    or has_permission('employees.external')
    or has_permission('approvals.decide')
  );

-- Reading: the queue is visible to whoever may see requests — but only the
-- accounts that ARE requests. The approved directory stays behind
-- employees.view.
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select
  using (
    id = auth.uid()
    or is_admin()
    or has_permission('employees.view')
    or has_permission('employees.edit')
    or (has_permission('approvals.view')
        and account_status in ('pending', 'incomplete', 'rejected'))
    or shares_a_module_with(id)
  );

-- ================================================================= 6. seasons

-- Switching the season the whole mission works in — the highest-leverage single
-- action in the app — now has its own name.
create or replace function set_current_season(
  p_season_id uuid,
  p_pinned_for_hijri_year int default null
) returns void
  language plpgsql security definer set search_path = public as $$
begin
  if not (is_admin() or has_permission('seasons.switch')) then
    raise exception 'not authorized';
  end if;

  if not exists (select 1 from seasons where id = p_season_id) then
    raise exception 'season not found';
  end if;

  update seasons
     set is_current = false,
         pinned_for_hijri_year = null
   where is_current or pinned_for_hijri_year is not null;

  update seasons
     set is_current = true,
         pinned_for_hijri_year = p_pinned_for_hijri_year
   where id = p_season_id;
end;
$$;

-- The roster: reading and writing were one code, and the write half never
-- worked (the policy said admin). Now they are two codes and both work.
drop policy if exists season_participants_select on season_participants;
create policy season_participants_select on season_participants for select
  using (
    profile_id = auth.uid()
    or has_permission('seasons.participants_view')
  );

drop policy if exists season_participants_write on season_participants;
create policy season_participants_write on season_participants for all
  using (has_permission('seasons.participants_manage'))
  with check (has_permission('seasons.participants_manage'));

-- =========================================================== 7. notifications
--
-- Three blast radii, three permissions: one person, one file, everyone.

drop policy if exists notifications_insert on notifications;
create policy notifications_insert on notifications for insert
  with check (
    is_admin()
    or has_permission('notifications.send')
    or has_permission('notifications.broadcast_module')
    or has_permission('notifications.broadcast_all')
  );

drop policy if exists notification_attachments_write on notification_attachments;
create policy notification_attachments_write on notification_attachments
  for all
  using (
    is_admin()
    or has_permission('notifications.send')
    or has_permission('notifications.broadcast_module')
    or has_permission('notifications.broadcast_all')
  )
  with check (
    is_admin()
    or has_permission('notifications.send')
    or has_permission('notifications.broadcast_module')
    or has_permission('notifications.broadcast_all')
  );

create or replace function can_send_any_notification() returns boolean
  language sql stable security definer set search_path = public as $$
  select is_admin()
      or has_permission('notifications.send')
      or has_permission('notifications.broadcast_module')
      or has_permission('notifications.broadcast_all');
$$;

drop policy if exists notification_files_write on storage.objects;
create policy notification_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'notifications' and public.can_send_any_notification()
  );

drop policy if exists notification_files_update on storage.objects;
create policy notification_files_update on storage.objects for update
  to authenticated using (
    bucket_id = 'notifications' and public.can_send_any_notification()
  );

drop policy if exists notification_files_delete on storage.objects;
create policy notification_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'notifications' and public.can_send_any_notification()
  );

create or replace function broadcast_to_module(
  p_module_id uuid,
  p_title text,
  p_body text default null
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_group uuid := gen_random_uuid();
begin
  if not (is_admin() or has_permission('notifications.broadcast_module')) then
    raise exception 'not authorized';
  end if;

  insert into notifications (recipient_id, sender_id, title, body, group_id, data)
  select distinct p.profile_id, auth.uid(), p_title, p_body, v_group,
         jsonb_build_object('type', 'module_broadcast', 'module_id', p_module_id)
    from (
      select mm.profile_id
        from module_members mm
       where mm.module_id = p_module_id
      union
      select nm.profile_id
        from module_node_members nm
        join module_nodes n on n.id = nm.node_id
       where n.module_id = p_module_id
    ) p;

  return v_group;
end;
$$;

create or replace function broadcast_to_all(
  p_title text,
  p_body text default null,
  p_season_id uuid default null
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_group uuid := gen_random_uuid();
begin
  if not (is_admin() or has_permission('notifications.broadcast_all')) then
    raise exception 'not authorized';
  end if;

  insert into notifications (recipient_id, sender_id, title, body, group_id, data)
  select pr.id, auth.uid(), p_title, p_body, v_group,
         jsonb_build_object('type', 'broadcast')
    from profiles pr
   where pr.account_status = 'approved'
     and not pr.is_suspended
     and (
       p_season_id is null
       or exists (
         select 1 from season_participants sp
          where sp.profile_id = pr.id
            and sp.season_id = p_season_id
            and sp.status = 'active'
       )
     );

  return v_group;
end;
$$;

-- ================================================================= 8. modules

drop policy if exists modules_select on modules;
create policy modules_select on modules for select
  using (
    is_admin()
    or has_permission('modules.view_all')
    or has_permission('modules.members')
    or (is_active and is_module_member(id))
  );

-- The single write policy becomes three verbs...
drop policy if exists modules_write on modules;

drop policy if exists modules_insert on modules;
create policy modules_insert on modules for insert
  with check (is_admin() or has_permission('modules.create'));

drop policy if exists modules_update on modules;
create policy modules_update on modules for update
  using (
    is_admin()
    or has_permission('modules.edit')
    or has_permission('modules.activate')
  )
  with check (
    is_admin()
    or has_permission('modules.edit')
    or has_permission('modules.activate')
  );

drop policy if exists modules_delete on modules;
create policy modules_delete on modules for delete
  using (is_admin() or has_permission('modules.delete'));

-- ...and a guard keeps the two update verbs apart: releasing a file to its
-- members (is_active) is modules.activate, everything else is modules.edit.
create or replace function modules_guard_update() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if is_admin() then
    return new;
  end if;

  if new.is_active is distinct from old.is_active
     and not has_permission('modules.activate') then
    raise exception 'not authorized';
  end if;

  if (to_jsonb(new) - 'is_active' - 'updated_at')
     is distinct from (to_jsonb(old) - 'is_active' - 'updated_at')
     and not has_permission('modules.edit') then
    raise exception 'not authorized';
  end if;

  return new;
end;
$$;

drop trigger if exists modules_guard_update on modules;
create trigger modules_guard_update
  before update on modules
  for each row execute function modules_guard_update();

drop policy if exists module_members_select on module_members;
create policy module_members_select on module_members for select
  using (
    is_admin()
    or has_permission('modules.view_all')
    or has_permission('modules.members')
    or is_module_member(module_id)
  );

-- module_members_write already says modules.members and keeps saying it.

-- The tree is structure: editing it is editing the file.
drop policy if exists module_nodes_write on module_nodes;
create policy module_nodes_write on module_nodes for all
  using (is_admin() or has_permission('modules.edit'))
  with check (is_admin() or has_permission('modules.edit'));

-- People on the tree are staffing, wherever the row sits.
drop policy if exists module_node_members_write on module_node_members;
create policy module_node_members_write on module_node_members for all
  using (is_admin() or has_permission('modules.members'))
  with check (is_admin() or has_permission('modules.members'));

drop policy if exists module_assigned_tasks_write on module_assigned_tasks;
create policy module_assigned_tasks_write on module_assigned_tasks for all
  using (is_admin() or has_permission('modules.members'))
  with check (is_admin() or has_permission('modules.members'));

-- Reading what the members filed gets its own name; an author always reads
-- their own.
drop policy if exists module_reports_select on module_reports;
create policy module_reports_select on module_reports for select
  using (
    author_id = auth.uid()
    or is_admin()
    or has_permission('modules.reports')
  );

-- Storage: seeing a file's attachments follows seeing all files; writing them
-- follows editing. A report's author keeps their own path.
create or replace function can_read_module_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_module_id uuid;
  v_report_id uuid;
begin
  if is_admin() or has_permission('modules.view_all') then
    return true;
  end if;

  v_report_id := module_report_file_id(p_path);
  if v_report_id is not null then
    return exists (
      select 1 from module_reports
      where id = v_report_id
        and (author_id = auth.uid() or has_permission('modules.reports'))
    );
  end if;

  begin
    v_module_id := (storage.foldername(p_path))[1]::uuid;
  exception when others then
    return false;
  end;
  return exists (
    select 1 from module_members
    where module_id = v_module_id and profile_id = auth.uid()
  );
end;
$$;

drop policy if exists module_files_write on storage.objects;
create policy module_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'modules'
    and (
      public.is_admin()
      or public.has_permission('modules.edit')
      or public.can_write_module_report_file(name)
    )
  );

drop policy if exists module_files_update on storage.objects;
create policy module_files_update on storage.objects for update
  to authenticated using (
    bucket_id = 'modules'
    and (
      public.is_admin()
      or public.has_permission('modules.edit')
      or public.can_write_module_report_file(name)
    )
  );

drop policy if exists module_files_delete on storage.objects;
create policy module_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'modules'
    and (
      public.is_admin()
      or public.has_permission('modules.edit')
      or public.can_write_module_report_file(name)
    )
  );

-- Importing sectors copies structure AND the people standing on it, so it asks
-- for both hands.
create or replace function copy_module_sectors(
  p_from_module uuid,
  p_to_module uuid
) returns integer
  language plpgsql security definer set search_path = public as $$
declare
  v_from_type uuid;
  v_to_type uuid;
  v_from_season uuid;
  v_to_season uuid;
  v_from_level uuid;
  v_to_level uuid;
  v_from_code text;
  v_to_code text;
  v_copied integer;
begin
  if not (is_admin()
          or (has_permission('modules.edit')
              and has_permission('modules.members'))) then
    raise exception 'not authorized';
  end if;

  if p_from_module = p_to_module then
    raise exception 'same file';
  end if;

  select module_type_id, season_id into v_from_type, v_from_season
    from modules where id = p_from_module;
  select module_type_id, season_id into v_to_type, v_to_season
    from modules where id = p_to_module;

  if v_from_type is null or v_to_type is null then
    raise exception 'file not found';
  end if;

  if v_from_season <> v_to_season then
    raise exception 'files are in different seasons';
  end if;

  select id, code into v_from_level, v_from_code from module_type_levels
   where module_type_id = v_from_type and depth = 1 and reference_set_id is null;
  select id, code into v_to_level, v_to_code from module_type_levels
   where module_type_id = v_to_type and depth = 1 and reference_set_id is null;

  if v_from_level is null or v_to_level is null then
    raise exception 'one of these files has no sectors';
  end if;

  if v_from_code <> v_to_code then
    raise exception 'these files are not divided the same way';
  end if;

  insert into module_nodes (module_id, level_id, label, sort_order)
  select p_to_module, v_to_level, n.label, n.sort_order
    from module_nodes n
   where n.module_id = p_from_module
     and n.level_id = v_from_level
     and n.parent_id is null
     and n.label is not null
     and not exists (
       select 1 from module_nodes t
        where t.module_id = p_to_module
          and t.level_id = v_to_level
          and t.label = n.label
     );

  get diagnostics v_copied = row_count;

  with candidate as (
    select tn.id as node_id,
           tr.id as role_id,
           sm.profile_id,
           tr.allows_multiple,
           row_number() over (
             partition by tn.id, tr.id order by sm.created_at, sm.id
           ) as rn
      from module_nodes sn
      join module_nodes tn
        on tn.module_id = p_to_module
       and tn.level_id = v_to_level
       and tn.label = sn.label
      join module_node_members sm on sm.node_id = sn.id
      join module_type_roles sr on sr.id = sm.role_id
      join module_type_roles tr
        on tr.module_type_id = v_to_type
       and tr.level_id = v_to_level
       and tr.code = sr.code
     where sn.module_id = p_from_module
       and sn.level_id = v_from_level
       and sn.parent_id is null
  )
  insert into module_node_members (node_id, role_id, profile_id, assigned_by)
  select c.node_id, c.role_id, c.profile_id, auth.uid()
    from candidate c
   where (c.allows_multiple or c.rn = 1)
     and not exists (
       select 1 from module_node_members x
        where x.node_id = c.node_id
          and x.role_id = c.role_id
          and x.profile_id = c.profile_id
     );

  return v_copied;
end;
$$;

-- The picker serves staffing, and staffing is modules.members.
create or replace function assignable_employees(
  p_season_id uuid,
  p_query text default null,
  p_is_external boolean default null,
  p_limit int default 40,
  p_offset int default 0,
  p_job_title_id uuid default null,
  p_only_free boolean default false,
  p_city_id uuid default null
)
returns table (
  id uuid,
  first_name text,
  father_name text,
  surname text,
  photo_url text,
  is_external boolean,
  external_organization text,
  external_title text,
  job_title_name text,
  job_title_name_en text,
  phone_sy text,
  phone_sa text,
  account_status text,
  assignments jsonb
)
language sql stable security definer set search_path = public as $$
  with permitted as (
    select is_admin() or has_permission('modules.members') as ok
  ),
  busy as (
    select mm.profile_id
      from module_members mm
      join modules m on m.id = mm.module_id
     where m.season_id = p_season_id
    union
    select nm.profile_id
      from module_node_members nm
      join module_nodes n on n.id = nm.node_id
      join modules m on m.id = n.module_id
     where m.season_id = p_season_id
  ),
  candidates as (
    select
      p.id, p.first_name, p.father_name, p.surname, p.photo_url,
      p.is_external, p.external_organization, p.external_title,
      jt.name as job_title_name,
      jt.name_en as job_title_name_en,
      p.phone_sy, p.phone_sa, p.account_status::text as account_status
    from season_participants sp
    join profiles p on p.id = sp.profile_id
    left join job_titles jt on jt.id = p.job_title_id
    where (select ok from permitted)
      and sp.season_id = p_season_id
      and sp.status = 'active'
      and not p.is_suspended
      and (p_is_external is null or p.is_external = p_is_external)
      and (p_job_title_id is null or p.job_title_id = p_job_title_id)
      and (p_city_id is null or p.city_id = p_city_id)
      and (not coalesce(p_only_free, false)
           or p.id not in (select profile_id from busy))
      and (
        nullif(btrim(coalesce(p_query, '')), '') is null
        or ar_fold(concat_ws(' ', p.first_name, p.father_name, p.surname))
             like '%' || ar_fold(btrim(p_query)) || '%'
        or ar_fold(coalesce(jt.name, '')) like '%' || ar_fold(btrim(p_query)) || '%'
        or ar_fold(coalesce(jt.name_en, '')) like '%' || ar_fold(btrim(p_query)) || '%'
      )
  )
  select
    c.id, c.first_name, c.father_name, c.surname, c.photo_url,
    c.is_external, c.external_organization, c.external_title,
    c.job_title_name, c.job_title_name_en,
    c.phone_sy, c.phone_sa, c.account_status,
    coalesce(f.files, '[]'::jsonb) as assignments
  from candidates c
  left join lateral (
    select jsonb_agg(
             jsonb_build_object(
               'module_id',  a.module_id,
               'name_ar',    a.name_ar,
               'name_en',    a.name_en,
               'hijri_year', a.hijri_year
             )
             order by a.name_ar
           ) as files
    from (
      select m.id as module_id, mt.name_ar, mt.name_en, s.hijri_year
        from module_members mm
        join modules m       on m.id = mm.module_id
        join module_types mt on mt.id = m.module_type_id
        join seasons s       on s.id = m.season_id
       where mm.profile_id = c.id
         and m.season_id = p_season_id
      union
      select m.id, mt.name_ar, mt.name_en, s.hijri_year
        from module_node_members nm
        join module_nodes n  on n.id = nm.node_id
        join modules m       on m.id = n.module_id
        join module_types mt on mt.id = m.module_type_id
        join seasons s       on s.id = m.season_id
       where nm.profile_id = c.id
         and m.season_id = p_season_id
    ) a
  ) f on true
  order by concat_ws(' ', c.first_name, c.father_name, c.surname)
  limit greatest(coalesce(p_limit, 40), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- ============================================================== 9. master data
--
-- `modules.types` named something it never did: no module-type editor exists.
-- What it gated is the master-data screen, and that is now its own section with
-- its own verbs. The type catalog (SQL-only today) writes under reference.edit.

do $$
declare t text;
begin
  -- module_type_role_tasks became module_type_tasks in 0028; the policy names
  -- followed the rename.
  foreach t in array array[
    'reference_sets', 'reference_set_fields', 'module_types',
    'module_type_fields', 'module_type_roles', 'module_type_tasks',
    'module_type_levels', 'module_type_task_groups'
  ] loop
    execute format('drop policy if exists %I on %I', t || '_write', t);
    execute format(
      'create policy %I on %I for all '
      'using (is_admin() or has_permission(''reference.edit'')) '
      'with check (is_admin() or has_permission(''reference.edit''))',
      t || '_write', t
    );
  end loop;
end
$$;

-- Entries: adding and correcting are reference.edit; removing is its own act.
drop policy if exists reference_items_write on reference_items;

drop policy if exists reference_items_insert on reference_items;
create policy reference_items_insert on reference_items for insert
  with check (is_admin() or has_permission('reference.edit'));

drop policy if exists reference_items_update on reference_items;
create policy reference_items_update on reference_items for update
  using (is_admin() or has_permission('reference.edit'))
  with check (is_admin() or has_permission('reference.edit'));

drop policy if exists reference_items_delete on reference_items;
create policy reference_items_delete on reference_items for delete
  using (is_admin() or has_permission('reference.delete'));

create or replace function copy_reference_items(
  p_set_id uuid,
  p_from_season uuid,
  p_to_season uuid
) returns integer
  language plpgsql security definer set search_path = public as $$
declare
  v_scoped boolean;
  v_copied integer;
  r record;
begin
  if not (is_admin() or has_permission('reference.import')) then
    raise exception 'not authorized';
  end if;

  select is_season_scoped into v_scoped from reference_sets where id = p_set_id;
  if v_scoped is not true then
    raise exception 'set is not season scoped';
  end if;
  if p_from_season = p_to_season then
    raise exception 'same season';
  end if;

  insert into reference_items
    (set_id, name_ar, name_en, data, is_active, sort_order, season_id)
  select i.set_id, i.name_ar, i.name_en, i.data, i.is_active, i.sort_order,
         p_to_season
    from reference_items i
   where i.set_id = p_set_id
     and i.season_id = p_from_season
     and not exists (
       select 1 from reference_items t
        where t.set_id = p_set_id
          and t.season_id = p_to_season
          and t.name_ar = i.name_ar
     );

  get diagnostics v_copied = row_count;

  for r in
    select f.key
      from reference_set_fields f
      join reference_sets rs on rs.id = f.reference_set_id
     where f.set_id = p_set_id
       and f.kind = 'reference'
       and rs.is_season_scoped
  loop
    update reference_items t
       set data = jsonb_set(
             t.data,
             array[r.key],
             coalesce(
               to_jsonb((
                 select n.id::text
                   from reference_items o
                   join reference_items n
                     on n.set_id = o.set_id
                    and n.name_ar = o.name_ar
                    and n.season_id = p_to_season
                  where o.id = (t.data ->> r.key)::uuid
                  limit 1
               )),
               'null'::jsonb
             )
           )
     where t.set_id = p_set_id
       and t.season_id = p_to_season
       and t.data ? r.key
       and nullif(t.data ->> r.key, '') is not null;
  end loop;

  return v_copied;
end;
$$;

-- ================================================================= 10. reports

-- The type catalog writes under reports.edit (it has no UI yet; SQL seeds
-- bypass RLS anyway).
do $$
declare t text;
begin
  foreach t in array array[
    'report_types', 'report_type_fields', 'report_type_columns'
  ] loop
    execute format('drop policy if exists %I on %I', t || '_write', t);
    execute format(
      'create policy %I on %I for all '
      'using (is_admin() or has_permission(''reports.edit'')) '
      'with check (is_admin() or has_permission(''reports.edit''))',
      t || '_write', t
    );
  end loop;
end
$$;

drop policy if exists reports_select on reports;
create policy reports_select on reports for select
  using (
    (is_published and is_approved())
    or is_admin()
    or has_permission('reports.view_all')
  );

drop policy if exists reports_write on reports;

-- Creating a report born published would smuggle a publish past its permission,
-- so the check names both.
drop policy if exists reports_insert on reports;
create policy reports_insert on reports for insert
  with check (
    is_admin()
    or (has_permission('reports.create')
        and (not is_published or has_permission('reports.publish')))
  );

drop policy if exists reports_update on reports;
create policy reports_update on reports for update
  using (
    is_admin()
    or has_permission('reports.edit')
    or has_permission('reports.publish')
  )
  with check (
    is_admin()
    or has_permission('reports.edit')
    or has_permission('reports.publish')
  );

drop policy if exists reports_delete on reports;
create policy reports_delete on reports for delete
  using (is_admin() or has_permission('reports.delete'));

-- Publishing — the act that puts a report before the whole mission — is its own
-- verb, kept apart from correcting a cell.
create or replace function reports_guard_update() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if is_admin() then
    return new;
  end if;

  if new.is_published is distinct from old.is_published
     and not has_permission('reports.publish') then
    raise exception 'not authorized';
  end if;

  if (to_jsonb(new) - 'is_published' - 'updated_at')
     is distinct from (to_jsonb(old) - 'is_published' - 'updated_at')
     and not has_permission('reports.edit') then
    raise exception 'not authorized';
  end if;

  return new;
end;
$$;

drop trigger if exists reports_guard_update on reports;
create trigger reports_guard_update
  before update on reports
  for each row execute function reports_guard_update();

drop policy if exists report_rows_write on report_rows;
create policy report_rows_write on report_rows for all
  using (is_admin() or has_permission('reports.edit'))
  with check (is_admin() or has_permission('reports.edit'));

drop policy if exists report_attachments_write on report_attachments;
create policy report_attachments_write on report_attachments for all
  using (is_admin() or has_permission('reports.edit'))
  with check (is_admin() or has_permission('reports.edit'));

drop policy if exists report_blocks_write on report_blocks;
create policy report_blocks_write on report_blocks for all
  using (is_admin() or has_permission('reports.edit'))
  with check (is_admin() or has_permission('reports.edit'));

create or replace function can_read_report_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_report_id uuid;
begin
  if is_admin() or has_permission('reports.view_all') then
    return true;
  end if;
  begin
    v_report_id := (storage.foldername(p_path))[1]::uuid;
  exception when others then
    return false;
  end;
  return exists (
    select 1 from reports
     where id = v_report_id and is_published
  ) and is_approved();
end;
$$;

drop policy if exists report_files_write on storage.objects;
create policy report_files_write on storage.objects for all
  to authenticated
  using (
    bucket_id = 'reports'
    and (public.is_admin() or public.has_permission('reports.edit'))
  )
  with check (
    bucket_id = 'reports'
    and (public.is_admin() or public.has_permission('reports.edit'))
  );

-- =============================================================== 11. dashboard
--
-- Same function, new names for its gates: the people block follows
-- employees.view, the files blocks follow seeing files, the queue block follows
-- seeing the queue.

create or replace function dashboard_stats(p_season_id uuid default null)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = public
as $$
declare
  v_season_id uuid;
  v_season jsonb;
  v_people jsonb;
  v_approvals jsonb;
  v_modules jsonb;
  v_reports jsonb;
  v_ratings jsonb;
  v_can_people boolean;
  v_can_modules boolean;
begin
  if not is_approved() then
    return jsonb_build_object('season', null);
  end if;

  select s.id into v_season_id
  from seasons s
  where (p_season_id is not null and s.id = p_season_id)
     or (p_season_id is null and s.is_current)
  limit 1;

  if v_season_id is null then
    return jsonb_build_object('season', null);
  end if;

  select jsonb_build_object(
           'id', s.id,
           'hijri_year', s.hijri_year,
           'gregorian_label', s.gregorian_label,
           'is_current', s.is_current
         )
    into v_season
  from seasons s
  where s.id = v_season_id;

  v_can_people := has_permission('employees.view');
  v_can_modules :=
    has_permission('modules.view_all') or has_permission('modules.members');

  if v_can_people then
    select jsonb_build_object(
             'participants', count(*) filter (where sp.status = 'active'),
             'withdrawn', count(*) filter (where sp.status = 'withdrawn'),
             'internal', count(*) filter
               (where sp.status = 'active' and not pr.is_external),
             'external', count(*) filter
               (where sp.status = 'active' and pr.is_external),
             'by_mission', coalesce((
               select jsonb_agg(jsonb_build_object('key', key, 'count', n)
                                order by n desc)
               from (
                 select coalesce(p2.mission_type::text, 'unknown') as key,
                        count(*) as n
                 from season_participants sp2
                 join profiles p2 on p2.id = sp2.profile_id
                 where sp2.season_id = v_season_id and sp2.status = 'active'
                 group by 1
               ) m
             ), '[]'::jsonb),
             'by_gender', coalesce((
               select jsonb_agg(jsonb_build_object('key', key, 'count', n)
                                order by n desc)
               from (
                 select coalesce(p3.gender::text, 'unknown') as key,
                        count(*) as n
                 from season_participants sp3
                 join profiles p3 on p3.id = sp3.profile_id
                 where sp3.season_id = v_season_id and sp3.status = 'active'
                 group by 1
               ) g
             ), '[]'::jsonb),
             'by_job_title', coalesce((
               select jsonb_agg(row_to_json(t)::jsonb order by t.n desc)
               from (
                 select jt.name as label_ar,
                        jt.name_en as label_en,
                        count(*) as n
                 from season_participants sp4
                 join profiles p4 on p4.id = sp4.profile_id
                 join job_titles jt on jt.id = p4.job_title_id
                 where sp4.season_id = v_season_id and sp4.status = 'active'
                 group by jt.id, jt.name, jt.name_en
                 order by count(*) desc
                 limit 8
               ) t
             ), '[]'::jsonb)
           )
      into v_people
    from season_participants sp
    join profiles pr on pr.id = sp.profile_id
    where sp.season_id = v_season_id;
  end if;

  if has_permission('approvals.view') then
    select jsonb_build_object(
             'pending', count(*) filter (where account_status = 'pending'),
             'approved', count(*) filter (where account_status = 'approved'),
             'rejected', count(*) filter (where account_status = 'rejected'),
             'incomplete', count(*) filter (where account_status = 'incomplete')
           )
      into v_approvals
    from profiles;
  end if;

  if v_can_modules then
    select jsonb_build_object(
             'total', count(*),
             'active', count(*) filter (where m.is_active),
             'draft', count(*) filter (where not m.is_active),
             'ended', count(*) filter
               (where m.ends_on is not null and m.ends_on < current_date),
             'running', count(*) filter (
               where m.is_active
                 and (m.ends_on is null or m.ends_on >= current_date)
             ),
             'by_type', coalesce((
               select jsonb_agg(row_to_json(t)::jsonb order by t.total desc)
               from (
                 select mt.name_ar as label_ar,
                        mt.name_en as label_en,
                        count(*) as total,
                        count(*) filter (where m2.is_active) as active,
                        count(*) filter (where not m2.is_active) as draft
                 from modules m2
                 join module_types mt on mt.id = m2.module_type_id
                 where m2.season_id = v_season_id
                 group by mt.id, mt.name_ar, mt.name_en
               ) t
             ), '[]'::jsonb),
             'nodes', coalesce((
               select count(*)
               from module_nodes n
               join modules m3 on m3.id = n.module_id
               where m3.season_id = v_season_id
             ), 0),
             'members', coalesce((
               select count(distinct mm.profile_id)
               from module_members mm
               join modules m4 on m4.id = mm.module_id
               where m4.season_id = v_season_id
             ), 0),
             'unstaffed', coalesce((
               select count(*)
               from modules m5
               where m5.season_id = v_season_id
                 and not exists (
                   select 1 from module_members mm2 where mm2.module_id = m5.id
                 )
             ), 0)
           )
      into v_modules
    from modules m
    where m.season_id = v_season_id;

    select jsonb_build_object(
             'total', count(*),
             'authors', count(distinct r.author_id),
             'series', coalesce((
               select jsonb_agg(row_to_json(d)::jsonb order by d.day)
               from (
                 select coalesce(r2.period_start, r2.created_at::date) as day,
                        count(*) as n
                 from module_reports r2
                 join modules m6 on m6.id = r2.module_id
                 where m6.season_id = v_season_id
                   and coalesce(r2.period_start, r2.created_at::date)
                       >= current_date - 29
                 group by 1
               ) d
             ), '[]'::jsonb)
           )
      into v_reports
    from module_reports r
    join modules m7 on m7.id = r.module_id
    where m7.season_id = v_season_id;
  end if;

  if v_can_modules then
    select jsonb_build_object(
             'count', count(*),
             'rated_people', count(distinct rt.ratee_id),
             'average', round(avg(rt.stars)::numeric, 2),
             'distribution', coalesce((
               select jsonb_agg(jsonb_build_object('stars', s, 'count', n)
                                order by s)
               from (
                 select rt2.stars as s, count(*) as n
                 from module_ratings rt2
                 join modules m8 on m8.id = rt2.module_id
                 where m8.season_id = v_season_id
                 group by rt2.stars
               ) x
             ), '[]'::jsonb)
           )
      into v_ratings
    from module_ratings rt
    join modules m9 on m9.id = rt.module_id
    where m9.season_id = v_season_id;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'season', v_season,
    'people', v_people,
    'approvals', v_approvals,
    'modules', v_modules,
    'reports', v_reports,
    'ratings', v_ratings
  ));
end;
$$;
