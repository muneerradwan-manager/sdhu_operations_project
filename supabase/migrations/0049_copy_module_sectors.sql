-- Taking the قطاعات from the file that already has them.
--
-- Two files are now divided into sectors — قطاعات وأبراج (0024) and تشكيل فرق
-- المشاعر (0048) — and they are divided into the SAME sectors. The same القطاع 1,
-- the same مشرف, the same معاون. Entering them twice is not just tedious; it is
-- how the two files start disagreeing about who runs a sector.
--
-- So a file can take them from the other. What it takes are COPIES, exactly as
-- 0043 copies a list from one season into another: every sector becomes a new
-- row with a new id, and from that moment the two files know nothing about each
-- other. Rename a sector here and it keeps its old name there; delete it here
-- and it is still standing there. That is what was asked for — an import, not a
-- link — and it is what the schema gives for free, since a node and its members
-- cascade only downward from the file they belong to.
--
-- Sectors already in the target are left alone rather than duplicated, so
-- running it twice adds nothing the second time, and running it after entering
-- a couple by hand fills in the rest.
--
-- One function serves both directions. The two types name the two posts with
-- the same codes — `sector_supervisor`, `sector_deputy` — so which file is the
-- source is only a matter of which id goes where.

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
  v_copied integer;
begin
  -- The permission that governs writing a file's tree (0024).
  if not (is_admin() or has_permission('modules.manage')) then
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

  -- Same season, always. A sector belongs to the year it was drawn up in, and
  -- the people in it were chosen for that year; carrying either across seasons
  -- would be a different thing entirely, and nobody has asked for it.
  if v_from_season <> v_to_season then
    raise exception 'files are in different seasons';
  end if;

  -- The outermost level of each type, and it has to be one that is named by
  -- hand: a level drawn from a master list holds hotels, not sectors, and its
  -- nodes could not be matched by name.
  select id into v_from_level from module_type_levels
   where module_type_id = v_from_type and depth = 1 and reference_set_id is null;
  select id into v_to_level from module_type_levels
   where module_type_id = v_to_type and depth = 1 and reference_set_id is null;

  if v_from_level is null or v_to_level is null then
    raise exception 'one of these files has no sectors';
  end if;

  -- ------------------------------------------------------------- the sectors
  --
  -- Skipping the names already there. The guard is the same shape as the
  -- partial unique index the table carries (`uq_module_nodes_label`), so the
  -- two agree instead of racing.

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

  -- ------------------------------------------------------------- the people
  --
  -- `insert ... returning` cannot say which source row produced which new id,
  -- so the copies are found again by LABEL — unique per (file, level), which is
  -- what makes that safe. Roles are matched by CODE onto the target's own
  -- sector level: a code the target does not have simply fails to join, which
  -- is what keeps the three المشاعر team roles out of the towers file and the
  -- tower roles out of this one, without either being named here.
  --
  -- The people are copied for every matching sector, not only the ones just
  -- inserted: a sector entered by hand on this side, under the same name, is
  -- the same sector, and should end up with the same مشرف.

  with candidate as (
    select tn.id as node_id,
           tr.id as role_id,
           sm.profile_id,
           tr.allows_multiple,
           -- Which of several holders to take when the target's post is held by
           -- one person. A plain `not exists` would not do it: it is evaluated
           -- against the table as it stood before the statement, so two rows
           -- from the same source would both get in.
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

  -- What is returned is the number of SECTORS taken, not of people. That is the
  -- number the person who pressed the button is asking about.
  --
  -- Note that copying a person into an ACTIVE file notifies them, through the
  -- trigger 0024 put on `module_node_members`. That is left alone on purpose:
  -- it is true — they have been placed in a file they were not in — and it is
  -- the same message they would have received had someone added them by hand.
  return v_copied;
end;
$$;

revoke execute on function copy_module_sectors(uuid, uuid) from public, anon;
grant execute on function copy_module_sectors(uuid, uuid) to authenticated;
