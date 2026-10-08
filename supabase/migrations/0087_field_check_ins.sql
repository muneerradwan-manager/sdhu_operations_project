-- Proving somebody was where he was supposed to be.
--
-- The system can already say who HOLDS a post — مشرف البرج of tower seven is a
-- row in module_node_members, and has been since 0024. What it has never been
-- able to say is whether he is standing in tower seven now. During a season
-- that is the question the operations room actually asks, and until this
-- migration the only answer was to telephone him.
--
-- Two proofs, and neither is trusted alone:
--
--   * A CODE at the place. A sticker on the camp gate carrying the node's id;
--     scanning it says "I am looking at this gate". It can be photographed and
--     scanned from a hotel room, which is exactly why it is not enough.
--   * The PHONE'S POSITION. Compared against the coordinates the file already
--     records for that node. It can be spoofed by a rooted device, and it is
--     wrong by two hundred metres inside a metal camp, which is why IT is not
--     enough either.
--
-- So both are recorded, the distance between claim and record is computed HERE
-- rather than on the phone, and a check-in that does not add up is **kept and
-- marked**, never refused. Refusing would mean a man standing in the right camp
-- with a bad GPS fix cannot report that he is there — and the cost of a missing
-- true record is far higher, during those five days, than the cost of a
-- doubtful one somebody can look at afterwards.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'check_in_method') then
    -- `manual` is deliberate and deliberately visible: a node with no code
    -- printed yet and no coordinates recorded still needs its people to be able
    -- to say they arrived. It is the weakest of the three and the register
    -- shows which one was used, so it can never quietly pass for a scan.
    create type check_in_method as enum ('qr', 'gps', 'manual');
  end if;
end
$$;

create table if not exists node_check_ins (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules (id) on delete cascade,
  -- Null means the FILE itself rather than a place inside it. A flat file with
  -- no towers still has people who arrive somewhere.
  node_id uuid references module_nodes (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  method check_in_method not null,

  -- What the phone said. Null where it would not say — permission refused, no
  -- fix indoors — which is a fact about the check-in and is kept as one.
  latitude double precision,
  longitude double precision,
  -- The phone's own estimate of how wrong it might be. A fix accurate to five
  -- metres and a fix accurate to two thousand are not the same evidence, and
  -- without this the register cannot tell them apart.
  accuracy_m double precision,

  -- Metres between the phone and the coordinates the file records for the node.
  -- Null when the node has no recorded location, or the phone gave none.
  -- Computed by the database from both sides; never accepted from the client.
  distance_m double precision,

  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_node_check_ins_module
  on node_check_ins (module_id, created_at desc);
create index if not exists idx_node_check_ins_node
  on node_check_ins (node_id, created_at desc);
create index if not exists idx_node_check_ins_profile
  on node_check_ins (profile_id, created_at desc);

alter table node_check_ins enable row level security;

-- ------------------------------------------------------------ where a node is
--
-- The coordinates a node carries, dug out of the level fields.
--
-- A location lives in `module_nodes.data` under the key of a field whose kind
-- is `location` (0020, 0052), and its value is the map URL the admin pasted or
-- the picker wrote. So: find the field, take the value, read the pair out of
-- the URL. The `q=`/`query=`/`ll=` form is what this app writes; the `@lat,lng`
-- form is what Google's own share links use. Both are read, because both end up
-- in that column — the same two forms `MapLocation.parse` handles on the phone,
-- and the two must agree or a node the app shows a pin for is a node the
-- database thinks has no position.
create or replace function node_location(p_node_id uuid)
  returns table (lat double precision, lng double precision)
  language plpgsql stable security definer set search_path = public as $$
declare
  v_url text;
  v_match text[];
begin
  select nullif(n.data ->> f.key, '')
    into v_url
    from module_nodes n
    join module_type_fields f
      on f.level_id = n.level_id
     and f.kind = 'location'
   where n.id = p_node_id
   order by f.sort_order
   limit 1;

  if v_url is null then
    return;
  end if;

  v_match := regexp_match(
    v_url,
    '[?&](?:q|query|ll|center)=(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)'
  );
  if v_match is null then
    v_match := regexp_match(
      v_url, '@(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)'
    );
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

-- ---------------------------------------------------------------- the distance
--
-- Haversine, in metres, written out rather than taken from `earthdistance`.
-- That extension needs `cube` alongside it and neither is enabled on this
-- project; twelve lines of arithmetic is a smaller thing to own than two
-- extensions and the migration that turns them on.
create or replace function metres_between(
  p_lat1 double precision, p_lng1 double precision,
  p_lat2 double precision, p_lng2 double precision
) returns double precision
  language sql immutable as $$
  select 2 * 6371000 * asin(
    sqrt(
      power(sin(radians(p_lat2 - p_lat1) / 2), 2)
      + cos(radians(p_lat1)) * cos(radians(p_lat2))
        * power(sin(radians(p_lng2 - p_lng1) / 2), 2)
    )
  );
$$;

-- ------------------------------------------------------------------ the policy
--
-- Reading: your own, always. Everyone's, for whoever runs the file — the same
-- trust that reads what the members filed, because a register of who was where
-- is the same kind of record as a register of what they reported.
drop policy if exists node_check_ins_select on node_check_ins;
create policy node_check_ins_select on node_check_ins for select
  using (
    profile_id = auth.uid()
    or is_admin()
    or has_permission('modules.reports')
  );

-- Writing goes through the RPC below and nowhere else. There is deliberately no
-- insert policy: a row here is a claim about a person's whereabouts, and the
-- distance on it is only worth anything if the database was the one that
-- measured it.

-- -------------------------------------------------------------- checking in
--
-- Membership, not permission — exactly as filing a report is. A man reports
-- that he has arrived because he belongs to the file, not because somebody
-- granted him the right to arrive.
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
  -- Two scalars rather than one record on purpose. `select * into <record>`
  -- from a function that returned no rows leaves the record's field access
  -- resting on a rule that reads differently depending on who is reading it;
  -- scalars are simply null, and null is what "this node has no coordinates"
  -- has to mean here.
  v_lat double precision;
  v_lng double precision;
  v_distance double precision;
begin
  if not is_module_member(p_module_id) then
    raise exception 'not a member of this file' using errcode = 'check_violation';
  end if;

  -- A node from another file would let somebody file presence at a place he was
  -- never given, and the pair is what the whole record means.
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

revoke execute on function check_in_here(
  uuid, uuid, check_in_method, double precision, double precision,
  double precision, text
) from public, anon;
grant execute on function check_in_here(
  uuid, uuid, check_in_method, double precision, double precision,
  double precision, text
) to authenticated;

-- ------------------------------------------------------------------ the board
--
-- Who is where, now. One round trip for the operations room.
--
-- The LATEST check-in per person per node, not all of them: the question is
-- "where is he", and a list of everywhere he has been today answers a different
-- one. `p_since` is what "now" means, and it is the caller's to decide — an
-- evening inspection wants today, a Mina night wants the last four hours.
create or replace function module_presence(
  p_module_id uuid,
  p_since timestamptz default null
) returns table (
  check_in_id uuid,
  node_id uuid,
  node_label text,
  profile_id uuid,
  full_name text,
  method check_in_method,
  distance_m double precision,
  accuracy_m double precision,
  note text,
  created_at timestamptz
)
  language sql stable security definer set search_path = public as $$
  select distinct on (c.profile_id, c.node_id)
         c.id,
         c.node_id,
         coalesce(n.label, ri.name_ar),
         c.profile_id,
         concat_ws(' ', p.first_name, p.father_name, p.surname),
         c.method,
         c.distance_m,
         c.accuracy_m,
         c.note,
         c.created_at
    from node_check_ins c
    join profiles p on p.id = c.profile_id
    left join module_nodes n on n.id = c.node_id
    left join reference_items ri on ri.id = n.reference_item_id
   where c.module_id = p_module_id
     and c.created_at >= coalesce(p_since, now() - interval '12 hours')
     -- The same row security the table has, restated because a definer
     -- function does not inherit it: your own, or everyone's if you run files.
     and (
       c.profile_id = auth.uid()
       or is_admin()
       or has_permission('modules.reports')
     )
   order by c.profile_id, c.node_id, c.created_at desc;
$$;

revoke execute on function module_presence(uuid, timestamptz) from public, anon;
grant execute on function module_presence(uuid, timestamptz) to authenticated;
