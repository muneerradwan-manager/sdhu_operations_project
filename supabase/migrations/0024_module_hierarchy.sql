-- The operational file, corrected.
--
-- 0017 modelled a module as a flat row and expected it to be created once per
-- hotel. That is not what an operational file is. A file is created ONCE in a
-- season — "قطاعات وأبراج حجاج سوريا في مكة المكرمة" is a single file for the
-- whole season — and the hotels live INSIDE it, under their sectors:
--
--   الملف  (one per season)
--     └── القطاع الأول       مشرف القطاع + نائب أو أكثر
--           └── البرج/الفندق  مشرف البرج + نواب مشرف البرج + أعضاء البعثة
--
-- Three consequences, all of them handled here:
--
--   * no title — the file is named by its type, so `modules.title` goes away
--     and `(module_type_id, season_id)` becomes unique;
--   * a start date is chosen when the file is created; the end is not a date
--     but an event, the same one every season, so it is text on the TYPE
--     ("ترحيل آخر حاج إلى المدينة المنورة") rather than a column on the file;
--   * the roster is no longer flat. It hangs off the nodes of the tree.
--
-- The tree itself stays data, not DDL — the whole point of 0017. A module type
-- now also declares its LEVELS, and each of its roles says which level it
-- belongs to. "Hospital wings in Madinah, three levels deep" is still INSERTs.

-- ------------------------------------------------------------------- levels

-- One level of a module type's tree. `reference_set_id` says what a node at
-- this level IS: a tower node is a hotel drawn from the hotels list. A sector
-- has no such list — it is a division of this file only, named when it is
-- created ("القطاع الأول"), so its nodes carry a label instead.
create table if not exists module_type_levels (
  id uuid primary key default gen_random_uuid(),
  module_type_id uuid not null references module_types (id) on delete cascade,
  code text not null,
  name_ar text not null,
  name_en text not null,
  -- 1 is the outermost level; each level nests inside the one before it.
  depth int not null,
  reference_set_id uuid references reference_sets (id) on delete restrict,
  unique (module_type_id, code),
  unique (module_type_id, depth)
);

-- A role now belongs to a level: مشرف القطاع is held per sector, مشرف البرج per
-- tower. A null level_id keeps the old meaning — a role held once for the whole
-- file — which types without a tree still use.
alter table module_type_roles
  add column if not exists level_id uuid
    references module_type_levels (id) on delete cascade;

-- The event that closes a file of this type. Always the same event, so it is
-- described once here rather than typed into every file.
alter table module_types
  add column if not exists end_condition_ar text,
  add column if not exists end_condition_en text;

-- -------------------------------------------------------------------- nodes

create table if not exists module_nodes (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules (id) on delete cascade,
  level_id uuid not null references module_type_levels (id) on delete restrict,
  -- Null at depth 1; otherwise the node this one sits inside.
  parent_id uuid references module_nodes (id) on delete cascade,
  -- The master-data entry this node stands for, when its level has a list.
  reference_item_id uuid references reference_items (id) on delete restrict,
  -- Its name, when its level has no list: "القطاع الأول". A sector exists only
  -- inside this file, so it is named here rather than drawn from master data.
  label text,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  constraint module_node_is_named check (
    reference_item_id is not null or nullif(trim(label), '') is not null
  )
);

create index if not exists idx_module_nodes_module on module_nodes (module_id);
create index if not exists idx_module_nodes_parent on module_nodes (parent_id);

-- The same hotel cannot be entered twice in one file, and neither can two
-- sectors share a name. Partial indexes: each level fills in only one of the two.
create unique index if not exists uq_module_nodes_entry
  on module_nodes (module_id, level_id, reference_item_id)
  where reference_item_id is not null;

create unique index if not exists uq_module_nodes_label
  on module_nodes (module_id, level_id, label)
  where reference_item_id is null;

create table if not exists module_node_members (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references module_nodes (id) on delete cascade,
  role_id uuid not null references module_type_roles (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  assigned_by uuid references profiles (id),
  created_at timestamptz not null default now(),
  -- Deliberately per (node, role, profile) and no further: one person may hold
  -- two roles in the same node — a sector supervisor is commonly his own deputy.
  unique (node_id, role_id, profile_id)
);

create index if not exists idx_module_node_members_node
  on module_node_members (node_id);
create index if not exists idx_module_node_members_profile
  on module_node_members (profile_id);

-- ------------------------------------------------------------------ the file

alter table modules
  add column if not exists starts_on date;

-- ------------------------------------------------- reshape the seeded type

update module_types
   set end_condition_ar = 'ينتهي العمل بترحيل آخر حاج إلى المدينة المنورة',
       end_condition_en = 'Ends when the last pilgrim leaves for Madinah'
 where code = 'makkah_sectors_towers';

insert into module_type_levels
  (module_type_id, code, name_ar, name_en, depth, reference_set_id)
select mt.id, v.code, v.name_ar, v.name_en, v.depth, rs.id
from (values
  ('sector', 'القطاع',      'Sector', 1, null),
  ('tower',  'البرج/الفندق', 'Tower',  2, 'hotels')
) as v(code, name_ar, name_en, depth, set_code)
cross join module_types mt
left join reference_sets rs on rs.code = v.set_code
where mt.code = 'makkah_sectors_towers'
on conflict (module_type_id, code) do nothing;

-- معاون مشرف القطاع was the wrong title: the sector has a deputy, exactly as
-- the tower does. Renamed in place so existing assignments survive.
update module_type_roles r
   set code = 'sector_deputy',
       name_ar = 'نائب مشرف القطاع',
       name_en = 'Deputy sector supervisor'
  from module_types mt
 where mt.id = r.module_type_id
   and mt.code = 'makkah_sectors_towers'
   and r.code = 'sector_assistant';

-- Sector roles first, then tower roles: the file is built from the outside in.
-- A sector and a tower may each carry more than one deputy, and nothing stops
-- the same person being both a supervisor and his own deputy.
update module_type_roles r
   set level_id = lv.id,
       sort_order = v.sort_order,
       allows_multiple = v.allows_multiple
  from (values
  ('sector_supervisor', 'sector', 1, false),
  ('sector_deputy',     'sector', 2, true),
  ('tower_supervisor',  'tower',  1, false),
  ('tower_deputy',      'tower',  2, true),
  ('mission_members',   'tower',  3, true)
) as v(role_code, level_code, sort_order, allows_multiple),
  module_types mt,
  module_type_levels lv
 where mt.code = 'makkah_sectors_towers'
   and r.module_type_id = mt.id
   and r.code = v.role_code
   and lv.module_type_id = mt.id
   and lv.code = v.level_code;

-- The hotel is now the tower node itself, not a field on the file; the cluster
-- has no place in this structure. Both remain master data — only their use as
-- file-level fields ends. The official PDF stays: it belongs to the file.
delete from module_type_fields f
 using module_types mt
 where mt.id = f.module_type_id
   and mt.code = 'makkah_sectors_towers'
   and f.key in ('hotel', 'cluster');

-- ------------------------------------------------------- migrate existing data
--
-- Every old row was one hotel. Fold them back into the single file they should
-- always have been: the oldest row of each season survives as the file, and the
-- rest become tower nodes, grouped into sectors by the sector supervisor they
-- named. Those sectors were never named, so they are numbered in the order they
-- appear — an admin renames them afterwards.
--
-- Runs before the node triggers exist, so nobody is notified for it.

do $$
declare
  v_type uuid;
  v_sector_level uuid;
  v_tower_level uuid;
  v_sector_sup uuid;
  v_sector_dep uuid;
  r_season record;
  r_old record;
  v_keep uuid;
  v_sector uuid;
  v_tower uuid;
  v_supervisor uuid;
  v_hotel uuid;
  v_sector_no int;
  v_tower_no int;
begin
  select id into v_type from module_types where code = 'makkah_sectors_towers';
  if v_type is null then return; end if;

  select id into v_sector_level
    from module_type_levels where module_type_id = v_type and code = 'sector';
  select id into v_tower_level
    from module_type_levels where module_type_id = v_type and code = 'tower';
  select id into v_sector_sup
    from module_type_roles where module_type_id = v_type and code = 'sector_supervisor';
  select id into v_sector_dep
    from module_type_roles where module_type_id = v_type and code = 'sector_deputy';

  for r_season in
    select distinct season_id from modules where module_type_id = v_type
  loop
    select id into v_keep
      from modules
     where module_type_id = v_type and season_id = r_season.season_id
     order by created_at
     limit 1;

    v_sector_no := 0;
    v_tower_no := 0;

    for r_old in
      select id, data
        from modules
       where module_type_id = v_type and season_id = r_season.season_id
       order by created_at
    loop
      select profile_id into v_supervisor
        from module_members
       where module_id = r_old.id and role_id = v_sector_sup
       limit 1;

      v_sector := null;
      if v_supervisor is not null then
        select n.id into v_sector
          from module_nodes n
          join module_node_members m
            on m.node_id = n.id and m.role_id = v_sector_sup
         where n.module_id = v_keep
           and n.level_id = v_sector_level
           and m.profile_id = v_supervisor
         limit 1;
      end if;

      if v_sector is null then
        v_sector_no := v_sector_no + 1;
        insert into module_nodes (module_id, level_id, label, sort_order)
        values (v_keep, v_sector_level, 'القطاع ' || v_sector_no, v_sector_no)
        returning id into v_sector;

        insert into module_node_members (node_id, role_id, profile_id)
        select v_sector, mm.role_id, mm.profile_id
          from module_members mm
         where mm.module_id = r_old.id
           and mm.role_id in (v_sector_sup, v_sector_dep)
        on conflict do nothing;
      end if;

      -- A hotel already claimed by another tower would trip the unique index;
      -- that row simply had the same hotel entered twice, so drop the value.
      v_hotel := nullif(r_old.data ->> 'hotel', '')::uuid;
      if v_hotel is not null and exists (
        select 1 from module_nodes
         where module_id = v_keep
           and level_id = v_tower_level
           and reference_item_id = v_hotel
      ) then
        v_hotel := null;
      end if;

      -- Every node must be named. A row that never had a hotel picked, or lost
      -- it to the duplicate check above, is numbered so it survives the move and
      -- can be pointed at the right hotel afterwards.
      v_tower_no := v_tower_no + 1;
      insert into module_nodes
        (module_id, parent_id, level_id, reference_item_id, label, sort_order)
      values (
        v_keep, v_sector, v_tower_level, v_hotel,
        case when v_hotel is null then 'برج ' || v_tower_no end,
        v_tower_no
      )
      returning id into v_tower;

      insert into module_node_members (node_id, role_id, profile_id)
      select v_tower, mm.role_id, mm.profile_id
        from module_members mm
        join module_type_roles r on r.id = mm.role_id
       where mm.module_id = r_old.id
         and r.code in ('tower_supervisor', 'tower_deputy', 'mission_members')
      on conflict do nothing;
    end loop;

    delete from modules
     where module_type_id = v_type
       and season_id = r_season.season_id
       and id <> v_keep;

    delete from module_members where module_id = v_keep;

    -- Both values now live on the tree (the hotel) or nowhere (the cluster).
    update modules set data = data - 'hotel' - 'cluster' where id = v_keep;
  end loop;
end
$$;

-- Now that the duplicates are folded away, the rule can be stated: one file of
-- a kind per season.
update modules set starts_on = created_at::date where starts_on is null;
alter table modules alter column starts_on set not null;
alter table modules drop column if exists title;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'modules_one_per_season'
  ) then
    alter table modules
      add constraint modules_one_per_season unique (module_type_id, season_id);
  end if;
end
$$;

-- ------------------------------------------------------------ visibility

-- Membership now sits on the nodes. Both are consulted: a type with no tree
-- still assigns its people directly to the file.
create or replace function is_module_member(p_module_id uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from module_members
    where module_id = p_module_id and profile_id = auth.uid()
  ) or exists (
    select 1
    from module_node_members m
    join module_nodes n on n.id = m.node_id
    where n.module_id = p_module_id and m.profile_id = auth.uid()
  );
$$;

-- Everyone in the same FILE can reach each other's contact details: a tower
-- supervisor calling his sector supervisor is the everyday use of this app.
create or replace function shares_a_module_with(p_profile_id uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  with mine as (
    select module_id from module_members where profile_id = auth.uid()
    union
    select n.module_id
      from module_node_members m
      join module_nodes n on n.id = m.node_id
     where m.profile_id = auth.uid()
  ), theirs as (
    select module_id from module_members where profile_id = p_profile_id
    union
    select n.module_id
      from module_node_members m
      join module_nodes n on n.id = m.node_id
     where m.profile_id = p_profile_id
  )
  select exists (select 1 from mine join theirs using (module_id));
$$;

alter table module_type_levels  enable row level security;
alter table module_nodes        enable row level security;
alter table module_node_members enable row level security;

-- Levels are catalog, and read like the rest of it.
drop policy if exists module_type_levels_select on module_type_levels;
create policy module_type_levels_select on module_type_levels for select
  using (is_admin() or is_approved());

drop policy if exists module_type_levels_write on module_type_levels;
create policy module_type_levels_write on module_type_levels for all
  using (is_admin() or has_permission('modules.types'))
  with check (is_admin() or has_permission('modules.types'));

-- A node is visible exactly when its file is: the file's own policy is the
-- single source of truth, so this one defers to it rather than restating it.
drop policy if exists module_nodes_select on module_nodes;
create policy module_nodes_select on module_nodes for select
  using (exists (select 1 from modules m where m.id = module_nodes.module_id));

drop policy if exists module_nodes_write on module_nodes;
create policy module_nodes_write on module_nodes for all
  using (is_admin() or has_permission('modules.manage'))
  with check (is_admin() or has_permission('modules.manage'));

drop policy if exists module_node_members_select on module_node_members;
create policy module_node_members_select on module_node_members for select
  using (
    exists (
      select 1 from module_nodes n where n.id = module_node_members.node_id
    )
  );

drop policy if exists module_node_members_write on module_node_members;
create policy module_node_members_write on module_node_members for all
  using (is_admin() or has_permission('modules.members') or has_permission('modules.manage'))
  with check (is_admin() or has_permission('modules.members') or has_permission('modules.manage'));

-- Attachments follow the same rule, now that members may be node-deep.
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
  return is_module_member(v_module_id);
end;
$$;

-- A hotel standing as a tower in some file cannot be deleted from the master
-- list. The foreign key would refuse it anyway; naming it here is what lets the
-- app show the translated explanation instead of a raw constraint error.
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
      select 1 from module_nodes where reference_item_id = p_item_id
    )
    or exists (
      select 1
      from reference_items i
      join reference_set_fields f on f.set_id = i.set_id
      where f.kind = 'reference'
        and i.data ->> f.key = p_item_id::text
    );
$$;

-- ------------------------------------------------------------ notifications

-- The file no longer has a title, and an assignment is now to a place inside
-- it — "البرج/الفندق: فندق الصفوة" — so the body is rebuilt from the tree.
create or replace function module_node_label(p_node_id uuid) returns text
  language sql stable security definer set search_path = public as $$
  select concat_ws(': ', lv.name_ar, coalesce(ri.name_ar, n.label))
  from module_nodes n
  join module_type_levels lv on lv.id = n.level_id
  left join reference_items ri on ri.id = n.reference_item_id
  where n.id = p_node_id;
$$;

-- Replaced, not overloaded: the three-argument version from 0017 still reads
-- `modules.title` and would keep winning the exact-arity match if left behind.
drop function if exists notify_module_assignment(uuid, uuid, uuid);

create or replace function notify_module_assignment(
  p_module_id uuid,
  p_profile_id uuid,
  p_role_id uuid,
  p_node_id uuid default null
) returns void
  language plpgsql security definer set search_path = public as $$
declare
  v_type_name text;
  v_role_name text;
begin
  select mt.name_ar into v_type_name
    from modules m
    join module_types mt on mt.id = m.module_type_id
   where m.id = p_module_id;

  select name_ar into v_role_name from module_type_roles where id = p_role_id;

  insert into notifications (recipient_id, sender_id, title, body, data)
  values (
    p_profile_id,
    auth.uid(),
    'تم إسنادك إلى ملف تشغيلي',
    concat_ws(
      ' — ',
      v_type_name,
      case when p_node_id is null then null else module_node_label(p_node_id) end,
      v_role_name
    ),
    jsonb_build_object(
      'type', 'module_assigned',
      'module_id', p_module_id,
      'node_id', p_node_id,
      'role_id', p_role_id
    )
  );
end;
$$;

create or replace function on_module_node_member_added() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_module_id uuid;
begin
  select module_id into v_module_id from module_nodes where id = new.node_id;
  if exists (select 1 from modules where id = v_module_id and is_active) then
    perform notify_module_assignment(
      v_module_id, new.profile_id, new.role_id, new.node_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists module_node_members_notify on module_node_members;
create trigger module_node_members_notify after insert on module_node_members
  for each row execute function on_module_node_member_added();

-- Activation still releases the file to everyone in it — now including the
-- people sitting on its nodes.
create or replace function on_module_activated() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  r record;
begin
  if new.is_active and not old.is_active then
    for r in
      select profile_id, role_id, null::uuid as node_id
        from module_members where module_id = new.id
      union all
      select m.profile_id, m.role_id, m.node_id
        from module_node_members m
        join module_nodes n on n.id = m.node_id
       where n.module_id = new.id
    loop
      perform notify_module_assignment(new.id, r.profile_id, r.role_id, r.node_id);
    end loop;
  end if;
  return new;
end;
$$;
