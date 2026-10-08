-- Permission catalog (flexible RBAC — permissions granted directly, no role table)
create table permissions (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  description text
);

create table user_permissions (
  user_id uuid not null references profiles (id) on delete cascade,
  permission_id uuid not null references permissions (id) on delete cascade,
  granted_by uuid references profiles (id),
  granted_at timestamptz not null default now(),
  primary key (user_id, permission_id)
);

insert into permissions (code, description) values
  ('view_employees',            'View the employee directory'),
  ('manage_employees',          'Create / edit employee records'),
  ('approve_accounts',          'Approve or reject pending accounts'),
  ('manage_job_titles',         'Manage the job-title list'),
  ('manage_permissions',        'Grant or revoke permissions'),
  ('manage_seasons',            'Create and manage seasons'),
  ('manage_season_participants','Manage who participates in a season'),
  ('view_season_participants',  'View season participant rosters'),
  ('view_documents',            'View sensitive documents (passport/visa/nusuk)'),
  ('view_reports',              'View reports');
