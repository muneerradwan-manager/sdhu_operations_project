-- A sector supervisor sleeps somewhere too.
--
-- 0136 settled that a man's مسكن is not typed in: it follows from his posting,
-- because the posting already says it. `housing_for` walks
--
--   module_node_members  ← he is posted here
--     └ module_nodes     ← the tower/برج
--         └ reference_item_id → فندق «سنود الريان»
--
-- and that is right for everybody the برج holds — مشرف البرج, نائبه, أعضاء
-- البعثة. It says nothing at all about the two men above them.
--
-- مشرف القطاع and معاون مشرف القطاع are posted to the القطاع, and a قطاع draws
-- its name from the `sectors` list (0096), not from `hotels`. So the join runs
-- and returns nothing, and two men who sleep in Makkah every night of the season
-- have no مسكن anywhere in this system. Nobody wrote that rule; it fell out of
-- which list the level draws from.
--
-- ------------------------------------------------------- why it cannot derive
--
-- A برج IS one hotel, so his bed follows from the posting. A قطاع is SEVERAL
-- towers, so it does not: the file says he supervises four hotels and is silent
-- on which one he sleeps in, and no amount of joining will make it speak. This
-- is the one case where the fact is genuinely absent rather than merely
-- unjoined, and the only honest answer is to ask for it — once, in the place
-- the posting is already made.
--
-- Hence `module_node_members.housing_item_id`: the hotel written against ONE
-- man on ONE posting. Per person and not per node, because the supervisor and
-- his معاون are commonly put in different towers.
--
-- ---------------------------------------------------------- one rule, one place
--
-- The rule this migration turns on is a single expression:
--
--     coalesce(mnm.housing_item_id, mn.reference_item_id)
--
-- — the hotel written against him, else the place his node stands on. It is
-- stated once, in the view `module_member_places`, and the four functions that
-- had each grown their own copy of the join now read it there.
--
-- Note what the coalesce preserves without being told to. A tower member with
-- nothing written falls through to his tower: 0136's behaviour, unchanged. A
-- camp member falls through to his camp, which is not in `hotels`, so the
-- deliberate camp exclusion of 0136 survives untouched. A sector member with
-- nothing written falls through to his sector, which is not in `hotels` either
-- — so a file where nobody has filled the new field in reads exactly as it does
-- today. The change is additive by construction.
--
-- ------------------------------------------------------------ and the beds
--
-- The second half. «الطاقة الاستيعابية» of a hotel has until now counted
-- pilgrims — the sum of the التكتلات pointing at it — against the hotel's
-- capacity, in Dart, on one screen. It has never counted the mission's own
-- people, though eight of them sleep there. A bed is a bed: `place_occupancy`
-- returns both figures and the ceiling, and the screen adds them.

-- ================================================== 1. the hotel written down

alter table module_node_members
  add column if not exists housing_item_id uuid references reference_items (id);

comment on column module_node_members.housing_item_id is
  'The hotel this man sleeps in, written against the posting — for a posting to '
  'a node that is not itself a place (a قطاع, a مركز). Null everywhere else: a '
  'tower member''s hotel is his tower and is derived, never entered (0136).';

create index if not exists idx_module_node_members_housing
  on module_node_members (housing_item_id)
  where housing_item_id is not null;

-- A مسكن is a hotel. The same guard 0136 dropped from `journey_stays`, put back
-- where the fact now lives: `sectors` and `camps` are entries too, and either
-- would be accepted by the foreign key and be silently wrong.

create or replace function module_member_housing_is_a_hotel()
  returns trigger
  language plpgsql
  set search_path = public
as $$
begin
  if new.housing_item_id is null then
    return new;
  end if;

  if not exists (
    select 1
      from reference_items ri
      join reference_sets rs on rs.id = ri.set_id
     where ri.id = new.housing_item_id
       and rs.code = 'hotels'
  ) then
    raise exception 'housing must be a hotel'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists module_node_members_housing_is_a_hotel
  on module_node_members;
create trigger module_node_members_housing_is_a_hotel
  before insert or update of housing_item_id on module_node_members
  for each row execute function module_member_housing_is_a_hotel();

-- ============================================ 2. where a posting puts a person
--
-- Every posting, with the place it puts the man at — his node's own place, or
-- the hotel written against him where one is. Unfiltered on purpose: it says
-- what the postings say, and each caller applies its own question to it.
--
-- Not exposed. A row here is where a named person sleeps, and the four callers
-- below are `security definer` and restate their own guards; PostgREST would
-- otherwise publish this to every signed-in account.

-- Dropped rather than replaced: `create or replace view` may only APPEND
-- columns, so a rerun that adds one anywhere but the end fails outright. The
-- callers below hold no dependency on it — their bodies are strings, parsed
-- when they run — so this is safe to repeat.
drop view if exists module_member_places;

create view module_member_places as
  select mnm.id           as member_id,
         mnm.profile_id,
         mnm.role_id,
         mnm.node_id,
         mn.module_id,
         m.season_id,
         mn.sort_order,
         coalesce(mnm.housing_item_id, mn.reference_item_id) as item_id,
         mnm.housing_item_id is not null                     as is_explicit
    from module_node_members mnm
    join module_nodes mn on mn.id = mnm.node_id
    join modules m on m.id = mn.module_id;

comment on view module_member_places is
  'Every posting and the place it puts the man at: the hotel written against '
  'him (0139), else whatever his node stands on. The single statement of that '
  'rule — housing_for, season_map, presence_gaps and place_occupancy all read '
  'it here rather than each carrying its own copy of the join.';

revoke all on module_member_places from public, anon, authenticated;

-- ============================================= 3. the مسكن, from both sources

create or replace function housing_for(
  p_profile_id uuid,
  p_season_id uuid,
  p_city_item_id uuid
) returns uuid
  language sql
  stable
  security definer
  set search_path = public
as $$
  select ri.id
  from module_member_places pl
  join reference_items ri on ri.id = pl.item_id
  join reference_sets rs on rs.id = ri.set_id
  where pl.profile_id = p_profile_id
    and pl.season_id = p_season_id
    -- Hotels only. See 0136 on why camps are not accommodation.
    and rs.code = 'hotels'
    and (p_city_item_id is null
         or (ri.data ->> 'city')::uuid = p_city_item_id)
  -- What somebody wrote down beats what was inferred. A man posted to a tower
  -- AND given a hotel of his own has been given it for a reason; the inference
  -- is the fallback, not the ruling.
  order by pl.is_explicit desc, pl.sort_order, ri.name_ar
  limit 1
$$;

comment on function housing_for(uuid, uuid, uuid) is
  'The hotel this man sleeps in, in this city, this season: the one written '
  'against a posting of his (0139), else the one his tower stands on (0136). '
  'The single source — journey_stays deliberately does not store it.';

-- ================================================= 4. the map counts the beds
--
-- Only `posted` changes, and only by widening what counts as being AT a place.
-- A hotel holding nothing but a sector supervisor used to draw grey — `posted`
-- of zero is `PlaceCondition.empty`, "no one is assigned here" — while a man
-- slept in it.

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
         -- one man standing in one camp — and a man posted to this hotel's
         -- tower who is also housed in it is likewise one man.
         (select count(distinct pl.profile_id)::int
            from module_member_places pl
            join modules m on m.id = pl.module_id
           where pl.item_id = p.id
             and pl.season_id = (select id from season)
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
  'how many are posted or housed at each (0139), how many have reported arriving '
  'in the last twelve hours, and how many incidents are open. Requires map.view.';

revoke execute on function season_map(uuid) from public, anon;
grant execute on function season_map(uuid) to authenticated;

-- ============================================ 5. the board expects him there
--
-- 0110 said it plainly: "a sector is a node too and nobody checks in to a
-- sector". True of the sector, and it took the man with it. Now that he has a
-- hotel, the hotel is where he is expected — `check_in_at_place` has never
-- asked about postings (0098), so he could already scan the poster; what was
-- missing was anyone noticing when he did not.

create or replace function presence_gaps(
  p_within   interval default interval '12 hours',
  p_item_id  uuid default null,
  p_season_id uuid default null
)
  returns table (
    profile_id  uuid,
    full_name   text,
    phone_sy    text,
    phone_sa    text,
    item_id     uuid,
    place_name  text,
    set_code    text,
    module_id   uuid,
    module_name text,
    node_label  text,
    role_name   text,
    last_seen   timestamptz
  )
  language sql stable security definer set search_path = public as $$
  -- The guard, restated by hand: `security definer` does not inherit the
  -- policies on the tables below, and without this the function would hand the
  -- mission's postings and telephone numbers to anybody who called it.
  --
  -- Only `checkin.board` — no "your own gaps" branch of the kind
  -- `presence_board` has. A man does not need a report to tell him he has not
  -- checked in; this is a room's screen, and its rows are other people.
  select p.id,
         concat_ws(' ', p.first_name, p.father_name, p.surname),
         p.phone_sy,
         p.phone_sa,
         ri.id,
         ri.name_ar,
         rs.code,
         m.id,
         -- The TYPE's name, and there is nothing else it could be: a file has
         -- no name of its own. 0024 dropped `modules.title` when it settled the
         -- rule that there is one file of a kind per season — so the kind IS
         -- the identity, and `raise_incident` names a file the same way.
         mt.name_ar,
         -- The قطاع he serves, not the hotel he sleeps in: the room ringing him
         -- needs to know which post is dark, and «فندق كذا — فندق كذا» would
         -- tell it nothing twice.
         coalesce(n.label, nri.name_ar, ri.name_ar),
         r.name_ar,
         seen.created_at
    from module_member_places pl
    join module_nodes n on n.id = pl.node_id
    join modules m on m.id = pl.module_id
    left join module_types mt on mt.id = m.module_type_id
    left join reference_items nri on nri.id = n.reference_item_id
    join module_type_roles r on r.id = pl.role_id
    join profiles p on p.id = pl.profile_id
    -- The posting must put him at a place. A sector is a node too and nobody
    -- checks in to a sector — so a sector posting reaches here only when a
    -- hotel has been written against it (0139), which is exactly the case this
    -- was blind to. `is_place` (0098) is what says which lists are things in
    -- the world, and it is read rather than a list of codes written here.
    join reference_items ri on ri.id = pl.item_id
    join reference_sets rs on rs.id = ri.set_id and rs.is_place
    -- His latest check-in AT THAT PLACE, if there is one. Lateral rather than a
    -- grouped join: one row per posting is the shape wanted, and a person
    -- posted to two places must be judged separately at each.
    left join lateral (
      select c.created_at
        from place_check_ins c
       where c.profile_id = pl.profile_id
         and c.item_id = ri.id
       order by c.created_at desc
       limit 1
    ) seen on true
   where m.is_active
     and (p_item_id is null or ri.id = p_item_id)
     and (p_season_id is null or pl.season_id = p_season_id)
     -- A suspended or unapproved account is not an empty post; it is an account
     -- that should not be posted at all, and it belongs on a different screen.
     and p.account_status = 'approved'
     and not p.is_suspended
     -- The whole condition, and the reason both halves are one clause: never
     -- seen and seen too long ago are the same answer to "is this post manned".
     and (seen.created_at is null or seen.created_at < now() - p_within)
     and (is_admin() or has_permission('checkin.board'))
   -- Never-seen first, then longest-quiet. The top of this list is where the
   -- room starts telephoning, so it has to be ordered by how worrying a row is
   -- rather than by place or by name.
   order by seen.created_at asc nulls first,
            ri.name_ar,
            concat_ws(' ', p.first_name, p.father_name, p.surname);
$$;

revoke execute on function presence_gaps(interval, uuid, uuid) from public, anon;
grant execute on function presence_gaps(interval, uuid, uuid) to authenticated;

-- ================================================== 6. how full a place is
--
-- Pilgrims and staff against the ceiling. Both halves were already true and
-- neither was ever added up: the pilgrims are counted on the master-data screen
-- in Dart and the staff nowhere at all, so a hotel of 130 beds holding 128
-- pilgrims and 8 of the mission read as comfortably inside its capacity.
--
-- Written against the SCHEMA rather than against the words "hotel" and
-- "cluster", which is the convention the Dart already follows: the FIRST number
-- field of a set is the figure that set counts in — a parent's is its ceiling,
-- a child's is its share. A place that comes to hold something else next season
-- is counted by this without being named in it.

create or replace function place_occupancy(
  p_item_id uuid,
  p_season_id uuid default null
) returns table (
    staff integer,
    pilgrims integer,
    capacity integer
  )
  language sql stable security definer set search_path = public as $$
  with season as (
    select s.id
      from seasons s
     where (p_season_id is not null and s.id = p_season_id)
        or (p_season_id is null and s.is_current)
     limit 1
  ),
  -- The ceiling: this entry's own first number field.
  own_number as (
    select f.key
      from reference_set_fields f
      join reference_items ri on ri.set_id = f.set_id
     where ri.id = p_item_id
       and f.kind = 'number'
     order by f.sort_order, f.key
     limit 1
  ),
  -- The share: the first number field of each list that POINTS at this one, and
  -- the entries of it that point at this entry. التكتلات, for a hotel.
  --
  -- Compared and summed as TEXT that happens to look like a number, never cast
  -- outright. `data` is jsonb a person typed into: one entry holding «٣٠» or a
  -- half-finished id would otherwise not be skipped, it would abort the query
  -- and take the whole page with it. This is `int.tryParse(…) ?? 0`, which is
  -- what the Dart has always done with the same values.
  children as (
    select coalesce(sum(
             case
               when (ci.data ->> cn.key) ~ '^\s*-?\d+\s*$'
                 then (ci.data ->> cn.key)::bigint
               else 0
             end
           ), 0)::int as total
      from reference_set_fields link
      join reference_items ri on ri.id = p_item_id
      join reference_items ci
        on ci.set_id = link.set_id
       and nullif(ci.data ->> link.key, '') = ri.id::text
      join lateral (
        select f.key
          from reference_set_fields f
         where f.set_id = link.set_id
           and f.kind = 'number'
         order by f.sort_order, f.key
         limit 1
      ) cn on true
     where link.kind = 'reference'
       and link.reference_set_id = ri.set_id
       -- A list that points at ITSELF (a place inside a place) is a nesting,
       -- not a filling of it. The Dart skips the same case.
       and link.set_id <> ri.set_id
       and ci.is_active
  )
  select
    -- DISTINCT: a man posted to two towers of one hotel is one man in one bed.
    (select count(distinct pl.profile_id)::int
       from module_member_places pl
       join modules m on m.id = pl.module_id
      where pl.item_id = p_item_id
        and pl.season_id = (select id from season)
        and m.is_active
        and (m.ends_on is null or m.ends_on >= current_date)),
    (select total from children),
    (select case
              when (ri.data ->> o.key) ~ '^\s*-?\d+\s*$'
                then (ri.data ->> o.key)::int
            end
       from reference_items ri, own_number o
      where ri.id = p_item_id)
  where is_admin() or has_permission('reference.view');
$$;

comment on function place_occupancy(uuid, uuid) is
  'How full a place is this season: the mission''s own people housed there '
  '(0139), the pilgrims its dependent entries add up to, and the ceiling the '
  'entry itself states. A bed is a bed — the screen shows the sum against the '
  'ceiling and the two figures beneath it.';

revoke execute on function place_occupancy(uuid, uuid) from public, anon;
grant execute on function place_occupancy(uuid, uuid) to authenticated;

-- ============================================== 7. the log names the hotel
--
-- A posting row now carries a third fact, and «فلان — القطاع الأول» does not
-- show that it changed.

create or replace function audit_record_label(p_table text, p_row jsonb)
  returns text
  language plpgsql stable security definer set search_path = public as $$
declare
  v text;
begin
  v := case p_table
    when 'profiles' then
      nullif(concat_ws(' ', p_row ->> 'first_name', p_row ->> 'father_name',
                            p_row ->> 'surname'), '')
    when 'user_permissions' then
      concat_ws(' — ',
        audit_actor_name((p_row ->> 'user_id')::uuid),
        (select code from permissions where id = (p_row ->> 'permission_id')::uuid))
    when 'season_participants' then
      audit_actor_name((p_row ->> 'profile_id')::uuid)
    when 'seasons' then
      (p_row ->> 'hijri_year')
    when 'modules' then
      (select mt.name_ar from module_types mt
        where mt.id = (p_row ->> 'module_type_id')::uuid)
    when 'module_members' then
      audit_actor_name((p_row ->> 'profile_id')::uuid)
    -- The hotel joins the label only when there is one, so a tower posting
    -- reads exactly as it did.
    when 'module_node_members' then
      concat_ws(' — ',
        audit_actor_name((p_row ->> 'profile_id')::uuid),
        (select label from module_nodes where id = (p_row ->> 'node_id')::uuid),
        (select ri.name_ar from reference_items ri
          where ri.id = (p_row ->> 'housing_item_id')::uuid))
    when 'module_nodes' then
      (p_row ->> 'label')
    when 'module_ratings' then
      audit_actor_name((p_row ->> 'ratee_id')::uuid)
    when 'module_reports' then
      (select mt.name_ar
         from modules m
         join module_types mt on mt.id = m.module_type_id
        where m.id = (p_row ->> 'module_id')::uuid)
    when 'incidents' then
      nullif(left(btrim(coalesce(p_row ->> 'body', '')), 80), '')
    when 'place_check_ins' then
      concat_ws(' — ',
        audit_actor_name((p_row ->> 'profile_id')::uuid),
        (select ri.name_ar from reference_items ri
          where ri.id = (p_row ->> 'item_id')::uuid))
    when 'report_misses' then
      concat_ws(' — ',
        audit_actor_name((p_row ->> 'profile_id')::uuid),
        (p_row ->> 'period_start'))
    when 'trips' then
      nullif(concat_ws(' — ',
        nullif(btrim(coalesce(p_row ->> 'trip_number', '')), ''),
        concat_ws(' ← ',
          (select ri.name_ar from reference_items ri
            where ri.id = (p_row ->> 'from_point_id')::uuid),
          (select ri.name_ar from reference_items ri
            where ri.id = (p_row ->> 'to_point_id')::uuid))), '')
    when 'journey_legs' then
      concat_ws(' — ',
        (select audit_actor_name(sp.profile_id) from season_participants sp
          where sp.id = (p_row ->> 'participant_id')::uuid),
        coalesce(
          (select nullif(concat_ws(' ',
                    nullif(btrim(coalesce(t.trip_number, '')), ''),
                    to_char(t.planned_departure_at, 'YYYY-MM-DD')), '')
             from trips t where t.id = (p_row ->> 'trip_id')::uuid),
          'ترتيب ذاتي'))
    -- The place is no longer on the row (0136), so the city is what names it.
    when 'journey_stays' then
      concat_ws(' — ',
        (select audit_actor_name(sp.profile_id) from season_participants sp
          where sp.id = (p_row ->> 'participant_id')::uuid),
        coalesce(
          (select ri.name_ar from reference_items ri
            where ri.id = (p_row ->> 'city_item_id')::uuid),
          p_row ->> 'city_name'))
    else null
  end;

  return coalesce(v,
    p_row ->> 'name_ar', p_row ->> 'title', p_row ->> 'name',
    p_row ->> 'label', p_row ->> 'code', p_row ->> 'email');
exception when others then
  return null;
end;
$$;
