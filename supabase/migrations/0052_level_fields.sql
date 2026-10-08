-- A مخيم is typed, not chosen — and it carries facts of its own.
--
-- 0050 made the camp an entry of a list, so that its الطاقة الاستيعابية had
-- somewhere to live. That was the wrong trade. A camp is "مخيم رقم 10": a number
-- written down when the center is drawn up, not an item from a catalogue
-- somebody maintains ahead of time. The list was the only way to carry the
-- capacity, so the list is what had to go — and the capacity moved to where it
-- always belonged, on the camp itself, beside its location.
--
-- Which means a LEVEL can now declare fields, exactly as the file has declared
-- them since 0017. `module_type_fields.level_id` says whose they are: null for
-- the file, as every field until now, and a level for a field carried by every
-- node at that level. It is the same distinction `module_type_roles.level_id`
-- has drawn since 0024 — a role held once for the file, or once per node — and
-- it is drawn the same way here.
--
-- The values sit in `module_nodes.data`, the way a file's values sit in
-- `modules.data`. Nothing else about a node changes.

-- ------------------------------------------------------------- whose field it is

alter table module_type_fields
  add column if not exists level_id uuid
    references module_type_levels (id) on delete cascade;

comment on column module_type_fields.level_id is
  'Null: a field of the FILE, its value in modules.data. Set: a field carried '
  'by every node at that level, its value in module_nodes.data.';

-- A key was unique per type, which was right while every field belonged to the
-- file. Now two levels of one type may each want a `capacity`, and they are not
-- the same field. The null-folding sentinel keeps the file's own fields behaving
-- exactly as before — the same shape 0040 used for a name per season.
do $$
declare v_name text;
begin
  select conname into v_name
    from pg_constraint
   where conrelid = 'module_type_fields'::regclass
     and contype = 'u'
     and pg_get_constraintdef(oid) like '%module_type_id%key%';
  if v_name is not null then
    execute format('alter table module_type_fields drop constraint %I', v_name);
  end if;
end
$$;

create unique index if not exists uq_module_type_fields_key
  on module_type_fields (
    module_type_id,
    coalesce(level_id, '00000000-0000-0000-0000-000000000000'::uuid),
    key
  );

alter table module_nodes
  add column if not exists data jsonb not null default '{}'::jsonb;

comment on column module_nodes.data is
  'The values of this node''s level fields, keyed by module_type_fields.key — '
  'the same shape modules.data has for the file''s own fields.';

-- ------------------------------------------------------ the camp is typed again

update module_type_levels lv
   set reference_set_id = null
  from module_types mt
 where mt.id = lv.module_type_id
   and mt.code = 'arafat_camp_assignment'
   and lv.code = 'camp';

-- And the list it was drawn from goes with it. Safe: nothing was ever entered
-- in it and no node points at one, which is checked rather than assumed — a
-- list somebody had started filling would be left standing.
do $$
declare v_set uuid;
begin
  select id into v_set from reference_sets where code = 'arafat_camps';
  if v_set is null then
    return;
  end if;
  if exists (select 1 from reference_items where set_id = v_set)
     or exists (
       select 1 from module_nodes n
       join reference_items i on i.id = n.reference_item_id
       where i.set_id = v_set
     ) then
    raise notice 'arafat_camps still holds entries — left in place';
    return;
  end if;
  delete from reference_sets where id = v_set;
end
$$;

-- ------------------------------------------------------- what a camp carries

insert into module_type_fields
  (module_type_id, level_id, key, label_ar, label_en, kind, is_required,
   sort_order)
select mt.id, lv.id, v.key, v.label_ar, v.label_en,
       v.kind::module_field_kind, v.is_required, v.sort_order
from (values
  ('capacity', 'الطاقة الاستيعابية', 'Capacity', 'number',   true,  1),
  ('location', 'موقع المخيم',        'Location', 'location', false, 2)
) as v(key, label_ar, label_en, kind, is_required, sort_order)
cross join module_types mt
join module_type_levels lv
  on lv.module_type_id = mt.id and lv.code = 'camp'
where mt.code = 'arafat_camp_assignment'
  -- Re-runnable by hand rather than by `on conflict`: the uniqueness is an
  -- expression index now, and `on conflict` cannot name one of those.
  and not exists (
    select 1 from module_type_fields f
     where f.module_type_id = mt.id and f.level_id = lv.id and f.key = v.key
  );
