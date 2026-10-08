-- Carrying a list forward into the next season.
--
-- 0040 gave hotels and clusters a season, which is right — but it left the
-- first day of 1449 staring at an empty hotel list, retyping the same forty
-- hotels that 1448 had. So a season can be copied from another one.
--
-- What it copies is COPIES. Every entry becomes a new row with a new id, and
-- from that moment the two seasons know nothing about each other: rename the
-- hotel in 1449 and 1448 keeps the old name, delete it from 1449 and it is
-- still standing in 1448. That is the whole point of asking for it — an import,
-- not a link.
--
-- Existing names in the target season are left alone rather than duplicated, so
-- running it twice adds nothing the second time and running it after entering a
-- few hotels by hand fills in the rest.

create or replace function copy_reference_items(
  p_set_id uuid,
  p_from_season uuid,
  p_to_season uuid
) returns integer
  language plpgsql security definer set search_path = public as $$
declare
  v_scoped boolean;
  v_copied integer;
  r record;
begin
  if not (is_admin() or has_permission('modules.types')) then
    raise exception 'not authorized';
  end if;

  select is_season_scoped into v_scoped from reference_sets where id = p_set_id;
  if v_scoped is not true then
    raise exception 'set is not season scoped';
  end if;
  if p_from_season = p_to_season then
    raise exception 'same season';
  end if;

  insert into reference_items
    (set_id, name_ar, name_en, data, is_active, sort_order, season_id)
  select i.set_id, i.name_ar, i.name_en, i.data, i.is_active, i.sort_order,
         p_to_season
    from reference_items i
   where i.set_id = p_set_id
     and i.season_id = p_from_season
     and not exists (
       select 1 from reference_items t
        where t.set_id = p_set_id
          and t.season_id = p_to_season
          and t.name_ar = i.name_ar
     );

  get diagnostics v_copied = row_count;

  -- A copied entry may point at another entry through a `reference` field. If
  -- that target list is itself season-scoped, the copy must point at the TARGET
  -- season version of it, or the new season would quietly reach back into the
  -- old one — exactly the link this whole function exists to avoid.
  --
  -- Today nothing hits this: a hotel and a cluster each reference only a city,
  -- and cities belong to no season. It is here so that the first field which
  -- does is not a silent bug.
  for r in
    select f.key
      from reference_set_fields f
      join reference_sets rs on rs.id = f.reference_set_id
     where f.set_id = p_set_id
       and f.kind = 'reference'
       and rs.is_season_scoped
  loop
    update reference_items t
       set data = jsonb_set(
             t.data,
             array[r.key],
             coalesce(
               to_jsonb((
                 select n.id::text
                   from reference_items o
                   join reference_items n
                     on n.set_id = o.set_id
                    and n.name_ar = o.name_ar
                    and n.season_id = p_to_season
                  where o.id = (t.data ->> r.key)::uuid
                  limit 1
               )),
               'null'::jsonb
             )
           )
     where t.set_id = p_set_id
       and t.season_id = p_to_season
       and t.data ? r.key
       and nullif(t.data ->> r.key, '') is not null;
  end loop;

  return v_copied;
end;
$$;

revoke execute on function copy_reference_items(uuid, uuid, uuid) from public, anon;
grant execute on function copy_reference_items(uuid, uuid, uuid) to authenticated;
