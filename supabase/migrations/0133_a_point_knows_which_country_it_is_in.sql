-- A point knows which country it is in, and a movement knows what may carry it.
--
-- 0129 seeded nine travel points and left them undifferentiated, so the trip
-- form offered every one of them for every field and every mode for every role.
-- That is wrong in a way worse than untidy: a form that will accept «رحلة
-- القدوم — من: مكة المكرمة، إلى: مطار حلب، بالقطار» is a form that will
-- eventually be given exactly that, by somebody in a hurry at two in the
-- morning.
--
-- The rules the office actually works to, written down:
--
--   رحلة القدوم    طيران.  من مطار سوري  → إلى مطار سعودي
--   رحلة العودة    طيران.  من مطار سعودي → إلى مطار سوري
--   تنقّل داخلي     قطار أو سيارة أو وسيلة أخرى — never a flight — and between
--                  مكة المكرمة and المدينة المنورة, which is the only seasonal
--                  movement inside the Kingdom this mission makes.
--
-- Three facts are needed to say all that and none is derivable from a name:
-- which country a point is in, what kind of place it is, and which city it
-- serves. All three are recorded here.
--
-- --------------------------------------------------- why fields and not columns
--
-- `travel_points` is a reference list, and master data is schema-driven: a
-- field declared in `reference_set_fields` renders, validates, saves, displays
-- and audits itself with no Dart written for it (0098 makes the argument at
-- length about `check_in_radius_m`). Columns would need bespoke widgets in the
-- editor and the detail screen both.
--
-- What a schema field cannot give is a CLOSED set of values — there is no
-- `choice` in `module_field_kind` — and these are read by code, not merely
-- shown. A country miskeyed as «SAU» would not fail; it would quietly drop
-- مطار الملك عبدالعزيز out of every arrival form in the app. So the values are
-- held to by a trigger, which is the part a text field cannot do for itself.
--
-- ------------------------------------------------ and why triggers, not just UI
--
-- The form filters its pickers so a wrong pairing cannot be CHOSEN. The
-- triggers at the foot of this file are what stop one being WRITTEN — by an
-- import, by a script, by a future screen that forgot. The UI is a courtesy;
-- the trigger is the rule.

-- ============================================================== 1. the fields

insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, is_required, sort_order)
select rs.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
       v.is_required, v.sort_order
from (values
  ('country_code', 'الدولة (SY / SA)', 'Country (SY / SA)', 'text', true, 2),
  ('point_kind', 'النوع (airport / station / city)',
   'Kind (airport / station / city)', 'text', true, 3)
) as v(key, label_ar, label_en, kind, is_required, sort_order)
cross join reference_sets rs
where rs.code = 'travel_points'
on conflict (set_id, key) do nothing;

-- `city` already exists from 0129 and now carries weight: it is what decides
-- whether a point may stand at either end of a تنقّل داخلي.
update reference_set_fields f
   set is_required = true,
       label_ar = 'المدينة',
       label_en = 'City'
  from reference_sets rs
 where rs.id = f.set_id and rs.code = 'travel_points' and f.key = 'city';

-- ================================================================ 2. the nine
--
-- Matched on the Arabic name, the natural key of a reference entry
-- (`unique (set_id, name_ar)` since 0017). Written as a MERGE into `data` so
-- re-running this migration is harmless and anything an administrator has added
-- to these rows meanwhile survives.

update reference_items ri
   set data = coalesce(ri.data, '{}'::jsonb) || v.patch
  from (values
    ('مطار دمشق الدولي',
     '{"country_code":"SY","point_kind":"airport","city":"دمشق"}'::jsonb),
    ('مطار حلب الدولي',
     '{"country_code":"SY","point_kind":"airport","city":"حلب"}'::jsonb),
    ('مطار الملك عبدالعزيز الدولي',
     '{"country_code":"SA","point_kind":"airport","city":"جدة"}'::jsonb),
    ('مطار الأمير محمد بن عبدالعزيز',
     '{"country_code":"SA","point_kind":"airport","city":"المدينة المنورة"}'::jsonb),
    ('محطة مكة المكرمة',
     '{"country_code":"SA","point_kind":"station","city":"مكة المكرمة"}'::jsonb),
    ('محطة المدينة المنورة',
     '{"country_code":"SA","point_kind":"station","city":"المدينة المنورة"}'::jsonb),
    ('مكة المكرمة',
     '{"country_code":"SA","point_kind":"city","city":"مكة المكرمة"}'::jsonb),
    ('المدينة المنورة',
     '{"country_code":"SA","point_kind":"city","city":"المدينة المنورة"}'::jsonb),
    ('جدة',
     '{"country_code":"SA","point_kind":"city","city":"جدة"}'::jsonb)
  ) as v(name_ar, patch)
  join reference_sets rs on rs.code = 'travel_points'
 where ri.set_id = rs.id
   and ri.name_ar = v.name_ar;

-- The Kingdom's other international airports, so that «مطارات السعودية كلها» is
-- true of this list rather than of جدة and المدينة alone: a returning charter
-- does not always leave from the airport it arrived at.
insert into reference_items (set_id, name_ar, name_en, sort_order, data)
select rs.id, v.name_ar, v.name_en, v.sort_order, v.data
from (values
  ('مطار الملك خالد الدولي', 'King Khalid International Airport', 10,
   '{"country_code":"SA","point_kind":"airport","city":"الرياض"}'::jsonb),
  ('مطار الملك فهد الدولي', 'King Fahd International Airport', 11,
   '{"country_code":"SA","point_kind":"airport","city":"الدمام"}'::jsonb),
  ('مطار الطائف الدولي', 'Taif International Airport', 12,
   '{"country_code":"SA","point_kind":"airport","city":"الطائف"}'::jsonb),
  ('مطار ينبع', 'Yanbu Airport', 13,
   '{"country_code":"SA","point_kind":"airport","city":"ينبع"}'::jsonb),
  ('مطار حائل', 'Hail Airport', 14,
   '{"country_code":"SA","point_kind":"airport","city":"حائل"}'::jsonb),
  -- Syria's third international airport, for the same reason.
  ('مطار اللاذقية الدولي', 'Lattakia International Airport', 15,
   '{"country_code":"SY","point_kind":"airport","city":"اللاذقية"}'::jsonb)
) as v(name_ar, name_en, sort_order, data)
cross join reference_sets rs
where rs.code = 'travel_points'
-- Untargeted: the uniqueness of a reference entry's name is an EXPRESSION index
-- (`uq_reference_items_name_per_season`, which folds in the season and the
-- variant), and an expression index cannot be named in an ON CONFLICT target.
on conflict do nothing;

-- ========================================================= 3. holding the set

create or replace function travel_point_values_are_known() returns trigger
  language plpgsql
  set search_path = public as $$
declare
  v_code text;
  v_country text;
  v_kind text;
begin
  select code into v_code from reference_sets where id = new.set_id;
  if v_code is distinct from 'travel_points' then
    return new;
  end if;

  v_country := new.data ->> 'country_code';
  v_kind := new.data ->> 'point_kind';

  if v_country is null or v_country not in ('SY', 'SA') then
    raise exception
      'a travel point must say which country it is in: SY or SA'
      using errcode = 'check_violation';
  end if;

  if v_kind is null or v_kind not in ('airport', 'station', 'city') then
    raise exception
      'a travel point must say what it is: airport, station or city'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists travel_points_are_known on reference_items;
create trigger travel_points_are_known
  before insert or update on reference_items
  for each row execute function travel_point_values_are_known();

-- ==================================================== 4. the two holy cities
--
-- Which points a تنقّل داخلي may run between, in one place because the form and
-- the trigger must not be able to disagree about it.
--
-- Matched on the CITY rather than on a flag of its own, and that is deliberate:
-- a second station or a second pick-up point in مكة added to the list next year
-- becomes available to internal movements the moment somebody enters it, with
-- no migration and nobody remembering to tick a box.
--
-- Airports are excluded even when they stand in the right city, and مطار الأمير
-- محمد بن عبدالعزيز is exactly why the exclusion is written down: it IS in
-- المدينة المنورة, so a rule that asked only about the city would offer it as
-- the destination of a car from مكة. An internal movement of this mission ends
-- at the station or in the city; a man going to that airport is starting his
-- رحلة عودة, which is a different row with a different set of rules.
create or replace function is_internal_travel_point(p_item_id uuid)
  returns boolean
  language sql stable set search_path = public as $$
  select coalesce(
    (select ri.data ->> 'city' in ('مكة المكرمة', 'المدينة المنورة')
       and ri.data ->> 'country_code' = 'SA'
       and ri.data ->> 'point_kind' <> 'airport'
     from reference_items ri where ri.id = p_item_id),
    false)
$$;

-- ============================================ 5. what a movement may look like
--
-- One function, used by both triggers, because a trip and a self-arranged leg
-- are the same claim about the world and must be judged identically.
--
-- A point with no country recorded predates this migration or was written
-- around the trigger above; such a movement is left alone rather than refused.
-- This is not the place to fail a season's data entry over a list somebody has
-- not finished filling in.
create or replace function travel_shape_is_sane(
  p_role leg_role,
  p_mode travel_mode,
  p_from uuid,
  p_to uuid
) returns void
  language plpgsql stable set search_path = public as $$
declare
  v_from text;
  v_to text;
  v_from_kind text;
  v_to_kind text;
begin
  select data ->> 'country_code', data ->> 'point_kind'
    into v_from, v_from_kind
    from reference_items where id = p_from;
  select data ->> 'country_code', data ->> 'point_kind'
    into v_to, v_to_kind
    from reference_items where id = p_to;

  if v_from is null or v_to is null then
    return;
  end if;

  if p_role in ('inbound', 'outbound') then
    -- Between the two countries there is one way to travel, and the mission has
    -- never used another.
    if p_mode <> 'air' then
      raise exception 'an arrival or a return is a flight'
        using errcode = 'check_violation';
    end if;
    if v_from_kind <> 'airport' or v_to_kind <> 'airport' then
      raise exception 'a flight runs between airports'
        using errcode = 'check_violation';
    end if;
  end if;

  if p_role = 'inbound' and (v_from <> 'SY' or v_to <> 'SA') then
    raise exception 'an arrival must leave Syria and land in the Kingdom'
      using errcode = 'check_violation';
  end if;

  if p_role = 'outbound' and (v_from <> 'SA' or v_to <> 'SY') then
    raise exception 'a return must leave the Kingdom and land in Syria'
      using errcode = 'check_violation';
  end if;

  if p_role = 'internal' then
    -- Never a flight. Nobody in this mission flies مكة to المدينة, and offering
    -- it would put an aeroplane on a timeline where a car belongs.
    if p_mode = 'air' then
      raise exception 'an internal movement is not a flight'
        using errcode = 'check_violation';
    end if;
    if not (is_internal_travel_point(p_from)
            and is_internal_travel_point(p_to)) then
      raise exception
        'an internal movement runs between مكة المكرمة and المدينة المنورة'
        using errcode = 'check_violation';
    end if;
  end if;
end;
$$;

create or replace function trip_shape_is_sane() returns trigger
  language plpgsql set search_path = public as $$
begin
  perform travel_shape_is_sane(
    new.role, new.mode, new.from_point_id, new.to_point_id);
  return new;
end;
$$;

drop trigger if exists trips_shape_is_sane on trips;
create trigger trips_shape_is_sane before insert or update on trips
  for each row execute function trip_shape_is_sane();

-- The same for a movement a man arranged himself, which carries its own mode
-- and its own two points when it has no trip behind it (BR-4). A leg WITH a
-- trip carries none of them and is already judged through the trip.
create or replace function leg_shape_is_sane() returns trigger
  language plpgsql set search_path = public as $$
begin
  if new.trip_id is not null then
    return new;
  end if;
  perform travel_shape_is_sane(
    new.role, new.mode, new.from_point_id, new.to_point_id);
  return new;
end;
$$;

drop trigger if exists journey_legs_shape_is_sane on journey_legs;
create trigger journey_legs_shape_is_sane before insert or update on journey_legs
  for each row execute function leg_shape_is_sane();
