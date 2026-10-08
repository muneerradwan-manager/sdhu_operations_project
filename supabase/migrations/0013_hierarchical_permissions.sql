-- Hierarchical permissions: parent (section access) -> children (actions).
-- Granting a child action is meaningful only alongside its parent section.
--
-- Only permissions that correspond to features ACTUALLY implemented in the app
-- today are seeded. (No job_titles / reports / generic edit until those screens
-- exist.) This migration resets the catalog and is safe to re-run.
--
-- RLS policies that referenced the old flat codes are recreated against the new
-- namespaced codes.

-- 1. Structure: parent + ordering.
alter table permissions
  add column if not exists parent_id uuid references permissions (id) on delete cascade,
  add column if not exists sort_order int not null default 0;

-- 2. Reset catalog (cascades to user_permissions).
delete from permissions;

-- 3. Seed parents (sections) — only sections that exist in the app.
insert into permissions (code, description, sort_order) values
  ('employees',   'Employees section',         1),
  ('approvals',   'Account approvals section', 2),
  ('seasons',     'Seasons section',           3),
  ('permissions', 'Permissions section',       4);

-- 4. Seed children (implemented actions), linked to their parent by code.
insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('employees.view',       'View employees & details',   'employees',   1),
  ('employees.create',     'Add employees',              'employees',   2),
  ('employees.suspend',    'Suspend / reactivate',       'employees',   3),
  ('employees.external',   'Manage external status',     'employees',   4),
  ('employees.documents',  'View documents',             'employees',   5),
  ('approvals.decide',     'Approve & reject accounts',  'approvals',   1),
  ('seasons.manage',       'Manage seasons',             'seasons',     1),
  ('seasons.participants', 'Manage participants',        'seasons',     2),
  ('permissions.manage',   'Grant & revoke permissions', 'permissions', 1)
) as v(code, description, parent_code, sort_order)
join permissions p on p.code = v.parent_code;

-- 5. Recreate RLS policies that referenced the old flat codes.
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select
  using (id = auth.uid() or is_admin() or has_permission('employees.view'));

drop policy if exists season_participants_select on season_participants;
create policy season_participants_select on season_participants for select
  using (
    profile_id = auth.uid()
    or is_admin()
    or has_permission('seasons.participants')
  );

drop policy if exists documents_read on storage.objects;
create policy documents_read on storage.objects for select
  to authenticated using (
    bucket_id = 'documents'
    and (
      public.is_admin()
      or public.has_permission('employees.documents')
      or (storage.foldername(name))[1] = auth.uid()::text
    )
  );
