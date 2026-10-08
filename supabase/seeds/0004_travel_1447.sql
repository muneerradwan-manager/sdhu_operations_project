-- ============================================================================
-- رحلات الموسم — موسم 1447
--
-- NOT a migration. It writes CONTENT — three journeys and the whole roster on
-- them — and content belongs under seeds, where nothing runs against a database
-- by accident. Run it by hand in the SQL editor.
--
-- ---------------------------------------------------------------- WHAT IT DOES
--
-- Creates the three movements a season is made of and puts every ACTIVE
-- participant of 1447 on all three:
--
--   ١  رحلة القدوم    مطار دمشق الدولي → مطار الملك عبدالعزيز الدولي
--   ٢  التنقّل الداخلي  محطة مكة المكرمة → محطة المدينة المنورة  (بالقطار)
--   ٣  رحلة العودة    مطار الأمير محمد بن عبدالعزيز → مطار دمشق الدولي
--
-- The first two are dated in the past and marked `completed`; the return is
-- dated three days out and left `planned`. That is what makes the feature
-- legible the moment it is opened: every man's timeline reads «الآن في المدينة
-- المنورة · العودة بعد ٣ أيام» instead of showing three grey outlines.
--
-- ------------------------------------------------------------- READ THIS FIRST
--
-- **It marks arrivals as having happened, for real people.** `completed` on a
-- leg is the app saying "this man travelled on this date", and nothing here
-- knows whether he did. That is acceptable for a seed and would not be
-- acceptable for anything else, so it is said plainly here rather than left to
-- be discovered.
--
-- The alternative was worse in a specific way: three legs dated in the past and
-- left unconfirmed would put roughly three hundred and twenty rows on the gaps
-- board on the morning it was first opened, and a board that opens full of
-- noise is a board nobody opens twice.
--
-- ------------------------------------------------------------------ UNDOING IT
--
-- Every trip it writes carries a number beginning `SEED-`, so it comes out
-- cleanly and takes its legs with it:
--
--   delete from journey_legs
--    where trip_id in (select id from trips where trip_number like 'SEED-%');
--   delete from trips where trip_number like 'SEED-%';
--
-- (The legs must go first — 0129 refuses to delete a trip anybody is still on,
-- which is BR-11 doing its job.)
--
-- ------------------------------------------------------------------ IDEMPOTENT
--
-- Re-running it changes nothing: the trips are keyed on their `SEED-` number
-- and each participant is skipped if he already holds a live leg of that role,
-- which is the same rule the unique index enforces (BR-10).
-- ============================================================================

do $$
declare
  v_season uuid;
  v_damascus uuid;
  v_jeddah uuid;
  v_madinah_air uuid;
  v_makkah_st uuid;
  v_madinah_st uuid;
  v_inbound uuid;
  v_internal uuid;
  v_outbound uuid;
  v_people int;
begin
  select id into v_season from seasons where hijri_year = 1447;
  if v_season is null then
    raise exception 'season 1447 does not exist';
  end if;

  -- The points, by the names 0129/0133 seeded them under.
  select ri.id into v_damascus from reference_items ri
    join reference_sets rs on rs.id = ri.set_id
   where rs.code = 'travel_points' and ri.name_ar = 'مطار دمشق الدولي';
  select ri.id into v_jeddah from reference_items ri
    join reference_sets rs on rs.id = ri.set_id
   where rs.code = 'travel_points'
     and ri.name_ar = 'مطار الملك عبدالعزيز الدولي';
  select ri.id into v_madinah_air from reference_items ri
    join reference_sets rs on rs.id = ri.set_id
   where rs.code = 'travel_points'
     and ri.name_ar = 'مطار الأمير محمد بن عبدالعزيز';
  select ri.id into v_makkah_st from reference_items ri
    join reference_sets rs on rs.id = ri.set_id
   where rs.code = 'travel_points' and ri.name_ar = 'محطة مكة المكرمة';
  select ri.id into v_madinah_st from reference_items ri
    join reference_sets rs on rs.id = ri.set_id
   where rs.code = 'travel_points' and ri.name_ar = 'محطة المدينة المنورة';

  if v_damascus is null or v_jeddah is null or v_madinah_air is null
     or v_makkah_st is null or v_madinah_st is null then
    raise exception
      'the travel points of 0129/0133 are missing — run the migrations first';
  end if;

  -- ------------------------------------------------------------ 1. the trips

  select id into v_inbound from trips
   where season_id = v_season and trip_number = 'SEED-IN-1447';
  if v_inbound is null then
    insert into trips (season_id, mode, role, from_point_id, to_point_id,
                       trip_number, planned_departure_at, planned_arrival_at,
                       status, note)
    values (v_season, 'air', 'inbound', v_damascus, v_jeddah,
            'SEED-IN-1447',
            now() - interval '30 days',
            now() - interval '30 days' + interval '3 hours',
            'arrived', 'بيانات تجريبية — رحلة القدوم')
    returning id into v_inbound;
  end if;

  select id into v_internal from trips
   where season_id = v_season and trip_number = 'SEED-INT-1447';
  if v_internal is null then
    insert into trips (season_id, mode, role, from_point_id, to_point_id,
                       trip_number, planned_departure_at, planned_arrival_at,
                       status, note)
    values (v_season, 'rail', 'internal', v_makkah_st, v_madinah_st,
            'SEED-INT-1447',
            now() - interval '10 days',
            now() - interval '10 days' + interval '3 hours',
            'arrived', 'بيانات تجريبية — التنقّل الداخلي بالقطار')
    returning id into v_internal;
  end if;

  select id into v_outbound from trips
   where season_id = v_season and trip_number = 'SEED-OUT-1447';
  if v_outbound is null then
    insert into trips (season_id, mode, role, from_point_id, to_point_id,
                       trip_number, planned_departure_at, planned_arrival_at,
                       status, note)
    values (v_season, 'air', 'outbound', v_madinah_air, v_damascus,
            'SEED-OUT-1447',
            now() + interval '3 days',
            now() + interval '3 days' + interval '3 hours',
            'scheduled', 'بيانات تجريبية — رحلة العودة')
    returning id into v_outbound;
  end if;

  -- ------------------------------------------------------- 2. the whole roster
  --
  -- `travels` is respected even here: anybody already marked as not travelling
  -- is left off, which is the flag doing exactly what it exists for.
  --
  -- The `not exists` guard is what makes this re-runnable, and it is the same
  -- question the unique index asks (BR-10): one live leg per role.
  --
  -- `confirmed_by` and `confirmed_at` are left NULL, and the first attempt at
  -- this seed is why. Stamping a confirmation time with no confirmer was
  -- refused outright by `leg_confirmation_is_attributed` (0129) — "a
  -- confirmation without a confirmer is an assertion from nowhere" — and the
  -- alternative, naming a real administrator as having confirmed three hundred
  -- arrivals he never saw, is exactly the lie that constraint exists to
  -- prevent. So these legs say the movement completed and say nobody vouched
  -- for it, which is the truth about seeded data.

  insert into journey_legs (participant_id, trip_id, role, status,
                            actual_departure_at, actual_arrival_at)
  select sp.id, v_inbound, 'inbound', 'completed',
         now() - interval '30 days',
         now() - interval '30 days' + interval '3 hours'
    from season_participants sp
   where sp.season_id = v_season and sp.status = 'active' and sp.travels
     and not exists (
       select 1 from journey_legs l
        where l.participant_id = sp.id and l.role = 'inbound'
          and l.status in ('planned', 'confirmed', 'completed'));

  insert into journey_legs (participant_id, trip_id, role, status,
                            actual_departure_at, actual_arrival_at)
  select sp.id, v_internal, 'internal', 'completed',
         now() - interval '10 days',
         now() - interval '10 days' + interval '3 hours'
    from season_participants sp
   where sp.season_id = v_season and sp.status = 'active' and sp.travels
     and not exists (
       select 1 from journey_legs l
        where l.participant_id = sp.id and l.trip_id = v_internal
          and l.status in ('planned', 'confirmed', 'completed'));

  -- The return is NOT confirmed: it has not happened. This is the row that
  -- makes the countdown appear, and the one the reminder pass in 0131 will pick
  -- up at the 48-hour mark.
  insert into journey_legs (participant_id, trip_id, role, status)
  select sp.id, v_outbound, 'outbound', 'planned'
    from season_participants sp
   where sp.season_id = v_season and sp.status = 'active' and sp.travels
     and not exists (
       select 1 from journey_legs l
        where l.participant_id = sp.id and l.role = 'outbound'
          and l.status in ('planned', 'confirmed', 'completed'));

  select count(*) into v_people
    from season_participants sp
   where sp.season_id = v_season and sp.status = 'active' and sp.travels;

  raise notice 'season 1447: three trips, % participants on each', v_people;
end
$$;
