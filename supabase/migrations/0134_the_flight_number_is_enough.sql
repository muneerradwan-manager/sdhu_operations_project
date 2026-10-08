-- The flight number is enough.
--
-- 0129 gave a trip both a `trip_number` and a `carrier` — «SR441» and «الجدير
-- للطيران» — on the reasoning that a reader might want the airline as well as
-- the number. In use it turned out to be one field too many:
--
--   * The number already identifies the flight. It is what is printed on the
--     ticket, what the airport board shows, and what the office says out loud.
--   * The airline is derivable from it by anybody who needs it, and needed by
--     nobody who is reading this screen — the room asks "which flight", never
--     "which company".
--   * A second free-text field on a form entered forty times in a sitting is
--     forty more chances to type something that will be searched for later and
--     not found.
--
-- So it goes, while the table is still empty and going costs nothing. The
-- number stays.
--
-- Both read functions declare the column in their return type, so they cannot
-- be replaced in place — a `create or replace` may not change a function's
-- shape. They are dropped and rebuilt, unchanged apart from the missing column.

drop function if exists season_trips(uuid);
drop function if exists employee_journey(uuid);

alter table trips drop column if exists carrier;

-- ================================================== employee_journey, rebuilt

create or replace function employee_journey(p_participant_id uuid)
  returns table (
    leg_id uuid,
    trip_id uuid,
    role leg_role,
    mode travel_mode,
    from_point_id uuid,
    from_point_ar text,
    from_point_en text,
    to_point_id uuid,
    to_point_ar text,
    to_point_en text,
    trip_number text,
    planned_departure_at timestamptz,
    planned_arrival_at timestamptz,
    actual_departure_at timestamptz,
    actual_arrival_at timestamptz,
    status leg_status,
    vehicle_status trip_status,
    ticket_ref text,
    seat text,
    note text,
    replaces_leg_id uuid,
    confirmed_by uuid,
    confirmed_by_name text,
    confirmed_at timestamptz,
    self_arranged boolean,
    attachment_count integer
  )
  language sql
  stable
  set search_path = public
as $$
  select
    l.id,
    l.trip_id,
    l.role,
    coalesce(t.mode, l.mode),
    coalesce(t.from_point_id, l.from_point_id),
    fp.name_ar,
    fp.name_en,
    coalesce(t.to_point_id, l.to_point_id),
    tp.name_ar,
    tp.name_en,
    t.trip_number,
    coalesce(t.planned_departure_at, l.planned_departure_at),
    coalesce(t.planned_arrival_at, l.planned_arrival_at),
    l.actual_departure_at,
    l.actual_arrival_at,
    l.status,
    t.status,
    l.ticket_ref,
    l.seat,
    l.note,
    l.replaces_leg_id,
    l.confirmed_by,
    audit_actor_name(l.confirmed_by),
    l.confirmed_at,
    l.trip_id is null,
    (select count(*)::integer from leg_attachments la where la.leg_id = l.id)
  from journey_legs l
  left join trips t on t.id = l.trip_id
  left join reference_items fp
    on fp.id = coalesce(t.from_point_id, l.from_point_id)
  left join reference_items tp
    on tp.id = coalesce(t.to_point_id, l.to_point_id)
  where l.participant_id = p_participant_id
  order by coalesce(t.planned_departure_at, l.planned_departure_at),
           l.created_at
$$;

comment on function employee_journey(uuid) is
  'The resolved legs of one participation, in planned time order. Derivations '
  '(where he is now, what is next, days to return) are computed in the app '
  'from this list — deliberately not stored anywhere.';

-- ====================================================== season_trips, rebuilt

create or replace function season_trips(p_season_id uuid default null)
  returns table (
    id uuid,
    season_id uuid,
    mode travel_mode,
    role leg_role,
    from_point_id uuid,
    from_point_ar text,
    from_point_en text,
    to_point_id uuid,
    to_point_ar text,
    to_point_en text,
    trip_number text,
    planned_departure_at timestamptz,
    planned_arrival_at timestamptz,
    status trip_status,
    note text,
    assigned_count integer,
    completed_count integer,
    attachment_count integer
  )
  language sql
  stable
  set search_path = public
as $$
  select
    t.id,
    t.season_id,
    t.mode,
    t.role,
    t.from_point_id,
    fp.name_ar,
    fp.name_en,
    t.to_point_id,
    tp.name_ar,
    tp.name_en,
    t.trip_number,
    t.planned_departure_at,
    t.planned_arrival_at,
    t.status,
    t.note,
    (select count(*)::integer from journey_legs l
      where l.trip_id = t.id
        and l.status in ('planned', 'confirmed', 'completed')),
    (select count(*)::integer from journey_legs l
      where l.trip_id = t.id and l.status = 'completed'),
    (select count(*)::integer from trip_attachments a where a.trip_id = t.id)
  from trips t
  left join reference_items fp on fp.id = t.from_point_id
  left join reference_items tp on tp.id = t.to_point_id
  where t.season_id = coalesce(p_season_id, t.season_id)
  order by t.planned_departure_at
$$;

-- ------------------------------------------------------------- the label, too
--
-- `audit_record_label` names a trip by its number and its route; the carrier
-- was never in it, so nothing there changes. Restated only because 0129's
-- version is the one in place and this file is where a reader will look for
-- what the drop touched: it touched nothing else.
