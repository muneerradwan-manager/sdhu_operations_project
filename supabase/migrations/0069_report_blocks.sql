-- A general report is written, not filled in.
--
-- The three meal reports are TYPED: their shape is known before anyone opens
-- the form, so the type declares the columns and the enterer supplies the
-- values. That is what a special report is, and it is the right bargain for a
-- document the Administration republishes every year in the same shape.
--
-- A general report has no such shape. It is a notice, a circular, a set of
-- instructions — a title, some paragraphs, a numbered list, a table, a link, a
-- code to scan, in whatever order the thing being said needs. Declaring a type
-- per notice would mean a migration per notice.
--
-- So its content is a SEQUENCE OF BLOCKS. The report says what it is; the
-- blocks say what it contains, in the order they are read. A new kind of block
-- is a new value here; a new notice is data.
--
-- Both kinds live in the same table and the same list. To the reader they are
-- all تقارير, which was the point from the start: a typed report and a written
-- one are both something published to be read.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'report_block_kind') then
    create type report_block_kind as enum (
      'heading',    -- a title inside the document
      'subheading', -- the line under it
      'paragraph',  -- prose
      'bullets',    -- an unordered list, one item per line
      'numbers',    -- an ordered list, one item per line
      'table',      -- columns and rows, both carried in the block itself
      'url',        -- a link, with the words to show for it
      'qr',         -- a code to be scanned
      'note',       -- something set apart — a warning, a caveat
      'divider'     -- a rule, for when a gap is not enough
    );
  end if;
end
$$;

create table if not exists report_blocks (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references reports (id) on delete cascade,
  kind report_block_kind not null,
  -- What the block holds, by kind:
  --
  --   heading/subheading/paragraph/note  {"text": "…"}
  --   bullets/numbers                    {"items": ["…", "…"]}
  --   url                                {"url": "…", "label": "…"}
  --   qr                                 {"value": "…", "label": "…"}
  --   table                              {"columns": ["…"], "rows": [["…"]]}
  --   divider                            {}
  --
  -- A table's columns are carried IN the block rather than declared on a type,
  -- which is the whole difference between this and a special report: nobody
  -- knows the shape of a notice before it is written.
  data jsonb not null default '{}'::jsonb,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_report_blocks_report on report_blocks (report_id);

alter table report_blocks enable row level security;

-- Visible exactly when the report it belongs to is; the reports policy is the
-- single source of truth, so this defers rather than restating it.
drop policy if exists report_blocks_select on report_blocks;
create policy report_blocks_select on report_blocks for select
  using (exists (select 1 from reports r where r.id = report_blocks.report_id));

drop policy if exists report_blocks_write on report_blocks;
create policy report_blocks_write on report_blocks for all
  using (is_admin() or has_permission('reports.manage'))
  with check (is_admin() or has_permission('reports.manage'));

-- ------------------------------------------------------------- the free type
--
-- One type for everything written rather than typed. It declares no columns —
-- its content is its blocks — and the header fields every report gets, so a
-- notice can still carry the paper it came from.

insert into report_types
  (code, name_ar, name_en, description_ar, description_en, sort_order)
values (
  'general',
  'تقرير عام',
  'General report',
  'تقرير يُكتب بحرّية: عناوين وفقرات وقوائم وجداول وروابط ورموز مسح، بالترتيب '
  'الذي يقتضيه ما يُقال.',
  'A report written freely: headings, paragraphs, lists, tables, links and '
  'scannable codes, in whatever order the thing being said needs.',
  99
)
on conflict (code) do nothing;

insert into report_type_fields
  (report_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select rt.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
       false, v.sort_order
from (values
  ('subtitle',    'عنوان فرعي',           'Subtitle',          'text',     1),
  ('note',        'ملاحظات',              'Notes',             'textarea', 2),
  ('official_pdf','المستند الرسمي (PDF)', 'Official document', 'pdf',      3)
) as v(key, label_ar, label_en, kind, sort_order)
cross join report_types rt
where rt.code = 'general'
on conflict (report_type_id, key) do nothing;
