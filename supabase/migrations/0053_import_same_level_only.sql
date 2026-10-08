-- A قطاع is not a مركز, and the import must not pretend otherwise.
--
-- 0049 accepted any two files of a season whose outermost level is named by
-- hand. That was the whole test when one file had sectors and another wanted
-- them. 0050 added توزيع أعضاء المكاتب على مخيمات عرفات, which is divided into
-- مراكز — also a division of a file, also named by hand, and nothing whatever
-- to do with a قطاع. One is a stretch of towers in Makkah; the other a station
-- at عرفات with its camps.
--
-- So the two levels must be the SAME level, by code. The app already stops
-- offering the button where the codes differ; this is what makes that a rule
-- rather than a courtesy, since the function is callable without it.
--
-- Everything else is 0049 unchanged.

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

  -- The new rule. Two divisions are the same division when they are called the
  -- same thing; anything else is two different ideas wearing one shape.
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

revoke execute on function copy_module_sectors(uuid, uuid) from public, anon;
grant execute on function copy_module_sectors(uuid, uuid) to authenticated;
