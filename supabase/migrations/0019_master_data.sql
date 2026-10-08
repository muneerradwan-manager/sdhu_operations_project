-- Master data grows attributes: a hotel is a name, a map link and a city; a
-- cluster is a name, a head, a deputy and a city.
--
-- Rather than giving each of those its own table (and its own screens, and its
-- own code path in the module dropdowns), a reference SET now carries an item
-- schema the same way a module type carries a field schema:
--
--   reference_sets         the list        (hotels, clusters, cities, …)
--   reference_set_fields   its item shape  (a field per row)
--   reference_items.data   the values      (jsonb, keyed by field key)
--
-- So "manage hotels" and "manage clusters" are the same screen reading two
-- different schemas, and a future master entity — buses, clinics, gates — is
-- added with INSERTs, exactly like a new module type.

-- --------------------------------------------------------------- item schema

create table if not exists reference_set_fields (
  id uuid primary key default gen_random_uuid(),
  set_id uuid not null references reference_sets (id) on delete cascade,
  key text not null,
  label_ar text not null,
  label_en text not null,
  kind module_field_kind not null,
  -- For kind = 'reference': the set this field points at (a hotel's city).
  reference_set_id uuid references reference_sets (id) on delete restrict,
  is_required boolean not null default false,
  sort_order int not null default 0,
  unique (set_id, key),
  constraint reference_item_field_needs_a_set check (
    kind <> 'reference' or reference_set_id is not null
  )
);

create index if not exists idx_reference_set_fields_set
  on reference_set_fields (set_id);

alter table reference_items
  add column if not exists data jsonb not null default '{}'::jsonb;

alter table reference_set_fields enable row level security;

drop policy if exists reference_set_fields_select on reference_set_fields;
create policy reference_set_fields_select on reference_set_fields for select
  using (is_admin() or is_approved());

drop policy if exists reference_set_fields_write on reference_set_fields;
create policy reference_set_fields_write on reference_set_fields for all
  using (is_admin() or has_permission('modules.types'))
  with check (is_admin() or has_permission('modules.types'));

-- ------------------------------------------------------------ delete guard
-- Entries are now deleted outright rather than retired, so deleting one that a
-- module (or another entry) still points at has to be refused: those references
-- live inside jsonb and no foreign key can catch them.

create or replace function reference_item_in_use(p_item_id uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select
    exists (
      select 1
      from modules m
      join module_type_fields f on f.module_type_id = m.module_type_id
      where f.kind = 'reference'
        and m.data ->> f.key = p_item_id::text
    )
    or exists (
      select 1
      from reference_items i
      join reference_set_fields f on f.set_id = i.set_id
      where f.kind = 'reference'
        and i.data ->> f.key = p_item_id::text
    );
$$;

create or replace function guard_reference_item_delete() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if reference_item_in_use(old.id) then
    -- The app matches on this text to show a translated explanation.
    raise exception 'reference_item_in_use'
      using errcode = 'foreign_key_violation';
  end if;
  return old;
end;
$$;

drop trigger if exists reference_items_guard_delete on reference_items;
create trigger reference_items_guard_delete before delete on reference_items
  for each row execute function guard_reference_item_delete();

-- --------------------------------------------------------------------- seed

-- Cities are themselves master data: both a hotel and a cluster point at this
-- one list, so "Makkah" is a single row rather than a string typed twice.
insert into reference_sets (code, name_ar, name_en) values
  ('cities', 'المدن', 'Cities')
on conflict (code) do nothing;

insert into reference_items (set_id, name_ar, name_en, sort_order)
select rs.id, v.name_ar, v.name_en, v.sort_order
from (values
  ('مكة المكرمة',  'Makkah',   1),
  ('المدينة المنورة', 'Madinah', 2)
) as v(name_ar, name_en, sort_order)
join reference_sets rs on rs.code = 'cities'
on conflict (set_id, name_ar) do nothing;

-- Hotel: name (the built-in name column), map link, and which city it is in.
-- The city field is labelled "النوع" here because that is how the hotel list is
-- read in practice — a Makkah hotel or a Madinah hotel — while the cluster
-- calls the same list "المدينة". One list, two labels.
insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, reference_set_id, is_required, sort_order)
select
  own.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
  target.id, v.is_required, v.sort_order
from (values
  ('hotels',   'location_url', 'الموقع (رابط)',      'Location (link)', 'url',       null,     false, 1),
  ('hotels',   'city',         'النوع',              'Type',            'reference', 'cities', true,  2),
  ('clusters', 'head',         'رئيس التكتل',        'Cluster head',    'text',      null,     true,  1),
  ('clusters', 'deputy',       'نائب رئيس التكتل',   'Deputy head',     'text',      null,     false, 2),
  ('clusters', 'city',         'المدينة',            'City',            'reference', 'cities', true,  3)
) as v(set_code, key, label_ar, label_en, kind, target_code, is_required, sort_order)
join reference_sets own on own.code = v.set_code
left join reference_sets target on target.code = v.target_code
on conflict (set_id, key) do nothing;
