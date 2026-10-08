-- An arrival has to arrive SOMEWHERE.
--
-- `check_in_here` accepted a call naming neither a place nor a position, and
-- wrote a row that says: somebody reports that he arrived — at the file. Not at
-- a camp, not at a tower, and from nowhere in particular. It cannot be drawn on
-- the map, it reads as "الملف نفسه" on the presence board, and it counts toward
-- nothing: `season_map` counts arrivals per NODE, so a row with no node is
-- invisible to the one screen the register exists to feed.
--
-- It is worse than useless, because it is not empty. A man who presses the
-- button and is told his arrival was recorded has every reason to believe he
-- has been counted, and the operations room looking for him sees a camp with
-- nobody in it. A refusal he can act on — scan the code, turn the location on,
-- pick the place — is the honest answer.
--
-- The rule is deliberately OR, not AND. Either is enough on its own:
--
--   * a NODE with no position — the man scanned the code on the gate, and his
--     phone could not get a fix inside a metal camp. The code already said
--     where he is;
--   * a POSITION with no node — he is somewhere the file has not drawn yet, on
--     a road, at a place nobody has printed a code for. The coordinates say
--     where he is.
--
-- Only neither is nothing.

create or replace function check_in_here(
  p_module_id uuid,
  p_node_id uuid default null,
  p_method check_in_method default 'manual',
  p_lat double precision default null,
  p_lng double precision default null,
  p_accuracy double precision default null,
  p_note text default null
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_lat double precision;
  v_lng double precision;
  v_distance double precision;
begin
  if not is_module_member(p_module_id) then
    raise exception 'not a member of this file' using errcode = 'check_violation';
  end if;

  -- Named as a code the app can turn into a sentence, like every other refusal
  -- in this schema. A raw English message on an Arabic screen is not an answer.
  if p_node_id is null and (p_lat is null or p_lng is null) then
    raise exception 'check_in_needs_a_place' using errcode = 'check_violation';
  end if;

  if p_node_id is not null then
    if not exists (
      select 1 from module_nodes
       where id = p_node_id and module_id = p_module_id
    ) then
      raise exception 'check_in_node_mismatch' using errcode = 'check_violation';
    end if;

    if p_lat is not null and p_lng is not null then
      select l.lat, l.lng into v_lat, v_lng from node_location(p_node_id) l;
      if v_lat is not null then
        v_distance := metres_between(p_lat, p_lng, v_lat, v_lng);
      end if;
    end if;
  end if;

  insert into node_check_ins (
    module_id, node_id, profile_id, method,
    latitude, longitude, accuracy_m, distance_m, note
  )
  values (
    p_module_id, p_node_id, auth.uid(), p_method,
    p_lat, p_lng, p_accuracy, v_distance, nullif(btrim(coalesce(p_note, '')), '')
  )
  returning id into v_id;

  return v_id;
end;
$$;
