-- A tower has no address of its own, because a tower IS a hotel.
--
-- `node_location` looked in one place: the node's own `data`, under a field its
-- LEVEL declares as a location. That is right for a مخيم — منى's camp level
-- carries `موقع المخيم` and the coordinates are typed onto the node.
--
-- It is not right for a برج. The tower level declares no location field at all;
-- it draws from the `hotels` list, and each node names WHICH hotel it is. Where
-- that hotel stands is a property of the hotel — `location_url` on the master
-- data row, carried since 0019 and re-declared as a location in 0056 — and the
-- node simply points at it.
--
-- So every tower in the season read as a place with no position and was dropped
-- from `season_map` (0090) without a word. The map drew the camps of منى and
-- عرفات and not one of the mission's hotels, and nothing anywhere said why: an
-- absent pin and a place that has not been pinned yet look identical.
--
-- The node's own value still wins where it has one. A file that pins a specific
-- entrance for one tower is saying something more precise than the hotel's
-- general address, and the more precise answer is the one to keep.

create or replace function node_location(p_node_id uuid)
  returns table (lat double precision, lng double precision)
  language plpgsql stable security definer set search_path = public as $$
declare
  v_url text;
  v_match text[];
  -- One pair, matched three ways. `\+?` admits the resolved share link:
  -- Google writes "21.424128,+39.896510" and nothing else here does. See 0091.
  c_pair constant text := '(-?\d{1,3}(?:\.\d+)?)\s*,\s*\+?\s*(-?\d{1,3}(?:\.\d+)?)';
begin
  -- 1. What the node was given directly.
  select nullif(n.data ->> f.key, '')
    into v_url
    from module_nodes n
    join module_type_fields f
      on f.level_id = n.level_id
     and f.kind = 'location'
   where n.id = p_node_id
   order by f.sort_order
   limit 1;

  -- 2. Failing that, where the thing it IS happens to stand.
  --
  -- Matched by KIND rather than by the key `location_url`, for the same reason
  -- the node lookup above is: a list that spells its location field differently
  -- — the Arafat camps, a list added next season — is found without this
  -- function being edited again.
  if v_url is null then
    select nullif(ri.data ->> rf.key, '')
      into v_url
      from module_nodes n
      join reference_items ri on ri.id = n.reference_item_id
      join reference_set_fields rf
        on rf.set_id = ri.set_id
       and rf.kind = 'location'
     where n.id = p_node_id
     order by rf.sort_order
     limit 1;
  end if;

  if v_url is null then
    return;
  end if;

  v_match := regexp_match(v_url, '[?&](?:q|query|ll|center)=' || c_pair);
  if v_match is null then
    v_match := regexp_match(v_url, '@' || c_pair);
  end if;
  if v_match is null then
    v_match := regexp_match(v_url, '/(?:maps/)?(?:search|place|dir)/' || c_pair);
  end if;
  if v_match is null then
    return;
  end if;

  lat := v_match[1]::double precision;
  lng := v_match[2]::double precision;
  -- A URL can carry any two numbers. Off the globe means it was not a position.
  if abs(lat) > 90 or abs(lng) > 180 then
    return;
  end if;
  return next;
end;
$$;
