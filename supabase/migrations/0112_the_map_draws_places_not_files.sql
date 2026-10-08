-- The map was still drawn out of the operational files.
--
-- 0095 took places out of the files — a camp is an entry in `camps`, a hotel an
-- entry in `hotels`, chosen rather than typed into a node's label. 0098 finished
-- the thought: `reference_sets.is_place`, a code seeded per entry by trigger,
-- and `place_check_ins.item_id` pointing at the ENTRY. Presence stopped being a
-- fact about a file and became a fact about a place in the world.
--
-- `season_map` did not follow. It was written in 0090, grouped in 0093, and in
-- 0098 it gained a second branch for hotels no file had claimed — but its FIRST
-- branch, the one that produces most of the pins, still starts at
-- `module_nodes`. Everything wrong with the screen falls out of that one fact:
--
--   1. Every pin carried `module_types.name_ar`, and the sheet printed it under
--      «ضمن الملف التشغيلي» — so tapping a camp in منى answered with «توزيع
--      أعضاء مكاتب البعثة على مخيمات منى». A place has not been part of a file
--      since 0095, and the sentence was not merely redundant: it was false.
--   2. The GROUP was `'type:' || module_types.code` for anything that was not a
--      hotel, so the map's own filter chips were file types. The four groups the
--      mission thinks in — مخيمات منى, مخيمات عرفات, فنادق مكة, فنادق المدينة —
--      only ever came out right for the hotels.
--   3. A camp entry no active file held as a node was NOT ON THE MAP, although
--      it is a place with a code and can be checked into. The rescue branch
--      0098 added covers `hotels` and only `hotels`.
--   4. One entry held by two files drew TWO PINS on one spot. 0098 noticed the
--      half of this that mattered for counting — عرفات holds camp 16 as tent 154
--      and again as 158 — and fixed the presence count to be per entry while
--      leaving the duplicate rows.
--   5. Rows were narrowed by `is_module_member`, while the hotels branch beside
--      them was not. The same hotel appeared or vanished depending on whether
--      some file happened to hold it.
--
-- ------------------------------------------------------- what it is drawn from
--
-- Place entries. `reference_items` joined to a set with `is_place`, active, with
-- a location that resolves — and nothing else decides whether a pin exists. The
-- files are still asked ONE question, and only one: how many people are posted
-- here. That is a fact about the place («six of ours should be at this camp»),
-- it is what an operations room is looking at the map to learn, and it is
-- counted DISTINCT so a man posted to one camp by two files is one man.
--
-- ---------------------------------------------------------------- the grouping
--
-- Out of the data, as 0093 intended and only half achieved. A place entry names
-- its group in its own `data`: a hotel carries `city` (0021) and a camp carries
-- `site` (0095) — both are references to another list, so both resolve the same
-- way and a set added next season needs no code here.
--
-- The Arabic label drops the list's definite article and stands the group after
-- it: «الفنادق» + «مكة» → «فنادق مكة», «المخيمات» + «منى» → «مخيمات منى». That
-- is the phrase the mission uses, produced from the data rather than written
-- into a `case` that a fifth list would have to be added to.
--
-- ------------------------------------------------------------------ who may ask
--
-- `map.view`, once. 0100 gave the SCREEN a permission and deliberately left the
-- rows narrowing themselves per reader — which was the right call while the rows
-- came out of files a reader could be a member of. There is no membership to
-- narrow by once the pins are places, and the hotels branch already handed every
-- located hotel to any approved account. So the rule moves to where it can be
-- stated once and agree with the router: the holder of `map.view` sees the
-- season's places, and nobody else calls this at all.
--
-- This WIDENS what a file member sees (his own camps became all of them) and
-- NARROWS what an approved account without the grant sees (every hotel became
-- none). Both are what 0100 decided the screen is for.

drop function if exists season_map(uuid);

create function season_map(p_season_id uuid default null)
  returns table (
    item_id uuid,
    place_name text,
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
  places as (
    select ri.id,
           ri.name_ar as place_name,
           rs.code    as set_code,
           rs.name_ar as set_ar,
           rs.name_en as set_en,
           grp.id     as group_id,
           grp.name_ar as group_ar,
           grp.name_en as group_en,
           loc.lat,
           loc.lng
      from reference_items ri
      join reference_sets rs on rs.id = ri.set_id and rs.is_place
      -- A hotel names its city, a camp names its مشعر. Whichever it carries,
      -- it carries as a reference to another list — so one join reaches both,
      -- and a place set invented next season is grouped without editing this.
      left join reference_items grp
        on grp.id = nullif(
             coalesce(ri.data ->> 'city', ri.data ->> 'site'), '')::uuid
      cross join lateral place_location(ri.id) loc
     where ri.is_active
       and loc.lat is not null
       -- A season-scoped list shows this season's entries; an unscoped one
       -- shows all of its own, which is what unscoped means.
       and (ri.season_id is null
            or ri.season_id = (select id from season))
  )
  select p.id,
         p.place_name,
         p.set_code || ':' || coalesce(p.group_id::text, '—'),
         case
           when p.group_ar is null then p.set_ar
           -- «الفنادق» → «فنادق مكة». The article is dropped rather than a
           -- label being hard-coded per list.
           else regexp_replace(p.set_ar, '^ال', '') || ' ' || p.group_ar
         end,
         case
           when p.group_en is null then p.set_en
           else coalesce(p.set_en, p.set_ar) || ' — ' || p.group_en
         end,
         p.lat,
         p.lng,
         -- The one question still asked of the files, and it is a question
         -- about the place. DISTINCT: a man posted to this camp by two files is
         -- one man standing in one camp.
         (select count(distinct nm.profile_id)::int
            from module_node_members nm
            join module_nodes n on n.id = nm.node_id
            join modules m on m.id = n.module_id
           where n.reference_item_id = p.id
             and m.season_id = (select id from season)
             and m.is_active
             and (m.ends_on is null or m.ends_on >= current_date)),
         (select count(distinct c.profile_id)::int
            from place_check_ins c
           where c.item_id = p.id
             and c.created_at >= now() - interval '12 hours'),
         -- Incidents are still raised against a NODE (0088) — the report is
         -- about something happening in a file's area of work — so they are
         -- rolled up to the place through whatever nodes stand on it.
         (select count(*)::int
            from incidents i
            join module_nodes n on n.id = i.node_id
           where n.reference_item_id = p.id
             and i.state <> 'closed')
    from places p
   where is_admin() or has_permission('map.view')
   order by 3, 2;
$$;

comment on function season_map(uuid) is
  'The season''s places — the hotels and camps of reference_sets.is_place — with '
  'how many are posted at each, how many have reported arriving in the last '
  'twelve hours, and how many incidents are open. Drawn from place entries and '
  'not from module_nodes: a place stopped being part of an operational file in '
  '0095. Requires map.view.';

revoke execute on function season_map(uuid) from public, anon;
grant execute on function season_map(uuid) to authenticated;

-- ------------------------------------------------------------------ the index
--
-- The pins are now found by walking the place entries and asking each one three
-- questions, and two of the three look up a node by the entry it stands on.
create index if not exists module_nodes_reference_item_idx
  on module_nodes (reference_item_id)
  where reference_item_id is not null;
