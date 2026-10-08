-- A man lives in a hotel, not in a terminal.
--
-- 0129 modelled the journey as a chain of MOVEMENTS between POINTS, and drew it
-- that way: مطار دمشق ← مطار جدة ← محطة مكة ← محطة المدينة ← مطار دمشق. Every
-- noun on that line is somewhere a man stands for an hour holding a bag.
--
-- What actually happens in a season is this:
--
--   سوريا                     home
--   ✈ طيران                   a few hours
--   مكة المكرمة  ~30 يوماً     in a hotel: the rites, then rest
--   🚄 قطار أو سيارة           a few hours
--   المدينة المنورة  ~5 أيام   in a hotel
--   ✈ طيران                   a few hours
--   سوريا                     home
--
-- Thirty-five days, and all but a few hours of them are spent in a **مسكن** —
-- a hotel or a camp. The terminals are not places he goes; they are details OF
-- the flights. Drawing them as the spine of his journey put the hours on the
-- page and left the month off it.
--
-- ------------------------------------------------------------ what this fixes
--
-- It also dissolves a confusion 0129 created and could not answer. Landing at
-- مطار الملك عبدالعزيز and next departing from محطة مكة produced a "gap" the
-- timeline asked the reader to fill in — but there was never a missing movement
-- there. جدة is where the aeroplane touched down on the way to مكة. Once the
-- spine is stays, the flight simply runs **سوريا ← مكة** and the airport is
-- printed underneath it in small type, where a terminal belongs.
--
-- --------------------------------------------------- why stays are STORED
--
-- Everything else in this feature is derived where it can be — that is 0130's
-- whole argument, and it stands. A stay cannot be:
--
--   * **Which hotel** he sleeps in is not in the legs and cannot be computed
--     from them. It is a new fact, and it is the one the room asks for by name.
--   * A man with `travels = false` has **no legs at all** and still has a stay.
--     He is in the Kingdom already, housed somewhere, for the whole season. A
--     spine derived from movements cannot represent him, and he is not an edge
--     case — 0129 added that flag precisely because there are many of him.
--
-- So the rows are real, and [ensure_participant_stays] builds them from the leg
-- chain so that the ordinary path costs nobody a second round of data entry.
--
-- --------------------------------------------------- and it reuses what exists
--
-- The place is a `reference_items` row from a set where `is_place` — the
-- الفنادق and المخيمات lists (0095/0098), season-scoped, already chosen inside
-- the operational files. **The same id `place_check_ins.item_id` points at**, so
-- "his stay is at this hotel" and "he checked in at this hotel" are the same
-- row, and the presence board (§30) and this timeline are talking about the
-- same thing without either being told about the other.
--
-- The city is a `saudi_cities` or `syrian_cities` entry — and the hotels
-- already carry `data->>'city'` pointing at the former, so choosing a مسكن for
-- a مكة stay can offer مكة's hotels and no others without a word of new data.

-- ================================================================ 1. the words

do $$
begin
  if not exists (select 1 from pg_type where typname = 'stay_kind') then
    create type stay_kind as enum (
      -- Syria, before he leaves and after he returns. Drawn as the two ends of
      -- the line rather than as somewhere the mission houses him.
      'home',
      -- A hotel or a camp: where he is based for weeks at a time.
      'residence',
      -- المشاعر — منى, عرفات, مزدلفة. Days rather than weeks, and a different
      -- kind of thing from a hotel: he is there for the rites, not based there.
      -- Seeded as its own kind so a timeline can draw the five days of ذو الحجة
      -- differently from the twenty-five around them, whenever somebody wants
      -- to record them. Nothing is required to use it.
      'rites'
    );
  end if;
end
$$;

-- ================================================================ 2. the table

create table if not exists journey_stays (
  id uuid primary key default gen_random_uuid(),

  -- The same anchor as a leg: his participation in this season, never his
  -- profile. A new season is an empty itinerary by construction.
  participant_id uuid not null
    references season_participants (id) on delete cascade,

  kind stay_kind not null default 'residence',

  -- Where, as a row rather than as a string: `saudi_cities` (مكة المكرمة,
  -- المدينة المنورة), `syrian_cities` for home, or `holy_sites` for the rites.
  -- Null is allowed, because a city the office has not put in any list is still
  -- somewhere a man slept, and refusing to record that would be the schema
  -- telling the truth to go away.
  city_item_id uuid references reference_items (id) on delete restrict,

  -- What to print when there is no row to print — and what the leg chain hands
  -- over, since `travel_points.city` is text (0133). Kept alongside the id
  -- rather than instead of it so a stay is legible even where the lists are not
  -- yet filled in.
  city_name text,

  -- The مسكن itself: a hotel or a camp. `restrict`, so a hotel cannot be
  -- deleted from master data while somebody's season says he lived in it.
  place_item_id uuid references reference_items (id) on delete restrict,

  -- When it began and ended. Both nullable: the current stay has no end yet,
  -- and a stay entered ahead of time has neither.
  arrived_at timestamptz,
  departed_at timestamptz,

  -- Which movements bound it. These are what make [ensure_participant_stays]
  -- idempotent, and what lets a rebuilt spine recognise the stays it already
  -- created instead of writing them a second time.
  arrival_leg_id uuid references journey_legs (id) on delete set null,
  departure_leg_id uuid references journey_legs (id) on delete set null,

  note text,
  sort_order int not null default 0,

  created_at timestamptz not null default now(),
  created_by uuid references profiles (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references profiles (id),

  constraint stay_ends_after_it_starts check (
    arrived_at is null or departed_at is null or departed_at >= arrived_at
  )
);

create index if not exists idx_journey_stays_participant
  on journey_stays (participant_id, arrived_at);
create index if not exists idx_journey_stays_place
  on journey_stays (place_item_id) where place_item_id is not null;

-- One stay per movement that delivers him somewhere.
--
-- `nulls not distinct` is the whole point: the home stay he starts from has no
-- arrival leg, and without this two runs of the builder would give him two of
-- them. Postgres 15 and later only — this database is on 17.
create unique index if not exists one_stay_per_arrival
  on journey_stays (participant_id, arrival_leg_id) nulls not distinct;

comment on table journey_stays is
  'Where a participant is BASED, and for how long — the spine of his season. '
  'The legs (0129) are what carry him between these; almost all of his time is '
  'spent here. place_item_id is the same reference row place_check_ins uses.';

-- ====================================================== 3. a place is a place
--
-- The مسكن must come from a list somebody has declared to BE places (0098), not
-- from any reference list at all. Otherwise a stay could name a قطاع or a
-- job title and the timeline would print it without blinking.

create or replace function stay_place_is_a_place() returns trigger
  language plpgsql set search_path = public as $$
declare
  v_is_place boolean;
begin
  if new.place_item_id is null then
    return new;
  end if;
  select rs.is_place into v_is_place
    from reference_items ri
    join reference_sets rs on rs.id = ri.set_id
   where ri.id = new.place_item_id;
  if not coalesce(v_is_place, false) then
    raise exception
      'a stay must be at a place — a hotel or a camp, not an arrangement on paper'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists journey_stays_place_is_a_place on journey_stays;
create trigger journey_stays_place_is_a_place
  before insert or update on journey_stays
  for each row execute function stay_place_is_a_place();

-- ============================================== 4. a city name becomes a row
--
-- The leg chain speaks in `travel_points.city`, which is text (0133); the stay
-- would rather hold the row. Matched by Arabic name across the two city lists
-- and the holy sites — and returning null is a perfectly good answer, which is
-- why `city_name` is kept beside the id.

create or replace function travel_city_item(p_name text) returns uuid
  language sql stable set search_path = public as $$
  select ri.id
  from reference_items ri
  join reference_sets rs on rs.id = ri.set_id
  where rs.code in ('saudi_cities', 'syrian_cities', 'holy_sites')
    and ri.name_ar = btrim(coalesce(p_name, ''))
  limit 1
$$;

-- ========================================== 5. building the spine from the legs
--
-- Idempotent, and safe to call after every change to anybody's movements. It
-- writes only what is missing and never touches what a person has edited — the
-- hotel somebody chose for a stay survives any number of rebuilds, because the
-- row is matched on its arrival leg and left alone once found.

create or replace function ensure_participant_stays(p_participant_id uuid)
  returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_leg record;
  v_prev_leg uuid := null;
  v_prev_arrival timestamptz := null;
  v_prev_city text := null;
  v_first boolean := true;
  v_made int := 0;
  v_kind stay_kind;
begin
  for v_leg in
    select l.id,
           l.role,
           coalesce(t.planned_departure_at, l.planned_departure_at) as departs,
           coalesce(l.actual_arrival_at,
                    t.planned_arrival_at, l.planned_arrival_at,
                    t.planned_departure_at, l.planned_departure_at) as arrives,
           l.actual_departure_at,
           fp.data ->> 'city' as from_city,
           tp.data ->> 'city' as to_city
      from journey_legs l
      left join trips t on t.id = l.trip_id
      left join reference_items fp
        on fp.id = coalesce(t.from_point_id, l.from_point_id)
      left join reference_items tp
        on tp.id = coalesce(t.to_point_id, l.to_point_id)
     where l.participant_id = p_participant_id
       and l.status in ('planned', 'confirmed', 'completed')
     order by coalesce(t.planned_departure_at, l.planned_departure_at),
              l.created_at
  loop
    -- Where he set out from, before the first movement. `home`, and it closes
    -- when that movement leaves.
    if v_first then
      insert into journey_stays
        (participant_id, kind, city_item_id, city_name,
         arrived_at, departed_at, arrival_leg_id, departure_leg_id, sort_order)
      values
        (p_participant_id, 'home', travel_city_item(v_leg.from_city),
         v_leg.from_city, null, v_leg.departs, null, v_leg.id, 0)
      on conflict do nothing;
      if found then v_made := v_made + 1; end if;
      v_first := false;
    end if;

    -- Close the stay the previous movement delivered him to.
    --
    -- Its city is where THIS movement sets out from, not where the last one
    -- landed — and that is the whole correction this migration exists for. The
    -- inbound flight terminates at مطار الملك عبدالعزيز; the man does not live
    -- in جدة. What the chain actually tells us is that he next departed from
    -- محطة مكة المكرمة, so مكة is where he spent those thirty days and the
    -- airport was three hours of it.
    --
    -- Falls back to the arrival city only when this leg names no departure
    -- city, which is a list somebody has not finished filling in rather than a
    -- fact about anybody's season.
    if v_prev_leg is not null then
      insert into journey_stays
        (participant_id, kind, city_item_id, city_name,
         arrived_at, departed_at, arrival_leg_id, departure_leg_id, sort_order)
      values
        (p_participant_id, 'residence',
         travel_city_item(coalesce(v_leg.from_city, v_prev_city)),
         coalesce(v_leg.from_city, v_prev_city),
         v_prev_arrival, v_leg.departs, v_prev_leg, v_leg.id, v_made)
      on conflict do nothing;
      if found then v_made := v_made + 1; end if;
    end if;

    v_prev_leg := v_leg.id;
    v_prev_arrival := v_leg.arrives;
    v_prev_city := v_leg.to_city;
  end loop;

  -- Where the last movement left him. Home when it was the return; otherwise a
  -- residence with no end yet — which is exactly the ordinary state of a man in
  -- the middle of his season.
  --
  -- This one CAN only use the arrival city: there is no next movement to ask.
  -- So a man who has landed at جدة and has nothing booked onward reads as being
  -- in جدة, which is the honest limit of what the record says — and the stay is
  -- editable, so the office can name مكة and its hotel the moment it knows.
  if v_prev_leg is not null then
    select case when l.role = 'outbound' then 'home' else 'residence' end
      into v_kind
      from journey_legs l where l.id = v_prev_leg;

    insert into journey_stays
      (participant_id, kind, city_item_id, city_name,
       arrived_at, departed_at, arrival_leg_id, sort_order)
    values
      (p_participant_id, coalesce(v_kind, 'residence'),
       travel_city_item(v_prev_city), v_prev_city, v_prev_arrival, null,
       v_prev_leg, v_made)
    on conflict do nothing;
    if found then v_made := v_made + 1; end if;
  end if;

  return v_made;
end;
$$;

revoke execute on function ensure_participant_stays(uuid) from public, anon;
grant execute on function ensure_participant_stays(uuid) to authenticated;

-- ==================================================== 6. reading the itinerary

create or replace function employee_stays(p_participant_id uuid)
  returns table (
    stay_id uuid,
    kind stay_kind,
    city_item_id uuid,
    city_ar text,
    city_en text,
    place_item_id uuid,
    place_ar text,
    place_en text,
    arrived_at timestamptz,
    departed_at timestamptz,
    arrival_leg_id uuid,
    departure_leg_id uuid,
    note text,
    nights integer,
    check_in_count integer
  )
  language sql
  stable
  set search_path = public
as $$
  select
    s.id,
    s.kind,
    s.city_item_id,
    coalesce(ci.name_ar, s.city_name),
    ci.name_en,
    s.place_item_id,
    pi.name_ar,
    pi.name_en,
    s.arrived_at,
    s.departed_at,
    s.arrival_leg_id,
    s.departure_leg_id,
    s.note,
    -- How long he was there, which is the number the whole restructure exists
    -- to put on the page. Counted to NOW for a stay still running, because
    -- "18 days so far" is the true answer and a blank is not.
    -- Date minus date, which Postgres answers in whole days. Not a subtraction
    -- of timestamps: that is an interval, and «كم يوماً» has never meant a
    -- count of 24-hour blocks — a man who lands at 23:00 and leaves at 07:00
    -- two mornings later spent two days there, not one.
    case
      when s.arrived_at is null then null
      else greatest(0, coalesce(s.departed_at, now())::date - s.arrived_at::date)
    end,
    -- What the attendance register already knows about this place, over this
    -- stay's own window. Nothing is written by either feature into the other;
    -- they simply agree about which row a hotel is.
    (select count(*)::integer
       from place_check_ins ci2
       join season_participants sp2 on sp2.id = s.participant_id
      where ci2.item_id = s.place_item_id
        and ci2.profile_id = sp2.profile_id
        and (s.arrived_at is null or ci2.created_at >= s.arrived_at)
        and (s.departed_at is null or ci2.created_at <= s.departed_at))
  from journey_stays s
  left join reference_items ci on ci.id = s.city_item_id
  left join reference_items pi on pi.id = s.place_item_id
  where s.participant_id = p_participant_id
  order by s.arrived_at nulls first, s.sort_order
$$;

comment on function employee_stays(uuid) is
  'Where a participant was based and for how long, in order. The spine of his '
  'season; employee_journey supplies the movements between these.';

-- ==================================================== 7. the acts on a stay

create or replace function set_stay_place(
  p_stay_id uuid,
  p_place_item_id uuid,
  p_note text default null
) returns void
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_owner uuid;
begin
  select sp.profile_id into v_owner
    from journey_stays s
    join season_participants sp on sp.id = s.participant_id
   where s.id = p_stay_id;

  if v_owner is null then
    raise exception 'no such stay' using errcode = 'no_data_found';
  end if;

  -- Naming his own مسكن is allowed to the man himself, on the same reasoning as
  -- confirming his own arrival (0130): for most of the roster nobody in the
  -- office is going to type four hundred hotel names, and he knows which one he
  -- is in. What he still cannot do is move himself between flights.
  if not (is_admin()
          or has_permission('travel.edit')
          or has_permission('travel.assign')
          or v_owner = auth.uid()) then
    raise exception 'not allowed to change this stay'
      using errcode = 'insufficient_privilege';
  end if;

  update journey_stays
     set place_item_id = p_place_item_id,
         note = coalesce(nullif(btrim(coalesce(p_note, '')), ''), note),
         updated_at = now(),
         updated_by = auth.uid()
   where id = p_stay_id;
end;
$$;

revoke execute on function set_stay_place(uuid, uuid, text) from public, anon;
grant execute on function set_stay_place(uuid, uuid, text) to authenticated;

-- A stay nothing carried him to: the man already resident in the Kingdom, and
-- the المشاعر days somebody wants on the record. No legs involved, so nothing
-- would ever have created it.
create or replace function add_stay(
  p_participant_id uuid,
  p_kind text,
  p_city_item_id uuid default null,
  p_place_item_id uuid default null,
  p_arrived_at timestamptz default null,
  p_departed_at timestamptz default null,
  p_note text default null
) returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_owner uuid;
  v_id uuid;
begin
  select profile_id into v_owner
    from season_participants where id = p_participant_id;
  if v_owner is null then
    raise exception 'no such participation' using errcode = 'no_data_found';
  end if;

  if not (is_admin()
          or has_permission('travel.edit')
          or has_permission('travel.assign')
          or v_owner = auth.uid()) then
    raise exception 'not allowed to record a stay for this person'
      using errcode = 'insufficient_privilege';
  end if;

  insert into journey_stays
    (participant_id, kind, city_item_id, place_item_id,
     arrived_at, departed_at, note, sort_order, created_by, updated_by)
  values
    (p_participant_id, p_kind::stay_kind, p_city_item_id, p_place_item_id,
     p_arrived_at, p_departed_at, nullif(btrim(coalesce(p_note, '')), ''),
     coalesce((select max(sort_order) + 1 from journey_stays
                where participant_id = p_participant_id), 0),
     auth.uid(), auth.uid())
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute on function add_stay(
  uuid, text, uuid, uuid, timestamptz, timestamptz, text) from public, anon;
grant execute on function add_stay(
  uuid, text, uuid, uuid, timestamptz, timestamptz, text) to authenticated;

create or replace function delete_stay(p_stay_id uuid) returns void
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  if not (is_admin() or has_permission('travel.edit')) then
    raise exception 'not allowed to delete a stay'
      using errcode = 'insufficient_privilege';
  end if;
  delete from journey_stays where id = p_stay_id;
end;
$$;

revoke execute on function delete_stay(uuid) from public, anon;
grant execute on function delete_stay(uuid) to authenticated;

-- ============================================ 8. which مسكن a city may offer
--
-- The hotels already say which city they are in — `data->>'city'` holds a
-- `saudi_cities` id (master data, entered long before this feature). So a مكة
-- stay can be offered مكة's hotels and no others without one new column.
--
-- Camps carry `site` (a holy site) rather than a city, and are offered for the
-- rites. Both are season-scoped, so only this season's contracted list appears.

create or replace function places_for_stay(
  p_city_item_id uuid,
  p_season_id uuid default null
) returns table (
    id uuid,
    name_ar text,
    name_en text,
    set_code text
  )
  language sql
  stable
  set search_path = public
as $$
  select ri.id, ri.name_ar, ri.name_en, rs.code
  from reference_items ri
  join reference_sets rs on rs.id = ri.set_id
  where rs.is_place
    and ri.is_active
    and (ri.season_id is null
         or ri.season_id = coalesce(
              p_season_id, (select id from seasons where is_current)))
    and (
      p_city_item_id is null
      -- A hotel names its city; a camp names its مشعر, and is offered when the
      -- stay itself is at that مشعر.
      or (ri.data ->> 'city')::uuid = p_city_item_id
      or (ri.data ->> 'site')::uuid = p_city_item_id
    )
  order by rs.code, ri.sort_order, ri.name_ar
$$;

-- ================================================================= 9. who sees

alter table journey_stays enable row level security;

-- The same shape as a leg (0129): his own always, the register to whoever keeps
-- it. A man must be able to read where he is being housed.
drop policy if exists journey_stays_select on journey_stays;
create policy journey_stays_select on journey_stays for select using (
  is_admin()
  or has_permission('travel.view')
  or exists (
    select 1 from season_participants sp
     where sp.id = journey_stays.participant_id and sp.profile_id = auth.uid()
  )
);

-- Writes go through the functions above, which is where "he may name his own
-- hotel but not move himself between flights" is written down. The policies
-- cover the office's direct edits.
drop policy if exists journey_stays_write on journey_stays;
create policy journey_stays_write on journey_stays for all
  using (is_admin() or has_permission('travel.edit')
         or has_permission('travel.assign'))
  with check (is_admin() or has_permission('travel.edit')
              or has_permission('travel.assign'));

-- ================================================================ 10. the record

drop trigger if exists audit_row on journey_stays;
create trigger audit_row after insert or update or delete on journey_stays
  for each row execute function audit_row_change();

-- Restated whole on top of 0129's version — the body is one CASE and Postgres
-- has no way to add an arm to it.
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
    when 'module_node_members' then
      concat_ws(' — ',
        audit_actor_name((p_row ->> 'profile_id')::uuid),
        (select label from module_nodes where id = (p_row ->> 'node_id')::uuid))
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
    -- New in 0135. Whose stay, and where — the man first, as everywhere else.
    when 'journey_stays' then
      concat_ws(' — ',
        (select audit_actor_name(sp.profile_id) from season_participants sp
          where sp.id = (p_row ->> 'participant_id')::uuid),
        coalesce(
          (select ri.name_ar from reference_items ri
            where ri.id = (p_row ->> 'place_item_id')::uuid),
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

-- ===================================== 11. the spine follows the movements
--
-- Assignment and self-recorded movements both rebuild the stays afterwards, so
-- nobody has to remember to. Restated whole for the same reason as above.

create or replace function assign_to_trip(
  p_trip_id uuid,
  p_participant_ids uuid[]
) returns jsonb
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_trip trips;
  v_participant uuid;
  v_existing_id uuid;
  v_existing_status leg_status;
  v_assigned int := 0;
  v_rebooked int := 0;
  v_skipped int := 0;
  v_new_leg uuid;
begin
  if not (is_admin() or has_permission('travel.assign')) then
    raise exception 'not allowed to assign travel'
      using errcode = 'insufficient_privilege';
  end if;

  select * into v_trip from trips where id = p_trip_id;
  if v_trip.id is null then
    raise exception 'no such trip' using errcode = 'no_data_found';
  end if;

  foreach v_participant in array coalesce(p_participant_ids, '{}'::uuid[]) loop
    if exists (
      select 1 from journey_legs l
       where l.participant_id = v_participant
         and l.trip_id = p_trip_id
         and l.status in ('planned', 'confirmed', 'completed')
    ) then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_existing_id := null;
    v_existing_status := null;
    if v_trip.role in ('inbound', 'outbound') then
      select l.id, l.status into v_existing_id, v_existing_status
        from journey_legs l
       where l.participant_id = v_participant
         and l.role = v_trip.role
         and l.status in ('planned', 'confirmed', 'completed')
       limit 1;
    end if;

    if v_existing_status = 'completed' then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    if v_existing_id is not null then
      update journey_legs
         set status = 'rebooked', updated_at = now(), updated_by = auth.uid()
       where id = v_existing_id;
      v_rebooked := v_rebooked + 1;
    end if;

    insert into journey_legs
      (participant_id, trip_id, role, status, replaces_leg_id, created_by,
       updated_by)
    values
      (v_participant, p_trip_id, v_trip.role, 'planned', v_existing_id,
       auth.uid(), auth.uid())
    returning id into v_new_leg;

    v_assigned := v_assigned + 1;

    insert into notifications (recipient_id, sender_id, title, body, data)
    select sp.profile_id, auth.uid(),
           case v_trip.role
             when 'inbound'  then 'أُسندت إليك رحلة القدوم'
             when 'outbound' then 'أُسندت إليك رحلة العودة'
             else 'أُسندت إليك حركة تنقّل'
           end,
           concat_ws(' — ',
             nullif(btrim(coalesce(v_trip.trip_number, '')), ''),
             to_char(v_trip.planned_departure_at, 'YYYY-MM-DD HH24:MI')),
           jsonb_build_object('type', 'travel_assigned', 'leg_id', v_new_leg,
                              'trip_id', p_trip_id)
    from season_participants sp
    where sp.id = v_participant;

    -- New in 0135: the itinerary follows the movements. A man put on a flight
    -- to جدة now has a مكة stay waiting for its hotel, rather than nothing at
    -- all until somebody notices.
    perform ensure_participant_stays(v_participant);
  end loop;

  return jsonb_build_object(
    'assigned', v_assigned, 'rebooked', v_rebooked, 'skipped', v_skipped);
end;
$$;

create or replace function record_self_leg(
  p_participant_id uuid,
  p_role text,
  p_mode text,
  p_from_point_id uuid,
  p_to_point_id uuid,
  p_departure_at timestamptz,
  p_arrival_at timestamptz default null,
  p_note text default null,
  p_completed boolean default true
) returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_owner uuid;
  v_role leg_role := p_role::leg_role;
  v_leg uuid;
begin
  select profile_id into v_owner
    from season_participants where id = p_participant_id;

  if v_owner is null then
    raise exception 'no such participation' using errcode = 'no_data_found';
  end if;

  if not (is_admin()
          or has_permission('travel.assign')
          or has_permission('travel.confirm')
          or v_owner = auth.uid()) then
    raise exception 'not allowed to record travel for this person'
      using errcode = 'insufficient_privilege';
  end if;

  if v_role in ('inbound', 'outbound') then
    update journey_legs
       set status = 'rebooked', updated_at = now(), updated_by = auth.uid()
     where participant_id = p_participant_id
       and role = v_role
       and status in ('planned', 'confirmed');
  end if;

  insert into journey_legs
    (participant_id, trip_id, role, mode, from_point_id, to_point_id,
     planned_departure_at, actual_departure_at, actual_arrival_at,
     status, note, confirmed_by, confirmed_at, created_by, updated_by)
  values
    (p_participant_id, null, v_role, p_mode::travel_mode,
     p_from_point_id, p_to_point_id,
     p_departure_at,
     case when p_completed then p_departure_at end,
     case when p_completed then coalesce(p_arrival_at, p_departure_at) end,
     case when p_completed then 'completed' else 'planned' end::leg_status,
     nullif(btrim(coalesce(p_note, '')), ''),
     case when p_completed then auth.uid() end,
     case when p_completed then now() end,
     auth.uid(), auth.uid())
  returning id into v_leg;

  perform ensure_participant_stays(p_participant_id);

  return v_leg;
end;
$$;

-- ==================================== 12. the spine for everybody, right now
--
-- Every participation that already has movements gets its stays built, so the
-- feature does not read as empty for the season that is running while this
-- migration lands.

do $$
declare
  v_p uuid;
  v_total int := 0;
begin
  for v_p in
    select distinct participant_id from journey_legs
  loop
    v_total := v_total + ensure_participant_stays(v_p);
  end loop;
  raise notice 'built % stays from existing movements', v_total;
end
$$;
