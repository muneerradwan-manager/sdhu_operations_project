-- Operational modules (الملفات التشغيلية).
--
-- A module is a self-contained unit of season work: its own data, its own job
-- roles, its own assigned members, its own per-role tasks and its own
-- attachments. The requirement is that new KINDS of module can be added later
-- WITHOUT altering the database structure — so the shape of a module is data,
-- not DDL:
--
--   module_types            one row per kind of module
--   module_type_fields      that kind's data schema (a field per row)
--   module_type_roles       that kind's job roles
--   module_type_role_tasks  the standing task list attached to each role
--   reference_sets/items    admin-managed master data behind dropdown fields
--
-- An actual module then stores its field values in `modules.data` (jsonb, keyed
-- by field key) and its people in `module_members`. Adding "hospital wings in
-- Madinah" as a new type is INSERTs only.
--
-- Visibility: a module is invisible until an admin activates it, and even then
-- only to the members assigned to it (plus admins / module managers).

-- ---------------------------------------------------------------- master data

-- A named list of admin-managed values (hotels, clusters, …) used to populate
-- dropdown fields. Free text is deliberately not an option for these: the same
-- hotel typed three ways is three hotels.
create table if not exists reference_sets (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name_ar text not null,
  name_en text not null,
  created_at timestamptz not null default now()
);

create table if not exists reference_items (
  id uuid primary key default gen_random_uuid(),
  set_id uuid not null references reference_sets (id) on delete cascade,
  name_ar text not null,
  name_en text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (set_id, name_ar)
);

create index if not exists idx_reference_items_set on reference_items (set_id);

-- ------------------------------------------------------------- module catalog

-- The kinds of value a module field can hold. `reference` resolves against a
-- reference_set; `pdf` stores {path, name} pointing into the `modules` bucket.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'module_field_kind') then
    create type module_field_kind as enum (
      'text', 'textarea', 'number', 'date', 'reference', 'pdf'
    );
  end if;
end
$$;

create table if not exists module_types (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name_ar text not null,
  name_en text not null,
  description_ar text,
  description_en text,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists module_type_fields (
  id uuid primary key default gen_random_uuid(),
  module_type_id uuid not null references module_types (id) on delete cascade,
  key text not null,
  label_ar text not null,
  label_en text not null,
  kind module_field_kind not null,
  -- Required when kind = 'reference'; ignored otherwise.
  reference_set_id uuid references reference_sets (id) on delete restrict,
  is_required boolean not null default false,
  sort_order int not null default 0,
  unique (module_type_id, key),
  constraint reference_field_needs_a_set check (
    kind <> 'reference' or reference_set_id is not null
  )
);

create table if not exists module_type_roles (
  id uuid primary key default gen_random_uuid(),
  module_type_id uuid not null references module_types (id) on delete cascade,
  code text not null,
  name_ar text not null,
  name_en text not null,
  -- Roles such as "mission members" hold several people; a supervisor holds one.
  allows_multiple boolean not null default false,
  is_required boolean not null default false,
  sort_order int not null default 0,
  unique (module_type_id, code)
);

-- The standing operational duties of a role. Defined once per module type and
-- shown to every holder of that role in every module of that type — they are
-- not re-entered when a module is created.
create table if not exists module_type_role_tasks (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null references module_type_roles (id) on delete cascade,
  title_ar text not null,
  title_en text not null,
  description_ar text,
  description_en text,
  sort_order int not null default 0
);

create index if not exists idx_role_tasks_role on module_type_role_tasks (role_id);

-- -------------------------------------------------------------------- modules

create table if not exists modules (
  id uuid primary key default gen_random_uuid(),
  module_type_id uuid not null references module_types (id) on delete restrict,
  season_id uuid not null references seasons (id) on delete restrict,
  title text not null,
  -- Field values keyed by module_type_fields.key.
  data jsonb not null default '{}'::jsonb,
  -- Unactivated modules are invisible to everyone but admins/module managers.
  is_active boolean not null default false,
  created_by uuid references profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_modules_season on modules (season_id);
create index if not exists idx_modules_type on modules (module_type_id);

create table if not exists module_members (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules (id) on delete cascade,
  role_id uuid not null references module_type_roles (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  assigned_by uuid references profiles (id),
  created_at timestamptz not null default now(),
  unique (module_id, role_id, profile_id)
);

create index if not exists idx_module_members_profile on module_members (profile_id);
create index if not exists idx_module_members_module on module_members (module_id);

-- ------------------------------------------------------------------- helpers

-- SECURITY DEFINER so the modules ⇄ module_members policies can consult each
-- other without RLS recursing.
create or replace function is_module_member(p_module_id uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from module_members
    where module_id = p_module_id and profile_id = auth.uid()
  );
$$;

-- An approved, unsuspended account. Gates read access to the module catalog.
create or replace function is_approved() returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles
    where id = auth.uid()
      and account_status = 'approved'
      and not is_suspended
  );
$$;

-- ---------------------------------------------------------------- permissions

insert into permissions (code, description, sort_order)
values ('modules', 'Operational modules section', 6)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('modules.manage',  'Create, edit & activate modules', 1),
  ('modules.members', 'Assign module members',           2),
  ('modules.types',   'Manage module types & master data', 3)
) as v(code, description, sort_order)
join permissions p on p.code = 'modules'
on conflict (code) do nothing;

-- ------------------------------------------------------------------------ RLS

alter table reference_sets         enable row level security;
alter table reference_items        enable row level security;
alter table module_types           enable row level security;
alter table module_type_fields     enable row level security;
alter table module_type_roles      enable row level security;
alter table module_type_role_tasks enable row level security;
alter table modules                enable row level security;
alter table module_members         enable row level security;

-- Catalog + master data: readable by any approved employee (the app renders
-- module forms and labels from it), written only by module-type managers.
do $$
declare t text;
begin
  foreach t in array array[
    'reference_sets', 'reference_items', 'module_types', 'module_type_fields',
    'module_type_roles', 'module_type_role_tasks'
  ] loop
    execute format('drop policy if exists %I on %I', t || '_select', t);
    execute format(
      'create policy %I on %I for select using (is_admin() or is_approved())',
      t || '_select', t
    );
    execute format('drop policy if exists %I on %I', t || '_write', t);
    execute format(
      'create policy %I on %I for all '
      'using (is_admin() or has_permission(''modules.types'')) '
      'with check (is_admin() or has_permission(''modules.types''))',
      t || '_write', t
    );
  end loop;
end
$$;

-- Modules: managers see everything; everyone else sees only the activated
-- modules they were assigned to.
drop policy if exists modules_select on modules;
create policy modules_select on modules for select
  using (
    is_admin()
    or has_permission('modules.manage')
    or has_permission('modules.members')
    or (is_active and is_module_member(id))
  );

drop policy if exists modules_write on modules;
create policy modules_write on modules for all
  using (is_admin() or has_permission('modules.manage'))
  with check (is_admin() or has_permission('modules.manage'));

-- Members: a member sees every other member of their own module — that roster,
-- with each person's role and contact details, is the point of the module.
drop policy if exists module_members_select on module_members;
create policy module_members_select on module_members for select
  using (
    is_admin()
    or has_permission('modules.manage')
    or has_permission('modules.members')
    or is_module_member(module_id)
  );

drop policy if exists module_members_write on module_members;
create policy module_members_write on module_members for all
  using (is_admin() or has_permission('modules.members'))
  with check (is_admin() or has_permission('modules.members'));

-- Module members must be able to read each other's contact details even without
-- the `employees.view` permission, so they can coordinate.
create or replace function shares_a_module_with(p_profile_id uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from module_members mine
    join module_members theirs on theirs.module_id = mine.module_id
    where mine.profile_id = auth.uid()
      and theirs.profile_id = p_profile_id
  );
$$;

drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select
  using (
    id = auth.uid()
    or is_admin()
    or has_permission('employees.view')
    or shares_a_module_with(id)
  );

-- -------------------------------------------------------------------- storage

insert into storage.buckets (id, name, public)
values ('modules', 'modules', false)
on conflict (id) do nothing;

-- Path convention: {module_id}/{file}. Readable by that module's members.
create or replace function can_read_module_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_module_id uuid;
begin
  if is_admin() or has_permission('modules.manage') then
    return true;
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

drop policy if exists module_files_read on storage.objects;
create policy module_files_read on storage.objects for select
  to authenticated using (
    bucket_id = 'modules' and public.can_read_module_file(name)
  );

drop policy if exists module_files_write on storage.objects;
create policy module_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'modules'
    and (public.is_admin() or public.has_permission('modules.manage'))
  );

drop policy if exists module_files_update on storage.objects;
create policy module_files_update on storage.objects for update
  to authenticated using (
    bucket_id = 'modules'
    and (public.is_admin() or public.has_permission('modules.manage'))
  );

drop policy if exists module_files_delete on storage.objects;
create policy module_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'modules'
    and (public.is_admin() or public.has_permission('modules.manage'))
  );

-- ------------------------------------------------------------- notifications

-- Assignment is only meaningful once the module is live, so an assignment made
-- during setup notifies at activation instead. Both paths land here.
create or replace function notify_module_assignment(
  p_module_id uuid,
  p_profile_id uuid,
  p_role_id uuid
) returns void
  language plpgsql security definer set search_path = public as $$
declare
  v_title text;
  v_type_name text;
  v_role_name text;
begin
  select m.title, mt.name_ar
    into v_title, v_type_name
    from modules m
    join module_types mt on mt.id = m.module_type_id
   where m.id = p_module_id;

  select name_ar into v_role_name from module_type_roles where id = p_role_id;

  insert into notifications (recipient_id, sender_id, title, body, data)
  values (
    p_profile_id,
    auth.uid(),
    'تم إسنادك إلى ملف تشغيلي',
    concat_ws(' — ', v_type_name, v_title, v_role_name),
    jsonb_build_object(
      'type', 'module_assigned',
      'module_id', p_module_id,
      'role_id', p_role_id
    )
  );
end;
$$;

create or replace function on_module_member_added() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from modules where id = new.module_id and is_active) then
    perform notify_module_assignment(new.module_id, new.profile_id, new.role_id);
  end if;
  return new;
end;
$$;

drop trigger if exists module_members_notify on module_members;
create trigger module_members_notify after insert on module_members
  for each row execute function on_module_member_added();

create or replace function on_module_activated() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  r record;
begin
  if new.is_active and not old.is_active then
    for r in select profile_id, role_id from module_members where module_id = new.id
    loop
      perform notify_module_assignment(new.id, r.profile_id, r.role_id);
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists modules_notify_activation on modules;
create trigger modules_notify_activation after update on modules
  for each row execute function on_module_activated();

-- ---------------------------------------------------------------- seed: type
-- The first module type: "قطاعات وأبراج حجاج سوريا في مكة المكرمة".
-- Everything below is data — a second type is added the same way, with no DDL.

insert into reference_sets (code, name_ar, name_en) values
  ('hotels',   'الفنادق',   'Hotels'),
  ('clusters', 'التكتلات',  'Clusters')
on conflict (code) do nothing;

insert into module_types (code, name_ar, name_en, description_ar, description_en, sort_order)
values (
  'makkah_sectors_towers',
  'قطاعات وأبراج حجاج سوريا في مكة المكرمة',
  'Makkah Sectors & Towers',
  'ملف تشغيلي يربط الفندق والتكتل بمشرفي البرج والقطاع وأعضاء البعثة.',
  'Links a hotel and its cluster to the tower/sector supervisors and mission members.',
  1
)
on conflict (code) do nothing;

insert into module_type_fields
  (module_type_id, key, label_ar, label_en, kind, reference_set_id, is_required, sort_order)
select
  mt.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
  rs.id, v.is_required, v.sort_order
from (values
  ('hotel',        'الفندق',              'Hotel',        'reference', 'hotels',   true,  1),
  ('cluster',      'التكتل',              'Cluster',      'reference', 'clusters', true,  2),
  ('official_pdf', 'الملف الرسمي (PDF)',  'Official PDF', 'pdf',       null,       false, 3)
) as v(key, label_ar, label_en, kind, set_code, is_required, sort_order)
cross join module_types mt
left join reference_sets rs on rs.code = v.set_code
where mt.code = 'makkah_sectors_towers'
on conflict (module_type_id, key) do nothing;

insert into module_type_roles
  (module_type_id, code, name_ar, name_en, allows_multiple, is_required, sort_order)
select mt.id, v.code, v.name_ar, v.name_en, v.allows_multiple, v.is_required, v.sort_order
from (values
  ('tower_supervisor',  'مشرف البرج',           'Tower supervisor',   false, true,  1),
  ('tower_deputy',      'نائب مشرف البرج',      'Deputy tower supervisor', false, false, 2),
  ('sector_supervisor', 'مشرف القطاع',          'Sector supervisor',  false, true,  3),
  ('sector_assistant',  'معاون مشرف القطاع',    'Sector assistant',   false, false, 4),
  ('mission_members',   'أعضاء البعثة',         'Mission members',    true,  false, 5)
) as v(code, name_ar, name_en, allows_multiple, is_required, sort_order)
cross join module_types mt
where mt.code = 'makkah_sectors_towers'
on conflict (module_type_id, code) do nothing;

-- Starter task lists. These are operational content owned by the Administration
-- — expected to be reviewed and edited, not treated as final.
insert into module_type_role_tasks (role_id, title_ar, title_en, sort_order)
select r.id, v.title_ar, v.title_en, v.sort_order
from (values
  ('tower_supervisor',  'الإشراف العام على البرج ومتابعة سير العمل اليومي', 'Overall supervision of the tower and daily operations', 1),
  ('tower_supervisor',  'متابعة سكن الحجاج وحل المشكلات الطارئة',            'Follow up on pilgrim accommodation and resolve incidents', 2),
  ('tower_supervisor',  'رفع تقرير يومي إلى مشرف القطاع',                    'Submit a daily report to the sector supervisor', 3),
  ('tower_deputy',      'إنابة مشرف البرج عند غيابه',                        'Stand in for the tower supervisor when absent', 1),
  ('tower_deputy',      'متابعة الحضور والانصراف لأعضاء البعثة في البرج',    'Track mission member attendance in the tower', 2),
  ('sector_supervisor', 'الإشراف على أبراج القطاع والتنسيق بين مشرفيها',     'Supervise the sector towers and coordinate their supervisors', 1),
  ('sector_supervisor', 'التنسيق مع التكتل والجهات الرسمية',                 'Coordinate with the cluster and official bodies', 2),
  ('sector_supervisor', 'اعتماد التقارير الواردة من الأبراج ورفعها',         'Approve and escalate tower reports', 3),
  ('sector_assistant',  'معاونة مشرف القطاع ضمن نطاق إشرافه',                'Assist the sector supervisor within their scope', 1),
  ('sector_assistant',  'متابعة الاحتياجات اللوجستية للأبراج',               'Follow up on tower logistics needs', 2),
  ('mission_members',   'الالتزام بالتوجيهات الصادرة عن مشرف البرج',         'Follow the tower supervisor''s directions', 1),
  ('mission_members',   'خدمة الحجاج ومتابعة احتياجاتهم اليومية',            'Serve pilgrims and follow up on their daily needs', 2),
  ('mission_members',   'الإبلاغ الفوري عن أي حالة طارئة',                   'Report any emergency immediately', 3)
) as v(role_code, title_ar, title_en, sort_order)
join module_types mt on mt.code = 'makkah_sectors_towers'
join module_type_roles r on r.module_type_id = mt.id and r.code = v.role_code
where not exists (
  select 1 from module_type_role_tasks t
  where t.role_id = r.id and t.title_ar = v.title_ar
);
