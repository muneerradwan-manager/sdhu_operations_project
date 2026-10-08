-- The journey answers for itself.
--
-- 0129 built the two tables. This is how they are read and how they are
-- written, and both halves are here for the same reason: the interesting rules
-- of this feature are not in the columns, they are in the four acts — assigning
-- a group, moving somebody between flights, confirming what happened, and a man
-- recording a movement he arranged himself.
--
-- ------------------------------------------------- what is NOT in this file
--
-- There is no stored "current status" and there will not be one. Where a man is
-- now, which movement is next, how many days until he flies home — every one of
-- those is a function of the legs, and 0064 already wrote down what happens
-- when a derivable number is given a column of its own: it becomes a second
-- place for the answer to be wrong, and it goes wrong on the day somebody edits
-- a leg and nothing recomputes.
--
-- So `employee_journey` returns the RESOLVED LEGS — the trip's schedule and the
-- man's own facts already coalesced into one row each, in time order — and the
-- derivations are done in Dart, where they can be unit-tested against a list
-- without a database. The gaps board below is the other kind of question, asked
-- of everybody at once, and it stays in SQL where the set lives.
--
-- ------------------------------------------------------- reads run as caller
--
-- The read functions here are deliberately NOT `security definer`. RLS already
-- says exactly the right thing about travel — his own journey to any man, the
-- whole register to whoever holds `travel.view` — and a definer function would
-- mean restating that rule in a second place and keeping the two in step
-- forever. The acts ARE definer, because each of them enforces something RLS
-- cannot express: which COLUMNS a traveller may write on his own row.

-- ================================================== 1. one man's whole journey
--
-- One row per movement, in the order they happen, with the trip's half and the
-- leg's half already merged. `coalesce(t.x, l.x)` throughout, and it is never
-- ambiguous: BR-4 guarantees exactly one of the two is populated.

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
    carrier text,
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
    t.carrier,
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
  -- Planned time and not actual: the order a journey is READ in is the order it
  -- was meant to happen. A delayed flight does not move down the page.
  order by coalesce(t.planned_departure_at, l.planned_departure_at),
           l.created_at
$$;

comment on function employee_journey(uuid) is
  'The resolved legs of one participation, in planned time order. Derivations '
  '(where he is now, what is next, days to return) are computed in the app '
  'from this list — deliberately not stored anywhere.';

-- ============================================= 2. the season''s trips, counted
--
-- The count is the one number the board cannot do without: a flight is
-- interesting when it is full and alarming when it is empty two days out.
--
-- Live legs only. A trip that sixty people were moved OFF is not a trip with
-- sixty passengers, and the rebooked rows are kept precisely so that nobody has
-- to delete them to make this number right.

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
    carrier text,
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
    t.carrier,
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

-- ================================================ 3. who is on a given trip

create or replace function trip_passengers(p_trip_id uuid)
  returns table (
    leg_id uuid,
    participant_id uuid,
    profile_id uuid,
    full_name text,
    photo_url text,
    job_title_ar text,
    job_title_en text,
    status leg_status,
    ticket_ref text,
    seat text,
    actual_departure_at timestamptz,
    actual_arrival_at timestamptz,
    confirmed_at timestamptz
  )
  language sql
  stable
  set search_path = public
as $$
  select
    l.id,
    sp.id,
    p.id,
    nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
    p.photo_url,
    jt.name_ar,
    jt.name_en,
    l.status,
    l.ticket_ref,
    l.seat,
    l.actual_departure_at,
    l.actual_arrival_at,
    l.confirmed_at
  from journey_legs l
  join season_participants sp on sp.id = l.participant_id
  join profiles p on p.id = sp.profile_id
  left join reference_items jt on jt.id = p.job_title_id
  where l.trip_id = p_trip_id
    -- Those moved off it are kept in the table and left out of the manifest.
    -- The history is in the audit log and in `replaces_leg_id`, which is where
    -- somebody goes looking for it; a passenger list is a list of passengers.
    and l.status in ('planned', 'confirmed', 'completed')
  order by p.first_name, p.surname
$$;

-- ==================================================== 4. what is not answered
--
-- The screen the operations room actually opens every morning. It lists only
-- the unanswered, and every row on it has one obvious next action.
--
-- Four kinds, and the discipline is in which kinds are NOT here:
--
--   * A man with no train booking is not a gap. He may have gone by car, and
--     «بسيارة خاصة» is a complete answer (0129). What would be a gap is a
--     movement nobody recorded at all — but that cannot be told apart from a
--     movement that never needed to happen, so it is shown on HIS timeline as a
--     neutral connector with a button, and not shouted about here.
--   * Two legs whose points do not join up is likewise not listed, and this one
--     is worth stating because it is computable and tempting. It would fire on
--     مطار جدة → مكة for every single arrival in the mission — the airport
--     coach, which nobody tracks and nobody needs to. A board whose most common
--     row is one that never needs acting on is a board that gets ignored.
--
-- `travels = false` is excluded throughout: staff already resident in the
-- Kingdom have no arrival flight and never will, and a tool that reports forty
-- of those every morning is a tool nobody opens in the second week.

create or replace function travel_gaps(p_season_id uuid default null)
  returns table (
    kind text,
    participant_id uuid,
    profile_id uuid,
    full_name text,
    photo_url text,
    leg_id uuid,
    trip_id uuid,
    trip_number text,
    role leg_role,
    at timestamptz
  )
  language sql
  stable
  set search_path = public
as $$
  with season as (
    select coalesce(p_season_id, (select id from seasons where is_current)) as id
  ),
  travellers as (
    select sp.id as participant_id, sp.profile_id,
           nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), '')
             as full_name,
           p.photo_url
    from season_participants sp
    join profiles p on p.id = sp.profile_id
    cross join season s
    where sp.season_id = s.id
      and sp.status = 'active'
      and sp.travels
  ),
  live as (
    select l.*
    from journey_legs l
    join travellers tr on tr.participant_id = l.participant_id
    where l.status in ('planned', 'confirmed', 'completed')
  )

  -- Nobody has booked him a flight in.
  select 'no_inbound', tr.participant_id, tr.profile_id, tr.full_name,
         tr.photo_url, null::uuid, null::uuid, null::text, null::leg_role,
         null::timestamptz
  from travellers tr
  where not exists (
    select 1 from live l
     where l.participant_id = tr.participant_id and l.role = 'inbound')

  union all

  -- Nobody has booked him a flight home. Asked of everybody, all season: the
  -- return is very often set two days out, so this row is normal in ذو القعدة
  -- and is the whole job by the end of ذو الحجة. The urgency is the reader's to
  -- judge from the date, not something this function pretends to know.
  select 'no_outbound', tr.participant_id, tr.profile_id, tr.full_name,
         tr.photo_url, null::uuid, null::uuid, null::text, null::leg_role,
         null::timestamptz
  from travellers tr
  where not exists (
    select 1 from live l
     where l.participant_id = tr.participant_id and l.role = 'outbound')

  union all

  -- Its time came and went and nobody said whether he was on it. This is the
  -- one that catches the private car, which has no other source at all.
  select 'unconfirmed', tr.participant_id, tr.profile_id, tr.full_name,
         tr.photo_url, l.id, l.trip_id, t.trip_number, l.role,
         coalesce(t.planned_departure_at, l.planned_departure_at)
  from live l
  join travellers tr on tr.participant_id = l.participant_id
  left join trips t on t.id = l.trip_id
  where l.status in ('planned', 'confirmed')
    and coalesce(t.planned_departure_at, l.planned_departure_at) < now()

  union all

  -- The flight is off and he is still on it. Deliberately NOT resolved by a
  -- trigger when the trip is cancelled (BR-6): where sixty people go instead is
  -- a decision, and a decision is somebody pressing a button.
  select 'cancelled_trip', tr.participant_id, tr.profile_id, tr.full_name,
         tr.photo_url, l.id, l.trip_id, t.trip_number, l.role,
         t.planned_departure_at
  from live l
  join travellers tr on tr.participant_id = l.participant_id
  join trips t on t.id = l.trip_id
  where t.status = 'cancelled'

  order by 1, 10 nulls last, 4
$$;

-- ============================================================= 5. assigning
--
-- The act the whole feature was asked for: one trip, a set of people, one
-- press. Written as a function and not as a loop in Dart for three reasons —
-- it is atomic, it is one round trip instead of N, and the rebooking rule is
-- subtle enough that it must exist in exactly one place.
--
-- Returns what it did rather than nothing, because "27 assigned, 3 moved from
-- another flight, 1 already aboard" is a sentence the person who pressed the
-- button needs to read.

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
    -- Already aboard this one. Not an error and not worth a second row; it is
    -- the ordinary result of somebody re-opening the picker to add three more
    -- and leaving the existing ticks alone.
    if exists (
      select 1 from journey_legs l
       where l.participant_id = v_participant
         and l.trip_id = p_trip_id
         and l.status in ('planned', 'confirmed', 'completed')
    ) then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    -- One live arrival and one live return per participation (BR-10). An
    -- internal movement may repeat — مكة to المدينة and back is two of them —
    -- so only the two bookend roles displace anything.
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

    -- Moving a man who has already ARRIVED is refused rather than silently
    -- rewriting history. If he flew in on Tuesday, he flew in on Tuesday, and
    -- whatever the room is trying to record is not this.
    if v_existing_status = 'completed' then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    -- BR-5: never deleted. The old row is marked and kept, and the new one
    -- names it, so "he was on SR441 and was moved" survives in the rows
    -- themselves and not only in the audit log.
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

    -- An assignment nobody was told about is an assignment nobody acts on —
    -- 0105's words, and truer here: a man who is not told cannot be at the
    -- airport.
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
  end loop;

  return jsonb_build_object(
    'assigned', v_assigned, 'rebooked', v_rebooked, 'skipped', v_skipped);
end;
$$;

revoke execute on function assign_to_trip(uuid, uuid[]) from public, anon;
grant execute on function assign_to_trip(uuid, uuid[]) to authenticated;

-- ============================================================ 6. taking off
--
-- Not a delete. `cancelled` when the movement is off and nothing replaces it —
-- he is not going — which is a different fact from `rebooked`, and the gaps
-- board needs to be able to tell them apart.

create or replace function unassign_leg(p_leg_id uuid, p_note text default null)
  returns void
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  if not (is_admin() or has_permission('travel.assign')) then
    raise exception 'not allowed to assign travel'
      using errcode = 'insufficient_privilege';
  end if;

  update journey_legs
     set status = 'cancelled',
         note = coalesce(nullif(btrim(coalesce(p_note, '')), ''), note),
         updated_at = now(),
         updated_by = auth.uid()
   where id = p_leg_id;
end;
$$;

revoke execute on function unassign_leg(uuid, text) from public, anon;
grant execute on function unassign_leg(uuid, text) to authenticated;

-- =========================================================== 7. what happened
--
-- BR-6 lives here. A trip going to `arrived` says the aeroplane landed; it says
-- nothing whatever about whether any particular man was on it, and there is
-- deliberately no trigger connecting the two. The app may OFFER the bulk
-- confirmation — "SR441 has landed, mark its 57 passengers arrived?" — and the
-- offer is a button, which is to say a human being.
--
-- Who may press it: whoever holds `travel.confirm`, and **the traveller
-- himself**, for his own legs. That second case is not a convenience. For a
-- private car there is no airline feed, no gate, no manifest — the only person
-- who knows he reached المدينة is the man who drove there.
--
-- Definer, and narrow. RLS cannot say "he may write these four columns and not
-- the flight number", so the signature says it instead.

create or replace function confirm_leg(
  p_leg_id uuid,
  p_status text,
  p_departed_at timestamptz default null,
  p_arrived_at timestamptz default null
) returns void
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_owner uuid;
  v_status leg_status;
begin
  select sp.profile_id into v_owner
    from journey_legs l
    join season_participants sp on sp.id = l.participant_id
   where l.id = p_leg_id;

  if v_owner is null then
    raise exception 'no such leg' using errcode = 'no_data_found';
  end if;

  if not (is_admin() or has_permission('travel.confirm') or v_owner = auth.uid())
  then
    raise exception 'not allowed to confirm this movement'
      using errcode = 'insufficient_privilege';
  end if;

  v_status := p_status::leg_status;

  -- The four a confirmation may set. `cancelled` and `rebooked` are decisions
  -- about the booking, not observations about the journey, and they belong to
  -- `unassign_leg` and `assign_to_trip` where the rules around them are.
  if v_status not in ('planned', 'confirmed', 'completed', 'missed') then
    raise exception 'that is not something a confirmation may say'
      using errcode = 'check_violation';
  end if;

  update journey_legs
     set status = v_status,
         actual_departure_at = coalesce(p_departed_at, actual_departure_at),
         -- Arriving is the fact that moves a man on the map, so a `completed`
         -- with no time given is stamped now rather than left blank. A journey
         -- that says he arrived but not when is a journey that cannot be drawn.
         actual_arrival_at = case
           when p_arrived_at is not null then p_arrived_at
           when v_status = 'completed' then coalesce(actual_arrival_at, now())
           else actual_arrival_at
         end,
         confirmed_by = auth.uid(),
         confirmed_at = now(),
         updated_at = now(),
         updated_by = auth.uid()
   where id = p_leg_id;
end;
$$;

revoke execute on function confirm_leg(uuid, text, timestamptz, timestamptz)
  from public, anon;
grant execute on function confirm_leg(uuid, text, timestamptz, timestamptz)
  to authenticated;

-- ================================================= 8. he arranged it himself
--
-- The private car, and everything like it. A first-class movement with no trip
-- behind it, recorded by the man who made it or by the room on his behalf.
--
-- Definer for the same reason as `confirm_leg`: the insert policy on
-- `journey_legs` is `travel.assign` and must stay that way — putting people on
-- flights is not something a man does for himself — but recording that he drove
-- to المدينة is. The signature is the line between those two.

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

  -- BR-10 again, and reached from the other side. A man recording that he flew
  -- himself home when the room has already booked him onto a flight is not a
  -- second return leg — it is a correction, and it has to displace the booking
  -- rather than sit beside it and break the unique index with a raw error.
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

  return v_leg;
end;
$$;

revoke execute on function record_self_leg(
  uuid, text, text, uuid, uuid, timestamptz, timestamptz, text, boolean)
  from public, anon;
grant execute on function record_self_leg(
  uuid, text, text, uuid, uuid, timestamptz, timestamptz, text, boolean)
  to authenticated;

-- ============================================== 9. saying he does not travel
--
-- `travels` sits on `season_participants`, whose write policy is
-- `seasons.participants_manage` — the permission for adding and removing people
-- from the roster altogether. Widening that policy to let the travel team in
-- would hand them the roster, which is far more than they asked for.
--
-- So: one function, one column.

create or replace function set_participant_travels(
  p_participant_id uuid,
  p_travels boolean
) returns void
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  if not (is_admin()
          or has_permission('travel.edit')
          or has_permission('seasons.participants_manage')) then
    raise exception 'not allowed to change travel expectations'
      using errcode = 'insufficient_privilege';
  end if;

  update season_participants
     set travels = p_travels
   where id = p_participant_id;
end;
$$;

revoke execute on function set_participant_travels(uuid, boolean)
  from public, anon;
grant execute on function set_participant_travels(uuid, boolean)
  to authenticated;

-- ==================================================== 10. finding one's own
--
-- Every screen that draws a journey needs the participation id first, and the
-- app should not have to know how that is looked up. Null when the man is not
-- in the season at all, which is a perfectly ordinary answer — a great many
-- accounts are not in any given year — and reads as an empty journey rather
-- than as an error.

create or replace function my_participation(p_season_id uuid default null)
  returns uuid
  language sql
  stable
  set search_path = public
as $$
  select sp.id
  from season_participants sp
  where sp.profile_id = auth.uid()
    and sp.season_id = coalesce(
      p_season_id, (select id from seasons where is_current))
    and sp.status = 'active'
  limit 1
$$;

-- Same question, asked about somebody else — what the employee page needs
-- before it can show a travel section at all. RLS on `season_participants`
-- already refuses this to anybody without `seasons.participants_view`, and that
-- is the correct answer: whoever cannot see the roster has no business reading
-- travel off it.
create or replace function participation_of(
  p_profile_id uuid,
  p_season_id uuid default null
) returns uuid
  language sql
  stable
  set search_path = public
as $$
  select sp.id
  from season_participants sp
  where sp.profile_id = p_profile_id
    and sp.season_id = coalesce(
      p_season_id, (select id from seasons where is_current))
  limit 1
$$;
