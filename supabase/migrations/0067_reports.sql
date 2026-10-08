-- التقارير: the second thing under عام.
--
-- Until now عام held one entry — the operational files a person was put into.
-- Reports are the other half of what the mission publishes: مواعيد الوجبات في
-- المشاعر, ومكوناتها, وتوزيعها على التكتلات. Nobody is ASSIGNED to those. They
-- are read, by everyone, because everyone eats.
--
-- Shaped like the operational files on purpose, and for the same reason: a new
-- KIND of report must be addable without touching the schema. So a report type
-- carries its own header fields and its own table columns as data, exactly as a
-- module type carries fields, levels and roles.
--
-- Where it differs from a module, it differs because a report is a DOCUMENT:
--
--   * it has a title of its own — a module is named by its type, but there may
--     be several reports of one kind;
--   * it may belong to a season or to none. 'مكونات الوجبات' is contracted for
--     one year; 'دليل الطوارئ' is true until it is rewritten. So `season_id` is
--     NULLABLE and null means general, which is the default a new report takes;
--   * it carries the original document and links out. The paper exists, and a
--     table typed out of it is a convenience, not a replacement — so the file
--     and its URLs sit beside the table rather than instead of it.
--
-- To the reader they are all simply تقارير. The TYPE is the enterer's business:
-- it decides which columns the form asks for. Nowhere does the reader meet it.


-- --------------------------------------------------------------- the catalog

create table if not exists report_types (
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

-- What a report of this kind states about ITSELF, above its table: the days it
-- covers, a note, a link, a code to scan.
create table if not exists report_type_fields (
  id uuid primary key default gen_random_uuid(),
  report_type_id uuid not null references report_types (id) on delete cascade,
  key text not null,
  label_ar text not null,
  label_en text not null,
  kind module_field_kind not null,
  reference_set_id uuid references reference_sets (id) on delete restrict,
  is_required boolean not null default false,
  sort_order int not null default 0,
  unique (report_type_id, key),
  constraint report_field_reference_needs_a_set check (
    kind <> 'reference' or reference_set_id is not null
  )
);

-- One column of the table this kind of report is.
--
-- `source_set_id` is the interesting one. توزيع الوجبات has a column per تكتل,
-- and the تكتلات are contracted per season — so the type cannot list them, and
-- hard-coding fourteen columns would be wrong the first year a cluster is added.
-- One declaration with a source set EXPANDS at render time into a column per
-- entry of that set, in this report's season. The cell values are then keyed by
-- the entry's id rather than by a column key.
create table if not exists report_type_columns (
  id uuid primary key default gen_random_uuid(),
  report_type_id uuid not null references report_types (id) on delete cascade,
  key text not null,
  label_ar text not null,
  label_en text not null,
  kind module_field_kind not null default 'text',
  -- Set: this declaration is many columns, one per entry of that list.
  source_set_id uuid references reference_sets (id) on delete restrict,
  -- For a cell whose own value is drawn from a list.
  reference_set_id uuid references reference_sets (id) on delete restrict,
  -- Whether this column repeats the value above it when left blank — the
  -- التاريخ column of every one of these three documents is written once and
  -- read down. Presentation only; the stored value is still per row.
  spans_rows boolean not null default false,
  sort_order int not null default 0,
  unique (report_type_id, key)
);

-- --------------------------------------------------------------- the reports

create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  report_type_id uuid not null references report_types (id) on delete restrict,
  -- NULL means general: true regardless of which season is being run. The
  -- default, because most of what gets written down outlives one year.
  season_id uuid references seasons (id) on delete restrict,
  title text not null,
  -- The header field values, keyed by report_type_fields.key.
  data jsonb not null default '{}'::jsonb,
  -- Unpublished until somebody says so, like a module is inactive until
  -- activated: a half-entered meal timetable must not reach the mission.
  is_published boolean not null default false,
  created_by uuid references profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_reports_type on reports (report_type_id);
create index if not exists idx_reports_season on reports (season_id);

create table if not exists report_rows (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references reports (id) on delete cascade,
  -- Values keyed by report_type_columns.key, and — for an expanded column — by
  -- the reference item's id.
  data jsonb not null default '{}'::jsonb,
  sort_order int not null default 0
);

create index if not exists idx_report_rows_report on report_rows (report_id);

-- The paper it was typed from. Same columns as the other two attachment tables
-- (0031, 0045) and the same enum: an attachment is an attachment, and one
-- widget reads all three. Separate tables because what makes a row visible
-- differs, and that is a policy rather than a column.
create table if not exists report_attachments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references reports (id) on delete cascade,
  kind attachment_kind not null,
  -- Path inside the private `reports` bucket: {report_id}/{file}.
  path text not null,
  name text not null,
  mime_type text,
  size_bytes bigint,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_report_attachments_report
  on report_attachments (report_id);

-- Dropped first: Postgres has no `create trigger if not exists`, and a
-- migration that cannot be run twice is a migration that fails a retry.
drop trigger if exists reports_set_updated_at on reports;
create trigger reports_set_updated_at
  before update on reports
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------- permission
--
-- Reading needs none: a published report is for everybody approved, which is
-- what putting it under عام means. Writing is one permission, because entering
-- a report and correcting one are the same act by the same person.

insert into permissions (code, description, sort_order)
values ('reports', 'Reports section', 7)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select 'reports.manage', 'Create, edit & publish reports', p.id, 1
from permissions p where p.code = 'reports'
on conflict (code) do nothing;

-- ----------------------------------------------------------------------- RLS

alter table report_types        enable row level security;
alter table report_type_fields  enable row level security;
alter table report_type_columns enable row level security;
alter table reports             enable row level security;
alter table report_rows         enable row level security;
alter table report_attachments  enable row level security;

-- Catalog: readable by any approved employee — the app renders a report from
-- it — and written only by whoever manages reports.
do $$
declare t text;
begin
  foreach t in array array[
    'report_types', 'report_type_fields', 'report_type_columns'
  ] loop
    execute format('drop policy if exists %I on %I', t || '_select', t);
    execute format(
      'create policy %I on %I for select using (is_admin() or is_approved())',
      t || '_select', t
    );
    execute format('drop policy if exists %I on %I', t || '_write', t);
    execute format(
      'create policy %I on %I for all '
      'using (is_admin() or has_permission(''reports.manage'')) '
      'with check (is_admin() or has_permission(''reports.manage''))',
      t || '_write', t
    );
  end loop;
end
$$;

-- A published report is everyone's; an unpublished one is its author's problem.
drop policy if exists reports_select on reports;
create policy reports_select on reports for select
  using (
    (is_published and is_approved())
    or is_admin()
    or has_permission('reports.manage')
  );

drop policy if exists reports_write on reports;
create policy reports_write on reports for all
  using (is_admin() or has_permission('reports.manage'))
  with check (is_admin() or has_permission('reports.manage'));

-- Rows and attachments are visible exactly when their report is. The report's
-- own policy is the single source of truth, so these defer to it rather than
-- restating it and drifting.
drop policy if exists report_rows_select on report_rows;
create policy report_rows_select on report_rows for select
  using (exists (select 1 from reports r where r.id = report_rows.report_id));

drop policy if exists report_rows_write on report_rows;
create policy report_rows_write on report_rows for all
  using (is_admin() or has_permission('reports.manage'))
  with check (is_admin() or has_permission('reports.manage'));

drop policy if exists report_attachments_select on report_attachments;
create policy report_attachments_select on report_attachments for select
  using (
    exists (select 1 from reports r where r.id = report_attachments.report_id)
  );

drop policy if exists report_attachments_write on report_attachments;
create policy report_attachments_write on report_attachments for all
  using (is_admin() or has_permission('reports.manage'))
  with check (is_admin() or has_permission('reports.manage'));

-- ------------------------------------------------------------------- storage

insert into storage.buckets (id, name, public)
values ('reports', 'reports', false)
on conflict (id) do nothing;

-- Readable by anyone who may read the report it belongs to, which the reports
-- policy has already decided — so this asks it rather than deciding again.
create or replace function can_read_report_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_report_id uuid;
begin
  if is_admin() or has_permission('reports.manage') then
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

drop policy if exists report_files_read on storage.objects;
create policy report_files_read on storage.objects for select
  to authenticated using (
    bucket_id = 'reports' and public.can_read_report_file(name)
  );

drop policy if exists report_files_write on storage.objects;
create policy report_files_write on storage.objects for all
  to authenticated
  using (
    bucket_id = 'reports'
    and (public.is_admin() or public.has_permission('reports.manage'))
  )
  with check (
    bucket_id = 'reports'
    and (public.is_admin() or public.has_permission('reports.manage'))
  );
