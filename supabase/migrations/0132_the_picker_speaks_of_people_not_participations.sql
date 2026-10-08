-- The picker speaks of people; the register speaks of participations.
--
-- 0130 keyed assignment on `season_participants.id`, and that is right: travel
-- belongs to a man's participation in a year, never to the man. But every
-- employee picker in this app — `showEmployeePicker`, the one screen that
-- already knows how to page four hundred people, search them in Arabic and
-- hand back a set — deals in `profiles.id`, and rightly so, because it is used
-- by five features that have nothing to do with seasons.
--
-- Translating between the two in Dart would put the season lookup on the phone,
-- where it can be wrong: a picker opened against one season and a trip
-- belonging to another would resolve each man to the wrong participation and
-- BR-2's trigger would refuse the insert with a message about seasons that
-- nobody asked about.
--
-- So the translation happens here, once, against the TRIP's own season — which
-- is the only season that can possibly be correct.

create or replace function assign_profiles_to_trip(
  p_trip_id uuid,
  p_profile_ids uuid[]
) returns jsonb
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_season uuid;
  v_participants uuid[];
  v_missing int;
begin
  if not (is_admin() or has_permission('travel.assign')) then
    raise exception 'not allowed to assign travel'
      using errcode = 'insufficient_privilege';
  end if;

  select season_id into v_season from trips where id = p_trip_id;
  if v_season is null then
    raise exception 'no such trip' using errcode = 'no_data_found';
  end if;

  select array_agg(sp.id) into v_participants
    from season_participants sp
   where sp.season_id = v_season
     and sp.status = 'active'
     and sp.profile_id = any(coalesce(p_profile_ids, '{}'::uuid[]));

  v_participants := coalesce(v_participants, '{}'::uuid[]);

  -- Anybody picked who is not an active participant of this trip's season is
  -- silently left out rather than failing the whole call. It is a real case —
  -- a man withdrawn from the season between the picker opening and the button
  -- being pressed — and losing twenty-six good assignments to it would be the
  -- wrong trade. The count comes back so the app can say so.
  v_missing := coalesce(array_length(p_profile_ids, 1), 0)
             - coalesce(array_length(v_participants, 1), 0);

  return assign_to_trip(p_trip_id, v_participants)
         || jsonb_build_object('not_in_season', v_missing);
end;
$$;

revoke execute on function assign_profiles_to_trip(uuid, uuid[])
  from public, anon;
grant execute on function assign_profiles_to_trip(uuid, uuid[])
  to authenticated;

-- ------------------------------------------------- who still has no such leg
--
-- The single most useful thing the assign screen can offer at four hundred
-- people: not "choose from everybody", but "choose from the eighty who have no
-- arrival flight yet".
--
-- Returns profile ids, because that is what the picker takes.
create or replace function participants_without_leg(
  p_season_id uuid,
  p_role text
) returns table (profile_id uuid)
  language sql
  stable
  set search_path = public
as $$
  select sp.profile_id
  from season_participants sp
  where sp.season_id = coalesce(
          p_season_id, (select id from seasons where is_current))
    and sp.status = 'active'
    and sp.travels
    and not exists (
      select 1 from journey_legs l
       where l.participant_id = sp.id
         and l.role = p_role::leg_role
         and l.status in ('planned', 'confirmed', 'completed')
    )
$$;
