-- Attendance belongs to the PLACE, and the place stopped being a node.
--
-- 0087 made a check-in a fact about an operational file: `node_check_ins.node_id`
-- points at a `module_nodes` row, the sheet opens from the file page, the board
-- is per file. That was the right shape while a place WAS a node.
--
-- 0095/0096/0097 changed what a place is. A فندق and a مخيم are entries of a
-- reference list now, CHOSEN inside files rather than authored in them.
-- Attendance kept pointing at the paperwork while the place moved out from
-- under it — which is why the same camp entered in two files carries two
-- separate registers, and why a hotel in المدينة, which stands in no file at
-- all, could never carry presence however many people slept in it.
--
-- ------------------------------------------------------- the rule that reverses
--
-- 0087 argued, at length and correctly, that a doubtful check-in is KEPT and
-- FLAGGED and never refused: "the cost of a missing true record, in those five
-- days, is far higher than the cost of a doubtful one that can be reviewed
-- later." 0094 kept that and only refused the empty case.
--
-- That was right while presence was a note in a register nobody drew. It
-- stopped being right in 0090, when `season_map` began painting pins from it. A
-- check-in that can be filed from a hotel room in مكة for a camp in منى makes
-- every green pin on that map worth nothing, and a map that lies is worse than
-- no map — because the room stops phoning to check.
--
-- So proximity is ENFORCED now, and the phone's own doubt is subtracted before
-- it is: a fix that says "five hundred metres, give or take four hundred" is
-- not evidence that anybody was in the wrong place, and is accepted. A fix that
-- says "five hundred metres, give or take eight" is, and is refused. That is
-- 0087's own `isFarFromPlace` arithmetic, moved from flagging to refusing.
--
-- The cost is stated plainly: a place with no coordinates now accepts NOTHING.
-- The report at the end of this migration counts them, and the season cannot
-- start until that count is zero.

-- ======================================================= 1. which lists are places

alter table reference_sets
  add column if not exists is_place boolean not null default false;

comment on column reference_sets.is_place is
  'Whether an entry of this list is somewhere a person stands and a check-in '
  'code can be fixed. A فندق and a مخيم are; a قطاع, a مركز, a تكتل and a '
  'مجموعة are arrangements on paper. Default false, for 0089''s reason: a list '
  'added by a later migration carries no code until somebody says it is a '
  'place, which shows up as an empty screen with a sentence rather than as '
  'codes printed for something with no gate to put them on.';

update reference_sets set is_place = true where code in ('hotels', 'camps');

-- `module_type_levels.is_place` (0089) is NOT dropped and NOT the same question
-- any more. It still decides what the map draws, and that judgement stands: a
-- قطاع has no coordinates and drawing it would put a marker on an idea. What it
-- no longer decides is where a code is printed.
comment on column module_type_levels.is_place is
  'Whether a node at this level is drawn on the season map. NO LONGER what '
  'decides where a check-in code is printed — since 0098 a code belongs to a '
  'reference ENTRY, and that question is reference_sets.is_place. Related but '
  'not the same: a level may be a pin while drawing from a list of things '
  'nobody checks in at.';

-- ============================================================ 2. how near is near
--
-- A schema field rather than a column, and the reason is that the whole master
-- data screen is schema-driven: `reference_item_form` and
-- `reference_item_detail_screen` loop over `reference_set_fields`, so an
-- override declared here renders, validates, saves, displays and audits itself
-- with no Dart written for it. A column would need bespoke widgets in both.
-- sort_order 90 puts it last, which is where an override belongs.

insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, is_required, sort_order)
select rs.id, 'check_in_radius_m', 'نطاق تسجيل الوصول (م)',
       'Check-in radius (m)', 'number'::module_field_kind, false, 90
from reference_sets rs
where rs.is_place
on conflict (set_id, key) do nothing;

create or replace function place_radius_m(p_item_id uuid)
  returns double precision
  language sql stable security definer set search_path = public as $$
  select least(greatest(coalesce(
    (select (ri.data ->> 'check_in_radius_m')::double precision
       from reference_items ri
      where ri.id = p_item_id
        -- Guarded rather than cast blindly. The value lives in free-form jsonb
        -- and a typo of "٢٠٠" or "200m" would abort the check-in with a cast
        -- error instead of refusing it with a sentence — and an error a man at
        -- a gate cannot act on is the failure this whole migration is about.
        and btrim(coalesce(ri.data ->> 'check_in_radius_m', '')) ~ '^\d+(\.\d+)?$'),
    -- Two hundred metres is about the length of a camp in منى, and is the
    -- number 0087 already used to call a check-in suspect. Mirrored by
    -- CheckInRules.defaultRadiusM in Dart; test/check_in_radius_test.dart reads
    -- this file and pins the two together.
    200
  ), 20), 5000);
$$;

comment on function place_radius_m(uuid) is
  'How near a phone must be for a check-in at this place to be accepted. The '
  'clamp is not decoration: an override of 2 would make a hotel unreachable '
  'and 200000 would make the rule meaningless, and both fail silently.';

-- ============================================================ 3. where a place is
--
-- 0092's second half, lifted out so a place can be located without a node to
-- ask through. Matched BY KIND rather than by the key `location_url`, for
-- 0092's reason: a list that spells its location field differently — the camps
-- do, and a list added next season will — is found without this being edited.

create or replace function place_location(p_item_id uuid)
  returns table (lat double precision, lng double precision)
  language plpgsql stable security definer set search_path = public as $$
declare
  v_url text;
  v_match text[];
  -- One pair, matched three ways. `\+?` admits the resolved share link: Google
  -- writes "21.424128,+39.896510" and nothing else here does. See 0091.
  c_pair constant text := '(-?\d{1,3}(?:\.\d+)?)\s*,\s*\+?\s*(-?\d{1,3}(?:\.\d+)?)';
begin
  select nullif(ri.data ->> rf.key, '')
    into v_url
    from reference_items ri
    join reference_set_fields rf
      on rf.set_id = ri.set_id and rf.kind = 'location'
   where ri.id = p_item_id
   order by rf.sort_order
   limit 1;

  if v_url is null then
    return;
  end if;

  v_match := regexp_match(v_url, '[?&](?:q|query|ll|center)=' || c_pair);
  if v_match is null then
    v_match := regexp_match(v_url, '@' || c_pair);
  end if;
  if v_match is null then
    v_match := regexp_match(v_url, '/(?:maps/)?(?:search|place|dir)/' || c_pair);
  end if;
  if v_match is null then
    return;
  end if;

  lat := v_match[1]::double precision;
  lng := v_match[2]::double precision;
  -- A URL can carry any two numbers. Off the globe means it was not a position.
  if abs(lat) > 90 or abs(lng) > 180 then
    return;
  end if;
  return next;
end;
$$;

-- And `node_location` now asks it, so there is ONE parser in the database
-- answering to the one in Dart, rather than two drifting apart.
create or replace function node_location(p_node_id uuid)
  returns table (lat double precision, lng double precision)
  language plpgsql stable security definer set search_path = public as $$
declare
  v_url text;
  v_item uuid;
  v_match text[];
  c_pair constant text := '(-?\d{1,3}(?:\.\d+)?)\s*,\s*\+?\s*(-?\d{1,3}(?:\.\d+)?)';
begin
  -- 1. What the node was given directly. Still first: a file that pins one
  -- particular entrance for one tower is saying something more precise than
  -- the hotel's general address, and the more precise answer is the one to keep.
  select nullif(n.data ->> f.key, ''), n.reference_item_id
    into v_url, v_item
    from module_nodes n
    left join module_type_fields f
      on f.level_id = n.level_id and f.kind = 'location'
   where n.id = p_node_id
   order by f.sort_order
   limit 1;

  -- 2. Failing that, where the thing it IS happens to stand.
  if v_url is null and v_item is not null then
    return query select * from place_location(v_item);
    return;
  end if;

  if v_url is null then
    return;
  end if;

  v_match := regexp_match(v_url, '[?&](?:q|query|ll|center)=' || c_pair);
  if v_match is null then
    v_match := regexp_match(v_url, '@' || c_pair);
  end if;
  if v_match is null then
    v_match := regexp_match(v_url, '/(?:maps/)?(?:search|place|dir)/' || c_pair);
  end if;
  if v_match is null then
    return;
  end if;

  lat := v_match[1]::double precision;
  lng := v_match[2]::double precision;
  if abs(lat) > 90 or abs(lng) > 180 then
    return;
  end if;
  return next;
end;
$$;

-- =============================================================== 4. the code
--
-- The secret is stored in plain text, and that is a decision rather than an
-- omission. It is PRINTED ON A WALL: its confidentiality is physical, not
-- cryptographic, and anybody standing at the gate has it — which is the whole
-- design. Hashing it would prevent the one thing the system must do, which is
-- print it. What protects it is RLS: only whoever may print codes may read the
-- column, and it appears in no list, no map, and no `select *` on
-- reference_items.

create table if not exists place_codes (
  item_id    uuid primary key references reference_items (id) on delete cascade,
  secret     text not null,
  rotated_at timestamptz not null default now(),
  rotated_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

alter table place_codes enable row level security;

drop policy if exists place_codes_select on place_codes;
create policy place_codes_select on place_codes for select
  using (is_admin() or has_permission('checkin.codes'));

-- No insert, update or delete policy at all. Rows are made by the trigger below
-- and changed only by rotate_place_code(). A secret a client can write is a
-- secret he can set back to one he has already photographed, which would undo
-- rotation entirely.

create or replace function place_code_seed() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if exists (
    select 1 from reference_sets rs where rs.id = new.set_id and rs.is_place
  ) then
    -- gen_random_uuid is already in use across this schema; 16 hex characters
    -- of it is 64 bits, which is far past guessing and short enough to read off
    -- a sun-faded sticker. No pgcrypto — 0087 hand-wrote a haversine rather
    -- than take an extension, and this follows it.
    insert into place_codes (item_id, secret)
    values (new.id, substr(replace(gen_random_uuid()::text, '-', ''), 1, 16))
    on conflict (item_id) do nothing;
  end if;
  return null;
end;
$$;

drop trigger if exists place_codes_seed on reference_items;
create trigger place_codes_seed after insert on reference_items
  for each row execute function place_code_seed();

-- Every place that already exists. Note this also means 0043's carry-forward
-- into next season produces new entries with NEW ids and NEW secrets — so every
-- sticker is reprinted at the season roll. That is correct (a poster for last
-- season's contract should not admit anybody to this season's register) and it
-- is a morning's work, which is why the batch print action exists.
insert into place_codes (item_id, secret)
select ri.id, substr(replace(gen_random_uuid()::text, '-', ''), 1, 16)
from reference_items ri
join reference_sets rs on rs.id = ri.set_id and rs.is_place
on conflict (item_id) do nothing;

-- 0077 attaches its audit trigger to every base table PRESENT WHEN IT RAN, so a
-- table created afterwards is unaudited. That default is right for the register
-- below — thousands of rows, none of them an administrative act — and wrong
-- here: rotating a code silently voids every poster already on a wall.
drop trigger if exists audit_row on place_codes;
create trigger audit_row after insert or update or delete on place_codes
  for each row execute function audit_row_change();

-- ============================================================== 5. reading it

create or replace function place_code(p_item_id uuid)
  returns table (
    item_id     uuid,
    place_name  text,
    set_name_ar text,
    secret      text,
    lat         double precision,
    lng         double precision,
    radius_m    double precision,
    rotated_at  timestamptz
  )
  language plpgsql stable security definer set search_path = public as $$
begin
  -- Restated by hand: a `security definer` function does not inherit the RLS on
  -- place_codes, so without this line the policy above guards nothing.
  if not (is_admin() or has_permission('checkin.codes')) then
    raise exception 'check_in_codes_denied' using errcode = 'check_violation';
  end if;

  return query
  select ri.id, ri.name_ar, rs.name_ar, pc.secret,
         loc.lat, loc.lng, place_radius_m(ri.id), pc.rotated_at
    from reference_items ri
    join reference_sets rs on rs.id = ri.set_id and rs.is_place
    join place_codes pc on pc.item_id = ri.id
    left join lateral place_location(ri.id) loc on true
   where ri.id = p_item_id;
end;
$$;

comment on function place_code(uuid) is
  'Everything a poster needs, in one round trip. The coordinates come from '
  'place_location so a poster can never be built against a pin the server does '
  'not agree with.';

create or replace function rotate_place_code(p_item_id uuid)
  returns table (secret text, rotated_at timestamptz)
  language plpgsql security definer set search_path = public as $$
begin
  if not (is_admin() or has_permission('checkin.rotate')) then
    raise exception 'check_in_rotate_denied' using errcode = 'check_violation';
  end if;

  -- No grace window, deliberately. A rotation that keeps the old secret alive
  -- for an hour is the vulnerability re-opened for exactly the hour in which
  -- somebody is standing in a room holding the photograph. The app's
  -- confirmation says so in Arabic before it is pressed.
  --
  -- Wrapped in a CTE rather than `return query update … returning`, so that
  -- what is returned is plainly a SELECT and the OUT parameters cannot be read
  -- as the columns they are named after.
  return query
  with rotated as (
    update place_codes pc
       set secret = substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
           rotated_at = now(),
           rotated_by = auth.uid()
     where pc.item_id = p_item_id
    returning pc.secret as new_secret, pc.rotated_at as new_rotated_at
  )
  select r.new_secret, r.new_rotated_at from rotated r;
end;
$$;

-- ============================================================ 6. the register

create table if not exists place_check_ins (
  id          uuid primary key default gen_random_uuid(),
  item_id     uuid not null references reference_items (id) on delete cascade,
  profile_id  uuid not null references profiles (id) on delete cascade,
  -- Stamped from the entry's own season at insert, so the board and the map do
  -- not have to join back through a list whose scoping may change (0097 changed
  -- it for two lists already).
  season_id   uuid references seasons (id) on delete set null,

  -- All three NOT NULL, and that is this migration in one line. 0087 let them
  -- be null because a check-in with no fix was better than no check-in. Under
  -- the new rule a check-in with no fix is not a check-in.
  latitude    double precision not null,
  longitude   double precision not null,
  distance_m  double precision not null,

  accuracy_m  double precision,
  -- What it was measured AGAINST, at the time. The override on the entry can be
  -- edited afterwards, and a row has to stay explicable to somebody reading it
  -- in شوال.
  radius_m    double precision not null,

  note        text,
  created_at  timestamptz not null default now()
);

-- No `method` column. Check-in is a code plus a position and nothing else now,
-- so an enum with one value would only record that the migration used to be
-- different.

create index if not exists idx_place_check_ins_item
  on place_check_ins (item_id, created_at desc);
create index if not exists idx_place_check_ins_profile
  on place_check_ins (profile_id, created_at desc);
create index if not exists idx_place_check_ins_season
  on place_check_ins (season_id, created_at desc);

alter table place_check_ins enable row level security;

drop policy if exists place_check_ins_select on place_check_ins;
create policy place_check_ins_select on place_check_ins for select
  using (
    profile_id = auth.uid()
    or is_admin()
    or has_permission('checkin.board')
  );

-- No insert policy, for 0087's reason and more so now: the distance on a row is
-- worth something only because the database measured it.

-- ================================================================ 7. filing one

create or replace function check_in_at_place(
  p_item_id  uuid,
  p_secret   text,
  p_lat      double precision,
  p_lng      double precision,
  p_accuracy double precision default null,
  p_note     text default null
)
  returns table (
    check_in_id uuid,
    place_name  text,
    distance_m  double precision,
    radius_m    double precision
  )
  language plpgsql security definer set search_path = public as $$
declare
  v_name     text;
  v_season   uuid;
  v_secret   text;
  v_lat      double precision;
  v_lng      double precision;
  v_distance double precision;
  v_worst    double precision;
  v_radius   double precision;
  v_id       uuid;
begin
  -- The order of these guards is the argument. Each refusal is the most
  -- ACTIONABLE one available at that point, because a man holding a phone at a
  -- gate can only act on the first thing he is told.

  -- 1. A suspended account may not file presence. Membership is not asked for:
  -- a place is not in a file, and the instruction is that the gate is the code
  -- and the position. Standing there is the credential.
  if not is_approved() then
    raise exception 'check_in_not_approved' using errcode = 'check_violation';
  end if;

  -- 2. Before the secret, so a code for something that has stopped being a
  -- place says so rather than saying the code is wrong.
  select ri.name_ar, ri.season_id into v_name, v_season
    from reference_items ri
    join reference_sets rs on rs.id = ri.set_id
   where ri.id = p_item_id and ri.is_active and rs.is_place;
  if v_name is null then
    raise exception 'check_in_not_a_place' using errcode = 'check_violation';
  end if;

  -- 3. The reversal of 0087. Before the secret, because "turn your location on"
  -- is something he can do standing where he is.
  if p_lat is null or p_lng is null
     or abs(p_lat) > 90 or abs(p_lng) > 180 then
    raise exception 'check_in_needs_a_position' using errcode = 'check_violation';
  end if;

  -- 4. One code whether the row is missing or merely stale: both mean "this
  -- poster is out of date, find the one that replaced it".
  select pc.secret into v_secret from place_codes pc where pc.item_id = p_item_id;
  if v_secret is null or p_secret is null or v_secret <> p_secret then
    raise exception 'check_in_code_expired' using errcode = 'check_violation';
  end if;

  -- 5. A place with no pin cannot enforce proximity, and accepting silently
  -- would re-open the exact hole this closes. It is an administrator's job to
  -- fix, and the sentence says so.
  select loc.lat, loc.lng into v_lat, v_lng from place_location(p_item_id) loc;
  if v_lat is null then
    raise exception 'check_in_place_has_no_location'
      using errcode = 'check_violation';
  end if;

  -- 6. Last, because it needs everything above. The phone's own doubt is
  -- subtracted first: 0087's arithmetic, moved from flagging to refusing.
  v_radius := place_radius_m(p_item_id);
  v_distance := metres_between(p_lat, p_lng, v_lat, v_lng);
  v_worst := greatest(v_distance - coalesce(p_accuracy, 0), 0);
  if v_worst > v_radius then
    -- The detail rides along so a screen can say "you are 800 m away and the
    -- range is 200 m" rather than "too far". friendlyErrorL still matches the
    -- code by substring, exactly as 0094 arranged.
    raise exception 'check_in_too_far'
      using errcode = 'check_violation',
            detail = round(v_worst)::text || '/' || round(v_radius)::text;
  end if;

  insert into place_check_ins
    (item_id, profile_id, season_id, latitude, longitude,
     distance_m, accuracy_m, radius_m, note)
  values
    (p_item_id, auth.uid(), v_season, p_lat, p_lng,
     v_distance, p_accuracy, v_radius,
     nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_id;

  return query select v_id, v_name, v_distance, v_radius;
end;
$$;

-- ============================================================== 8. reading it

create or replace function presence_board(
  p_since     timestamptz default null,
  p_item_id   uuid default null,
  p_season_id uuid default null
)
  returns table (
    check_in_id uuid,
    item_id     uuid,
    place_name  text,
    set_code    text,
    set_name_ar text,
    group_ar    text,
    group_en    text,
    profile_id  uuid,
    full_name   text,
    distance_m  double precision,
    accuracy_m  double precision,
    radius_m    double precision,
    note        text,
    created_at  timestamptz
  )
  language sql stable security definer set search_path = public as $$
  -- Latest per person per place. "Where is he" and "everywhere he has been
  -- today" are different questions, and the board asks the first.
  select distinct on (c.profile_id, c.item_id)
         c.id,
         c.item_id,
         ri.name_ar,
         rs.code,
         rs.name_ar,
         grp.name_ar,
         grp.name_en,
         c.profile_id,
         concat_ws(' ', p.first_name, p.father_name, p.surname),
         c.distance_m,
         c.accuracy_m,
         c.radius_m,
         c.note,
         c.created_at
    from place_check_ins c
    join reference_items ri on ri.id = c.item_id
    join reference_sets rs on rs.id = ri.set_id
    join profiles p on p.id = c.profile_id
    -- The group is the entry's own dividing reference — a hotel's city, a
    -- camp's مشعر — read through the same schema the map derives its four
    -- groups from and the picker slices by (0095's reference_filter). Nothing
    -- names مكة or منى here, and a fifth group arrives the day a fifth exists.
    --
    -- LATERAL with its own limit, not a plain join: a place list that gains a
    -- second reference field would otherwise return the same check-in twice,
    -- and `distinct on` would silently keep whichever of the two sorted first.
    -- One group per row, chosen the same way every other reader chooses it —
    -- the first by sort_order.
    left join lateral (
      select grp2.name_ar, grp2.name_en
        from reference_set_fields df
        join reference_items grp2
          on grp2.id = nullif(ri.data ->> df.key, '')::uuid
       where df.set_id = rs.id and df.kind = 'reference'
       order by df.sort_order
       limit 1
    ) grp on true
   where c.created_at >= coalesce(p_since, now() - interval '12 hours')
     and (p_item_id is null or c.item_id = p_item_id)
     and (p_season_id is null or c.season_id = p_season_id)
     -- The table's policy restated by hand: `security definer` does not inherit
     -- it, and without this the function would hand every row to anybody.
     and (
       c.profile_id = auth.uid()
       or is_admin()
       or has_permission('checkin.board')
     )
   order by c.profile_id, c.item_id, c.created_at desc;
$$;

revoke execute on function place_radius_m(uuid) from public, anon;
revoke execute on function place_location(uuid) from public, anon;
revoke execute on function place_code(uuid) from public, anon;
revoke execute on function rotate_place_code(uuid) from public, anon;
revoke execute on function check_in_at_place(
  uuid, text, double precision, double precision, double precision, text)
  from public, anon;
revoke execute on function presence_board(timestamptz, uuid, uuid)
  from public, anon;

grant execute on function place_radius_m(uuid) to authenticated;
grant execute on function place_location(uuid) to authenticated;
grant execute on function place_code(uuid) to authenticated;
grant execute on function rotate_place_code(uuid) to authenticated;
grant execute on function check_in_at_place(
  uuid, text, double precision, double precision, double precision, text)
  to authenticated;
grant execute on function presence_board(timestamptz, uuid, uuid)
  to authenticated;

-- ========================================================= 9. the map, rewired
--
-- Done HERE rather than in 0099, and the order is forced: `season_map` is
-- `language sql` with a dollar-quoted body, so Postgres records no dependency
-- on the tables inside it. Dropping node_check_ins first would succeed
-- cleanly and leave this function broken until the next person opened the map.
--
-- Dropped and recreated rather than replaced, because it gains an OUT column
-- and those are part of a function's identity — 0093 learned that the hard way.

drop function if exists season_map(uuid);

create function season_map(p_season_id uuid default null)
  returns table (
    node_id uuid,
    module_id uuid,
    module_name text,
    place_name text,
    group_key text,
    group_ar text,
    group_en text,
    lat double precision,
    lng double precision,
    posted integer,
    present integer,
    open_incidents integer,
    -- New. Without it a node that cannot carry a code reads as `unmanned` —
    -- a coloured pin accusing nobody of anything, because there is nowhere to
    -- fix a sticker and so there can never be an arrival to count.
    can_check_in boolean
  )
  language sql stable security definer set search_path = public as $$
  with season as (
    select s.id
      from seasons s
     where (p_season_id is not null and s.id = p_season_id)
        or (p_season_id is null and s.is_current)
     limit 1
  ),
  nodes as (
    select n.id,
           n.module_id,
           mt.name_ar as module_name,
           coalesce(n.label, ri.name_ar) as place_name,
           lv.reference_set_id,
           ri.id as item_id,
           coalesce(rs.is_place, false) as item_is_place,
           city.name_ar as city_ar,
           city.name_en as city_en,
           mt.code as type_code,
           mt.name_ar as type_ar,
           mt.name_en as type_en,
           loc.lat,
           loc.lng
      from module_nodes n
      join modules m on m.id = n.module_id
      join season on season.id = m.season_id
      join module_types mt on mt.id = m.module_type_id
      join module_type_levels lv on lv.id = n.level_id and lv.is_place
      left join reference_items ri on ri.id = n.reference_item_id
      left join reference_sets rs on rs.id = ri.set_id
      left join reference_sets hs
        on hs.id = lv.reference_set_id and hs.code = 'hotels'
      left join reference_items city
        on hs.id is not null
       and city.id = nullif(ri.data ->> 'city', '')::uuid
      cross join lateral node_location(n.id) loc
     where m.is_active
       and (m.ends_on is null or m.ends_on >= current_date)
       and loc.lat is not null
  ),
  -- Hotels the season has not turned into a node anywhere. The coordinates go
  -- through `place_location` now instead of an inline regex that only matched
  -- `?q=` — which meant every hotel pinned with Google's own share button was
  -- missing from this map, silently, and nobody could tell an absent pin from
  -- an unpinned place.
  loose_hotels as (
    select ri.id,
           ri.name_ar,
           city.name_ar as city_ar,
           city.name_en as city_en,
           m2.lat,
           m2.lng
      from reference_items ri
      join reference_sets rs on rs.id = ri.set_id and rs.code = 'hotels'
      left join reference_items city
        on city.id = nullif(ri.data ->> 'city', '')::uuid
      cross join lateral place_location(ri.id) m2
     where ri.is_active
       and m2.lat is not null
       and not exists (select 1 from nodes n where n.item_id = ri.id)
  )
  select n.id,
         n.module_id,
         n.module_name,
         n.place_name,
         case when n.reference_set_id is not null and n.city_ar is not null
              then 'hotels:' || n.city_ar
              else 'type:' || n.type_code
         end,
         case when n.reference_set_id is not null and n.city_ar is not null
              then 'فنادق ' || n.city_ar
              else n.type_ar
         end,
         case when n.reference_set_id is not null and n.city_en is not null
              then 'Hotels — ' || n.city_en
              else n.type_en
         end,
         n.lat,
         n.lng,
         (select count(*)::int from module_node_members nm where nm.node_id = n.id),
         -- Counted against the ENTRY, not the node. Two nodes standing on one
         -- entry — عرفات holds camp 16 as tent 154 and again as tent 158, which
         -- is what 0095's entry_slot exists for — now show the same count, and
         -- rightly: presence is a fact about the camp, and both files want to
         -- know the camp is manned.
         (select count(distinct c.profile_id)::int
            from place_check_ins c
           where c.item_id = n.item_id
             and c.created_at >= now() - interval '12 hours'),
         (select count(*)::int from incidents i
           where i.node_id = n.id and i.state <> 'closed'),
         (n.item_id is not null and n.item_is_place)
    from nodes n
   where is_admin()
      or has_permission('modules.view_all')
      or is_module_member(n.module_id)

  union all

  -- A hotel nobody is posted to yet, which under the old model could never
  -- carry presence at all — it is a node in no file, so there was no node id to
  -- record an arrival against. It is an entry with a code like any other now,
  -- and this is the largest single thing the rework buys.
  select null::uuid,
         null::uuid,
         null::text,
         h.name_ar,
         'hotels:' || coalesce(h.city_ar, '—'),
         'فنادق ' || coalesce(h.city_ar, '—'),
         'Hotels — ' || coalesce(h.city_en, h.city_ar, '—'),
         h.lat,
         h.lng,
         0,
         (select count(distinct c.profile_id)::int
            from place_check_ins c
           where c.item_id = h.id
             and c.created_at >= now() - interval '12 hours'),
         0,
         true
    from loose_hotels h
   where is_approved()

   order by 6, 4;
$$;

revoke execute on function season_map(uuid) from public, anon;
grant execute on function season_map(uuid) to authenticated;

-- ========================================================== 10. who may do what

insert into permissions (code, description, sort_order)
values ('checkin', 'Check-in section', 12)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('checkin.board',  'Read who is present everywhere', 1),
  ('checkin.codes',  'View, print and share place codes', 2),
  ('checkin.rotate', 'Regenerate a place code, voiding every printed poster', 3)
) as v(code, description, sort_order)
join permissions p on p.code = 'checkin'
on conflict (code) do nothing;

-- Voiding forty posters requires being able to see them first. Same shape as
-- 0088's incidents.handle → incidents.receive; the 0073 trigger enforces it and
-- this states it so the editor can explain itself.
insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from permissions c, permissions r
where c.code = 'checkin.rotate' and r.code = 'checkin.codes'
on conflict do nothing;

-- Reading your OWN presence needs no code at all: the `profile_id = auth.uid()`
-- clause in the policy covers it, and a man may always see where he said he was.

-- =========================================================== 11. a readable log

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
    -- New. Its primary key is the item, so the generic fallback finds no id and
    -- the log would otherwise read as a bare uuid — for the one act in this
    -- feature that invalidates work already done in the physical world.
    when 'place_codes' then
      (select ri.name_ar from reference_items ri
        where ri.id = (p_row ->> 'item_id')::uuid)
    else null
  end;

  return coalesce(v,
    p_row ->> 'name_ar', p_row ->> 'title', p_row ->> 'name',
    p_row ->> 'label', p_row ->> 'code', p_row ->> 'email');
exception when others then
  return null;
end;
$$;

-- ================================================================ the report
--
-- `unpinned` is the column that matters. Every entry it counts is a place where
-- NOBODY CAN CHECK IN AT ALL under the new rule — under 0087 an unpinned camp
-- still accepted arrivals, and it accepts none now. The season cannot start
-- until this is zero.

select rs.code as list,
       count(ri.id) as entries,
       count(pc.item_id) as coded,
       count(*) filter (where loc.lat is null) as unpinned,
       count(*) filter (where ri.data ? 'check_in_radius_m') as overridden
  from reference_sets rs
  join reference_items ri on ri.set_id = rs.id and ri.is_active
  left join place_codes pc on pc.item_id = ri.id
  left join lateral place_location(ri.id) loc on true
 where rs.is_place
 group by rs.code
 order by rs.code;
