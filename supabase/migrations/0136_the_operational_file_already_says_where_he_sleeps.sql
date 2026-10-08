-- The operational file already says where he sleeps.
--
-- 0135 gave a stay a `place_item_id` and a way to set it, on the assumption
-- that somebody would name the hotel. That was wrong, and wrong in the way this
-- codebase most dislikes: it invented a second place for a fact the system
-- already holds.
--
-- A man's مسكن is not typed in. It follows from his membership of an
-- operational file:
--
--   module_node_members  ← he is posted here
--     └ module_nodes     ← the tower/برج he was posted to
--         └ reference_item_id → فندق «سنود الريان»
--             └ data->>'city' → مكة المكرمة
--
-- Which is already true of the running season: forty-five people are housed
-- through «قطاعات وأبراج حجاج سوريا في مكة المكرمة» exactly this way, and every
-- one of those hotels names its city. Asking anybody to re-enter that would be
-- asking them to keep two records in step by hand, and the second one would be
-- the one that went stale.
--
-- ------------------------------------------------------- hotels, not camps
--
-- The same join reaches CAMPS as well, and those are deliberately not treated
-- as accommodation. A hundred and thirty people hold two hundred and thirty-five
-- camp memberships between them: a man supervises several مخيمات across منى and
-- عرفات during the rites. That is his WORK for five days, not one bed for a
-- month, and reading it as "where he lives" would put four camps in a field
-- that can hold one.
--
-- So the derivation asks for `hotels` and matches the stay's own city. A camp
-- belongs to a `rites` stay, which somebody records deliberately or not at all.
--
-- --------------------------------------------------- what this migration does
--
-- Drops the column, the trigger that guarded it, the setter and the picker
-- feed; and rewrites `employee_stays` to resolve the مسكن through the files.
-- The stay row keeps its city, its dates and its bounding legs — everything
-- that genuinely IS a fact about his itinerary rather than about the paperwork.

-- ================================================== 1. the stored place goes

drop trigger if exists journey_stays_place_is_a_place on journey_stays;
drop function if exists stay_place_is_a_place();
drop function if exists set_stay_place(uuid, uuid, text);
drop function if exists places_for_stay(uuid, uuid);

drop index if exists idx_journey_stays_place;

-- `employee_stays` declares the column in its return type, so it cannot be
-- replaced in place while the column is being dropped.
drop function if exists employee_stays(uuid);

alter table journey_stays drop column if exists place_item_id;

-- `add_stay` took a place. It no longer can.
drop function if exists add_stay(
  uuid, text, uuid, uuid, timestamptz, timestamptz, text);

-- ========================================== 2. where the files say he sleeps
--
-- One hotel, for one man, in one city, in one season. `limit 1` because a man
-- posted to two towers of the same hotel is one man in one hotel, and a man
-- posted to towers of two DIFFERENT hotels in the same city is a data question
-- for the office rather than something this function should invent an answer
-- to — it takes the first and the file remains the place to look.

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
  from module_node_members mnm
  join module_nodes mn on mn.id = mnm.node_id
  join reference_items ri on ri.id = mn.reference_item_id
  join reference_sets rs on rs.id = ri.set_id
  join modules m on m.id = mn.module_id
  where mnm.profile_id = p_profile_id
    and m.season_id = p_season_id
    -- Hotels only. See the note at the head of this file about camps.
    and rs.code = 'hotels'
    and (p_city_item_id is null
         or (ri.data ->> 'city')::uuid = p_city_item_id)
  order by mn.sort_order, ri.name_ar
  limit 1
$$;

comment on function housing_for(uuid, uuid, uuid) is
  'The hotel an operational file posts this man to, in this city, this season. '
  'The single source of where he is housed — journey_stays deliberately does '
  'not store it (0136).';

-- ============================================== 3. the itinerary, rewritten

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
    -- Derived, every time it is read. Nothing here is stored, so nothing here
    -- can disagree with the file it came from: move a man to another tower and
    -- his itinerary says the new hotel the next time somebody opens it.
    housed.id,
    housed.name_ar,
    housed.name_en,
    s.arrived_at,
    s.departed_at,
    s.arrival_leg_id,
    s.departure_leg_id,
    s.note,
    case
      when s.arrived_at is null then null
      else greatest(0, coalesce(s.departed_at, now())::date - s.arrived_at::date)
    end,
    (select count(*)::integer
       from place_check_ins ci2
      where ci2.item_id = housed.id
        and ci2.profile_id = sp.profile_id
        and (s.arrived_at is null or ci2.created_at >= s.arrived_at)
        and (s.departed_at is null or ci2.created_at <= s.departed_at))
  from journey_stays s
  join season_participants sp on sp.id = s.participant_id
  left join reference_items ci on ci.id = s.city_item_id
  left join lateral (
    select ri.id, ri.name_ar, ri.name_en
    from reference_items ri
    where s.kind = 'residence'
      and ri.id = housing_for(sp.profile_id, sp.season_id, s.city_item_id)
  ) housed on true
  where s.participant_id = p_participant_id
  order by s.arrived_at nulls first, s.sort_order
$$;

comment on function employee_stays(uuid) is
  'Where a participant was based and for how long, in order. The مسكن is '
  'resolved through his operational-file postings (0136) and is not stored: '
  'the file is the record of where he is housed, and there is only one of it.';

-- ================================================== 4. a stay with no legs
--
-- Still wanted, and now simpler: the man already resident in the Kingdom, whose
-- hotel the files will answer for once he is posted. No place argument, because
-- there is nothing to pass.

create or replace function add_stay(
  p_participant_id uuid,
  p_kind text,
  p_city_item_id uuid default null,
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
    (participant_id, kind, city_item_id,
     arrived_at, departed_at, note, sort_order, created_by, updated_by)
  values
    (p_participant_id, p_kind::stay_kind, p_city_item_id,
     p_arrived_at, p_departed_at, nullif(btrim(coalesce(p_note, '')), ''),
     coalesce((select max(sort_order) + 1 from journey_stays
                where participant_id = p_participant_id), 0),
     auth.uid(), auth.uid())
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute on function add_stay(
  uuid, text, uuid, timestamptz, timestamptz, text) from public, anon;
grant execute on function add_stay(
  uuid, text, uuid, timestamptz, timestamptz, text) to authenticated;

-- =============================================== 5. the label loses the place

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
