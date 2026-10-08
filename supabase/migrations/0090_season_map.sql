-- The season on one map.
--
-- Every fact in this app is already tied to a place — a برج is a hotel with an
-- address, a مخيم has coordinates the Administration pinned, an arrival records
-- where the phone was, an urgent report records where the man was standing. And
-- none of it has ever been drawn together. `flutter_map` has been in this
-- project since 0021 and has only ever been used to PICK one point at a time.
--
-- What the operations room actually asks during those five days is a question
-- about a picture: where are our places, who is in them, and where is something
-- wrong. Answered as three lists on three screens, it is a question nobody
-- finishes asking.
--
-- This returns the PLACES. The incidents are already returned with their own
-- coordinates by `incidents_list` (0088) and are drawn as a second layer over
-- the same map — they belong to wherever the reporter was standing, which is
-- frequently not a place this file knows about at all. A broken-down bus on the
-- road to Arafat is exactly the case, and pinning it to the nearest camp would
-- put the marker somewhere nobody has to go.

create or replace function season_map(p_season_id uuid default null)
  returns table (
    node_id uuid,
    module_id uuid,
    module_name text,
    place_name text,
    lat double precision,
    lng double precision,
    -- Who HOLDS a post here. The establishment of the place.
    posted integer,
    -- Who has reported arriving here recently. The reality of it.
    present integer,
    open_incidents integer
  )
  language sql stable security definer set search_path = public as $$
  with season as (
    select s.id
      from seasons s
     where (p_season_id is not null and s.id = p_season_id)
        or (p_season_id is null and s.is_current)
     limit 1
  ),
  -- Only the levels that are physically somewhere (0089). A قطاع has no gate
  -- and no coordinates; drawing it would put a marker on an idea.
  places as (
    select n.id,
           n.module_id,
           mt.name_ar as module_name,
           coalesce(n.label, ri.name_ar) as place_name,
           loc.lat,
           loc.lng
      from module_nodes n
      join modules m on m.id = n.module_id
      join season on season.id = m.season_id
      join module_types mt on mt.id = m.module_type_id
      join module_type_levels lv on lv.id = n.level_id and lv.is_place
      left join reference_items ri on ri.id = n.reference_item_id
      cross join lateral node_location(n.id) loc
     where m.is_active
       -- The map is about the season as it is being run. A file whose end date
       -- has passed is history, and its camps are somebody else's now.
       and (m.ends_on is null or m.ends_on >= current_date)
       -- `node_location` returns no row for a node with nothing pinned, and the
       -- lateral join drops it here. A place with no coordinates cannot be on a
       -- map, and guessing one would be worse than leaving it off.
       and loc.lat is not null
  )
  select p.id,
         p.module_id,
         p.module_name,
         p.place_name,
         p.lat,
         p.lng,
         (select count(*)::int
            from module_node_members nm
           where nm.node_id = p.id),
         (select count(distinct c.profile_id)::int
            from node_check_ins c
           where c.node_id = p.id
             -- Twelve hours: a shift. Longer and "present" starts meaning
             -- "was here yesterday", which is the opposite of what a room
             -- looking at this map wants to know.
             and c.created_at >= now() - interval '12 hours'),
         (select count(*)::int
            from incidents i
           where i.node_id = p.id
             and i.state <> 'closed')
    from places p
   where
     -- Row security restated, because a definer function does not inherit it.
     -- The map may not become a way to see the establishment of files a person
     -- cannot open: he sees the places of files he is IN, and everything only
     -- if he runs files.
     is_admin()
     or has_permission('modules.view_all')
     or is_module_member(p.module_id)
   order by p.module_name, p.place_name;
$$;

revoke execute on function season_map(uuid) from public, anon;
grant execute on function season_map(uuid) to authenticated;
