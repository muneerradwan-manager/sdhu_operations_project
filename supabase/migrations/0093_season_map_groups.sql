-- The map, grouped — and with the hotels on it at last.
--
-- Two faults in 0090, and the second is the one that made the map look thin.
--
-- 1. NOTHING TO FILTER BY. Every place came back in one flat list, so a reader
--    wanting "the camps of Mina" had to find them among the hotels of Makkah by
--    eye. The season has four natural groups and the data always knew them; the
--    function simply never said which was which.
--
-- 2. THE HOTELS OF المدينة WERE NOT PLACES AT ALL. `season_map` reads
--    `module_nodes`, and a Madinah hotel is not one: the Madinah file's only
--    level is شركة الخدمة, which is a company and not somewhere anybody stands.
--    The hotel exists as MASTER DATA and nowhere else, so it could never appear
--    however well it was pinned.
--
-- So this returns two kinds of row:
--
--   * a NODE of a running file — a camp, a tower — carrying its counts;
--   * a located hotel that is NOT a node in this season, carrying none.
--
-- The second is deliberately narrowed by "not already a node": a Makkah hotel
-- IS a tower in the towers file, and returning it twice would draw two pins on
-- one building and count its people once.
--
-- GROUPING. A place whose level draws from the hotels list is grouped by the
-- hotel's CITY — which is what makes "فنادق مكة" and "فنادق المدينة" two
-- answers rather than one — and everything else by the file it belongs to.
-- Both names come back, Arabic and English, because the reader picks the
-- language and this function does not know which he picked.

-- Dropped rather than replaced, and it has to be.
--
-- The OUT columns of a function are part of its identity: `create or replace`
-- may change a body but never the shape of the row it returns, and this one
-- gains three columns. Postgres refuses with `cannot change return type of
-- existing function`, which is the correct answer to the wrong instruction.
--
-- Safe here because nothing in the database depends on it — no view, no other
-- function, no trigger. Its only caller is the app, which asks for it by name
-- over PostgREST and will find the new one.
drop function if exists season_map(uuid);

create function season_map(p_season_id uuid default null)
  returns table (
    node_id uuid,
    module_id uuid,
    module_name text,
    place_name text,
    -- Stable, for holding a filter across a refresh. Never shown.
    group_key text,
    group_ar text,
    group_en text,
    lat double precision,
    lng double precision,
    posted integer,
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
  -- Every node of a running file that is somewhere a person can stand (0089).
  nodes as (
    select n.id,
           n.module_id,
           mt.name_ar as module_name,
           coalesce(n.label, ri.name_ar) as place_name,
           lv.reference_set_id,
           ri.id as item_id,
           city.name_ar as city_ar,
           city.name_en as city_en,
           mt.code as type_code,
           mt.name_ar as type_ar,
           mt.name_en as type_en,
           loc.lat,
           loc.lng
      from module_nodes n
      join modules m on m.id = n.module_id
      join season on season.id = m.season_id
      join module_types mt on mt.id = m.module_type_id
      join module_type_levels lv on lv.id = n.level_id and lv.is_place
      left join reference_items ri on ri.id = n.reference_item_id
      -- A hotel names its city through a reference field (0019). Read here so
      -- that a tower can be grouped by where it stands rather than by the file
      -- it happens to be organised under.
      left join reference_sets hs
        on hs.id = lv.reference_set_id and hs.code = 'hotels'
      left join reference_items city
        on hs.id is not null
       and city.id = nullif(ri.data ->> 'city', '')::uuid
      cross join lateral node_location(n.id) loc
     where m.is_active
       and (m.ends_on is null or m.ends_on >= current_date)
       and loc.lat is not null
  ),
  -- Hotels the season has not turned into a node anywhere. `location_url` is
  -- read through the same three URL shapes everything else uses, by borrowing
  -- `node_location`'s reader — which is why the item is matched to a node id of
  -- null and parsed here instead.
  loose_hotels as (
    select ri.id,
           ri.name_ar,
           city.name_ar as city_ar,
           city.name_en as city_en,
           m2.lat,
           m2.lng
      from reference_items ri
      join reference_sets rs on rs.id = ri.set_id and rs.code = 'hotels'
      join reference_set_fields rf
        on rf.set_id = rs.id and rf.kind = 'location'
      left join reference_items city
        on city.id = nullif(ri.data ->> 'city', '')::uuid
      cross join lateral (
        select
          (regexp_match(ri.data ->> rf.key,
             '[?&](?:q|query|ll|center)=(-?\d{1,3}(?:\.\d+)?)\s*,\s*\+?\s*(-?\d{1,3}(?:\.\d+)?)'))[1]::double precision as lat,
          (regexp_match(ri.data ->> rf.key,
             '[?&](?:q|query|ll|center)=(-?\d{1,3}(?:\.\d+)?)\s*,\s*\+?\s*(-?\d{1,3}(?:\.\d+)?)'))[2]::double precision as lng
      ) m2
     where ri.is_active
       and m2.lat is not null
       and abs(m2.lat) <= 90
       and abs(m2.lng) <= 180
       and not exists (select 1 from nodes n where n.item_id = ri.id)
  )
  select n.id,
         n.module_id,
         n.module_name,
         n.place_name,
         case when n.reference_set_id is not null and n.city_ar is not null
              then 'hotels:' || n.city_ar
              else 'type:' || n.type_code
         end,
         case when n.reference_set_id is not null and n.city_ar is not null
              then 'فنادق ' || n.city_ar
              else n.type_ar
         end,
         case when n.reference_set_id is not null and n.city_en is not null
              then 'Hotels — ' || n.city_en
              else n.type_en
         end,
         n.lat,
         n.lng,
         (select count(*)::int from module_node_members nm where nm.node_id = n.id),
         (select count(distinct c.profile_id)::int
            from node_check_ins c
           where c.node_id = n.id
             and c.created_at >= now() - interval '12 hours'),
         (select count(*)::int from incidents i
           where i.node_id = n.id and i.state <> 'closed')
    from nodes n
   where is_admin()
      or has_permission('modules.view_all')
      or is_module_member(n.module_id)

  union all

  -- A hotel nobody is posted to yet. It is still somewhere the mission's
  -- pilgrims are, and leaving it off the map because no member has been
  -- assigned to it would hide most of المدينة.
  select null::uuid,
         null::uuid,
         null::text,
         h.name_ar,
         'hotels:' || coalesce(h.city_ar, '—'),
         'فنادق ' || coalesce(h.city_ar, '—'),
         'Hotels — ' || coalesce(h.city_en, h.city_ar, '—'),
         h.lat,
         h.lng,
         0, 0, 0
    from loose_hotels h
   -- Master data is readable by every approved account (0019), so the rule for
   -- a hotel is that and not membership: there is no file to be a member of.
   where is_approved()

   order by 6, 4;
$$;

revoke execute on function season_map(uuid) from public, anon;
grant execute on function season_map(uuid) to authenticated;
