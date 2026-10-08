-- A season is a journey from home and back, and the app never knew it.
--
-- A man's season starts at دمشق or حلب airport and ends at one of them a month
-- later. In between he lands at جدة, works out of مكة, is moved to المدينة
-- somewhere in the middle, and flies home on a booking that is very often made
-- two days before it happens. That arc is the single most-asked question about
-- any member of the mission — **where is he, and when does he come back** — and
-- until this migration the schema had no way to answer it.
--
-- What existed instead: `jeddah_airport_reception` (0034) and `central_aviation`
-- (0036) describe following flights and receiving returnees as DUTIES, in prose,
-- on an operational file, with the manifests attached as PDFs. That is a record
-- of the work of watching flights. It is not a record of who is on one.
--
-- ---------------------------------------------------------- what this is not
--
-- It is not three tables. The obvious shape — an `arrival_flight`, a
-- `return_flight` and a `train_trip` hanging off the employee — is wrong twice
-- over, and both ways are expensive:
--
--   * It puts travel on the PERSON, so next season inherits this season's
--     flights and somebody has to write code to forget them.
--   * It hard-codes the three movements that happen to exist in 1448. A fourth
--     (a tracked جدة→مكة coach, an عمرة leg before the Hajj) is then a fourth
--     table, a fourth screen, a fourth set of permissions and a fourth
--     attachment bucket.
--
-- So: ONE movement table, anchored on `season_participants` — the row that
-- already means "this person, in this season", that has existed since 0005 and
-- has been under RLS ever since. A new season is a new participation row and
-- therefore an empty journey **by construction**. There is no copy-forward to
-- suppress because there is nothing that could carry over.
--
-- ---------------------------------------------- the split that does the work
--
-- Two tables, and the line between them is the whole design:
--
--   `trips`         the VEHICLE and its schedule. SR441, دمشق ← جدة, 02:15.
--                   Exists before anybody is on it. Knows nothing about who is.
--   `journey_legs`  this PARTICIPANT on that vehicle — or moving under his own
--                   arrangements. Carries his ticket, his seat, HIS actual
--                   times, and his own status.
--
-- Both directions the operations room needs fall out for free: from the trip to
-- its passengers, and from the man to his whole journey. And a schedule change
-- on a flight carrying sixty people is ONE edit, not sixty, because the planned
-- time lives on the vehicle.
--
-- ------------------------------------------------ the train is not mandatory
--
-- The hardest requirement here, and it is answered by refusing to ask the wrong
-- question. The system does not ask "where is his train booking?" — it asks
-- **"how did this man get from مكة to المدينة?"**, and «بسيارة خاصة» is a
-- COMPLETE answer, not an exception to be worked around.
--
-- That is what `trip_id` being nullable means. A leg with no trip is a
-- self-arranged movement: a first-class row, drawn on the timeline exactly like
-- a flight, with a car for an icon. The only state that deserves anybody's
-- attention is «we do not know», and even that is grey with a button on it —
-- red is reserved for `missed` and `cancelled`, for things that HAPPENED and
-- went badly, never for something merely unwritten.

-- ====================================================== 1. not everybody goes
--
-- Some of the mission is already in the Kingdom — hired locally, seconded from
-- an office in جدة, external staff who never see a Syrian airport. Without a
-- way to say so, the gaps board would spend every day of the season shouting
-- that forty people have no arrival flight and never will, and a tool that
-- cries wolf is a tool nobody opens in the second week.
--
-- Default true because the overwhelming majority DO travel, and a default that
-- is wrong for most rows is a data-entry tax on the whole roster.

alter table season_participants
  add column if not exists travels boolean not null default true;

comment on column season_participants.travels is
  'Whether this participation involves travelling to the Kingdom at all. False '
  'for staff already resident there. Purely about expectations: it changes '
  'nothing about what may be recorded, only whether the ABSENCE of an arrival '
  'or return leg counts as a gap worth reporting.';

-- ========================================================== 2. the vocabulary
--
-- Enums rather than reference lists, and the distinction matters. A reference
-- list is data the Administration edits; an enum is a word the CODE reasons
-- about. The return countdown has to know which leg is the way home, and the
-- gaps board has to know which status still needs answering — neither may
-- depend on a row somebody can rename on a Tuesday.
--
-- Extending any of them later is `alter type ... add value`, exactly as
-- `module_field_kind` has been extended four times (0018, 0020, 0022, 0066).
-- Adding a mode costs one line here and one arm of an icon switch in Dart.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'travel_mode') then
    create type travel_mode as enum ('air', 'rail', 'road', 'other');
  end if;

  -- What a movement is FOR, which is not the same as what carries it: the
  -- return may be a flight one year and something else the next, and it is
  -- still the return.
  if not exists (select 1 from pg_type where typname = 'leg_role') then
    create type leg_role as enum ('inbound', 'internal', 'outbound');
  end if;

  -- A fact about the VEHICLE. Everyone on it shares it.
  if not exists (select 1 from pg_type where typname = 'trip_status') then
    create type trip_status as enum
      ('scheduled', 'delayed', 'departed', 'arrived', 'cancelled');
  end if;

  -- A fact about ONE MAN on that vehicle, and deliberately a different list.
  -- A flight can land with everybody aboard except one, and `arrived` on the
  -- trip must never be able to say anything about him.
  --
  --   planned    booked, nothing confirmed
  --   confirmed  he is going / he boarded
  --   completed  he arrived. THIS is what moves him on the map
  --   missed     he did not travel on it
  --   cancelled  the movement is off and is not being replaced
  --   rebooked   superseded by another leg — kept, never deleted (BR-5)
  if not exists (select 1 from pg_type where typname = 'leg_status') then
    create type leg_status as enum
      ('planned', 'confirmed', 'completed', 'missed', 'cancelled', 'rebooked');
  end if;
end
$$;

-- ============================================ 3. where a journey touches down
--
-- A reference set rather than a table, for 0064's reason stated again: every
-- thing this needs — the shared editor screen, the guard that refuses to delete
-- an entry something points at, the audit trail, the two-language name — is
-- already what master data does. A table would have bought nothing and cost a
-- screen.
--
-- NOT season-scoped: مطار دمشق is مطار دمشق every year. NOT `is_place`: a check-in
-- code is printed for somewhere a man stands and is counted (0098), and an
-- airport is somewhere he passes through.
--
-- Cities sit in the same list as airports and stations, and that is deliberate.
-- A private car goes مكة ← المدينة, city to city; a flight goes airport to
-- airport. One list holds both because they answer the same question — where
-- did this movement start and end — and splitting them would mean two pickers
-- on one form.

insert into reference_sets (code, name_ar, name_en, is_season_scoped)
values ('travel_points', 'نقاط السفر', 'Travel points', false)
on conflict (code) do nothing;

-- Which city it is in, so a journey can be read as a line of PLACES rather than
-- a line of terminals. Text and not a reference: half these cities are Saudi
-- and `syrian_cities` (0023) cannot hold them, and a second city list existing
-- only to be pointed at here is more machinery than the answer is worth.
insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, is_required, sort_order)
select rs.id, 'city', 'المدينة', 'City', 'text'::module_field_kind, false, 1
from reference_sets rs
where rs.code = 'travel_points'
on conflict (set_id, key) do nothing;

-- The points this mission actually uses. Seeded rather than left empty because
-- an empty picker on the first screen somebody opens reads as a broken feature,
-- and these nine have not changed in years. Anything else is one row in master
-- data — no migration, no code.
insert into reference_items (set_id, name_ar, name_en, sort_order)
select rs.id, v.name_ar, v.name_en, v.sort_order
from (values
  ('مطار دمشق الدولي',              'Damascus International Airport',      1),
  ('مطار حلب الدولي',               'Aleppo International Airport',        2),
  ('مطار الملك عبدالعزيز الدولي',   'King Abdulaziz International Airport', 3),
  ('مطار الأمير محمد بن عبدالعزيز', 'Prince Mohammad bin Abdulaziz Airport', 4),
  ('محطة مكة المكرمة',              'Makkah Station',                      5),
  ('محطة المدينة المنورة',          'Madinah Station',                     6),
  ('مكة المكرمة',                   'Makkah',                              7),
  ('المدينة المنورة',               'Madinah',                             8),
  ('جدة',                           'Jeddah',                              9)
) as v(name_ar, name_en, sort_order)
cross join reference_sets rs
where rs.code = 'travel_points'
on conflict do nothing;

-- ================================================================ 4. the trip

create table if not exists trips (
  id uuid primary key default gen_random_uuid(),

  -- The season owns it. `restrict` and not `cascade`: deleting a season out
  -- from under a year of travel records is not a thing anybody should be able
  -- to do by accident.
  season_id uuid not null references seasons (id) on delete restrict,

  mode travel_mode not null,
  role leg_role not null,

  from_point_id uuid not null references reference_items (id) on delete restrict,
  to_point_id uuid not null references reference_items (id) on delete restrict,

  -- «الجدير للطيران», «SR441». Free text: the carrier list of a Syrian charter
  -- season changes more often than a reference list would be maintained, and
  -- nothing in the code reasons about which airline it was.
  carrier text,
  trip_number text,

  -- Required, and this is the line that defines what a trip IS.
  --
  -- A trip is a SCHEDULED departure. If the time is not known, what exists is
  -- an intention, not a trip, and it should not be created yet — because the
  -- moment it is, every leg hung off it inherits a null departure, the return
  -- countdown silently has nothing to count, and the gaps board reports the man
  -- as handled. An absent trip is visible; a timeless one is not.
  planned_departure_at timestamptz not null,

  -- Not required. Often genuinely unknown at booking, and nothing depends on
  -- it: arrival is measured by what the man confirms, not by the timetable.
  planned_arrival_at timestamptz,

  status trip_status not null default 'scheduled',
  note text,

  created_at timestamptz not null default now(),
  created_by uuid references profiles (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references profiles (id)
);

create index if not exists idx_trips_season on trips (season_id);
create index if not exists idx_trips_season_departure
  on trips (season_id, planned_departure_at);

comment on table trips is
  'One vehicle and its schedule, within one season. Knows nothing about who is '
  'on it — that is journey_legs. Created before anybody is assigned, which is '
  'what makes bulk assignment possible at all.';

-- ================================================================= 5. the leg

create table if not exists journey_legs (
  id uuid primary key default gen_random_uuid(),

  -- The anchor of this whole feature. Not `profile_id`: travel belongs to a
  -- man's PARTICIPATION in a season, which is what keeps next year clean.
  participant_id uuid not null
    references season_participants (id) on delete cascade,

  -- Null means he arranged it himself — a private car, a lift with a colleague,
  -- anything the mission did not book. NOT a defect and never rendered as one.
  --
  -- `restrict` rather than `cascade` (BR-11): a flight with passengers on it
  -- cannot be deleted out from under them. Cancelling is a status, and it is
  -- not the same act as erasing.
  trip_id uuid references trips (id) on delete restrict,

  -- Stored even when there is a trip, and the only column of which that is
  -- true. It is mirrored from the trip by a BEFORE trigger and can therefore
  -- never disagree with it — it exists because the "one live arrival, one live
  -- return" rule (BR-10) is a partial unique index, and an index cannot reach
  -- through a foreign key to ask the trip what role it was.
  role leg_role not null,

  -- The five columns below are the SELF-ARRANGED half of the row, and are null
  -- exactly when `trip_id` is not. See the constraint after this table: the
  -- plan has one source, never two.
  mode travel_mode,
  from_point_id uuid references reference_items (id) on delete restrict,
  to_point_id uuid references reference_items (id) on delete restrict,
  planned_departure_at timestamptz,
  planned_arrival_at timestamptz,

  -- What actually happened to THIS man. Always on the leg, never on the trip:
  -- sixty people share a departure time and not one of them shares an arrival.
  actual_departure_at timestamptz,
  actual_arrival_at timestamptz,

  status leg_status not null default 'planned',

  ticket_ref text,
  seat text,
  note text,

  -- Where a rebooking points back to (BR-5). The old leg is marked `rebooked`
  -- and kept; the new one names it. Nothing is deleted, so "what was planned,
  -- what changed" is answerable from the rows themselves and not only from the
  -- audit log.
  replaces_leg_id uuid references journey_legs (id) on delete set null,

  -- Who said it happened, and when they said it. Recorded because for a private
  -- car there IS no other source — no airline feed, no gate, nothing but a man
  -- saying he arrived. A record like that is worth what its provenance is worth.
  confirmed_by uuid references profiles (id),
  confirmed_at timestamptz,

  created_at timestamptz not null default now(),
  created_by uuid references profiles (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references profiles (id),

  -- BR-4 — the plan comes from the trip, or from the leg, and never from both.
  --
  -- Two sources for one departure time is a schema that can contradict itself,
  -- and it would contradict itself on exactly the day it matters: a flight
  -- delayed by six hours, edited once on the trip, with sixty legs still
  -- carrying the old time underneath.
  constraint leg_plan_has_one_source check (
    case when trip_id is null then
      mode is not null
      and from_point_id is not null
      and to_point_id is not null
      and planned_departure_at is not null
    else
      mode is null
      and from_point_id is null
      and to_point_id is null
      and planned_departure_at is null
      and planned_arrival_at is null
    end
  ),

  -- A confirmation without a confirmer is an assertion from nowhere.
  constraint leg_confirmation_is_attributed check (
    (confirmed_by is null) = (confirmed_at is null)
  )
);

create index if not exists idx_journey_legs_participant
  on journey_legs (participant_id);
create index if not exists idx_journey_legs_trip
  on journey_legs (trip_id) where trip_id is not null;

-- BR-10 — one LIVE arrival and one LIVE return per participation.
--
-- Scoped to `inbound` and `outbound` only, because `internal` legitimately
-- repeats: مكة → المدينة and back again is two internal movements and both are
-- true. And scoped to the live statuses, because the whole point of keeping
-- `rebooked`, `cancelled` and `missed` rows is that a man may have four
-- historical arrival legs and exactly one that still stands.
create unique index if not exists one_live_leg_per_role
  on journey_legs (participant_id, role)
  where role in ('inbound', 'outbound')
    and status in ('planned', 'confirmed', 'completed');

comment on table journey_legs is
  'One movement of one participant. trip_id null means he arranged it himself '
  '(a private car) — a first-class movement, not a missing booking.';

-- ================================================== 6. the rule about seasons
--
-- BR-2. A leg joins a participation to a trip, and both of them name a season.
-- Nothing in the foreign keys stops those two seasons being different, and the
-- result would be silent and awful: a man appearing on last year's flight, a
-- passenger count that includes people who were not in the mission that year.
--
-- The same trigger mirrors `role` down from the trip, so the column BR-10 reads
-- is maintained by the database and not by whatever wrote the row.

create or replace function journey_leg_agrees_with_its_trip() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_trip_season uuid;
  v_trip_role leg_role;
  v_participant_season uuid;
begin
  if new.trip_id is null then
    return new;
  end if;

  select season_id, role into v_trip_season, v_trip_role
    from trips where id = new.trip_id;

  select season_id into v_participant_season
    from season_participants where id = new.participant_id;

  if v_trip_season is distinct from v_participant_season then
    raise exception
      'a leg cannot put a participant of one season on a trip of another'
      using errcode = 'check_violation';
  end if;

  -- Mirrored, not trusted from the caller.
  new.role := v_trip_role;
  return new;
end;
$$;

drop trigger if exists journey_legs_agree on journey_legs;
create trigger journey_legs_agree before insert or update on journey_legs
  for each row execute function journey_leg_agrees_with_its_trip();

-- Editing a trip's role after legs hang off it would leave those legs mirroring
-- something that is no longer true. Cheap to re-sync; the alternative is a
-- column that quietly rots.
create or replace function trip_role_flows_to_its_legs() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role then
    update journey_legs set role = new.role where trip_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trips_role_flows on trips;
create trigger trips_role_flows after update on trips
  for each row execute function trip_role_flows_to_its_legs();

-- ============================================================ 7. what is kept
--
-- The ticket, the manifest, the booking confirmation. Two tables and not one:
-- a manifest attached to a FLIGHT is everybody's and a boarding pass is one
-- man's, and those are different questions of who may read it — which is to say
-- different RLS policies, which is to say different tables.
--
-- Same columns as every attachment table in this schema since 0031, and for the
-- reason 0031 gave: the row is what says a reader may see the file, so it has
-- to be something a policy can be written against. A jsonb column could not be.

create table if not exists trip_attachments (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references trips (id) on delete cascade,
  kind attachment_kind not null,
  path text not null,
  name text not null,
  mime_type text,
  size_bytes bigint,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_trip_attachments_trip
  on trip_attachments (trip_id);

create table if not exists leg_attachments (
  id uuid primary key default gen_random_uuid(),
  leg_id uuid not null references journey_legs (id) on delete cascade,
  kind attachment_kind not null,
  path text not null,
  name text not null,
  mime_type text,
  size_bytes bigint,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_leg_attachments_leg
  on leg_attachments (leg_id);

-- ========================================================== 8. the permissions
--
-- Six codes, and the splits are the argument.

insert into permissions (code, description, sort_order)
values ('travel', 'Travel and movement section', 16)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('travel.view',     'See a colleague''s journey on their page', 1),
  ('travel.view_all', 'See every trip and journey of the season', 2),
  ('travel.edit',     'Create and change trips', 3),
  ('travel.assign',   'Put people on trips and move them between them', 4),
  ('travel.confirm',  'Record what actually happened — departures, arrivals', 5),
  ('travel.delete',   'Delete a trip', 6)
) as v(code, description, sort_order)
join permissions p on p.code = 'travel'
on conflict (code) do nothing;

-- The prerequisites. Enforced by 0073's triggers; written here so the
-- permissions editor can explain itself to whoever is granting.
--
-- `travel.confirm` stands apart from `travel.edit` on purpose, the same way
-- `employees.password` stands apart from `employees.edit` (0072): the man at
-- the airport gate ticking off sixty arrivals should be able to do exactly
-- that, and not to rewrite the timetable.
--
-- `travel.assign` stands apart for the mirror reason: whoever knows which
-- people travel together is rarely the same person who types in flight numbers.
insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from (values
  ('travel.view',     'employees.view'),
  ('travel.view_all', 'travel.view'),
  ('travel.edit',     'travel.view_all'),
  ('travel.assign',   'travel.view_all'),
  ('travel.confirm',  'travel.view_all'),
  ('travel.delete',   'travel.edit')
) as v(child, requires)
join permissions c on c.code = v.child
join permissions r on r.code = v.requires
on conflict do nothing;

-- ================================================================ 9. who sees
--
-- BR-7 runs through all of this: **a man always sees his own journey**, with no
-- code granted to him. It is the same judgement 0079 made about filing a
-- complaint — a record of where a man is being sent that he himself cannot read
-- is not a record worth keeping.

alter table trips enable row level security;
alter table journey_legs enable row level security;
alter table trip_attachments enable row level security;
alter table leg_attachments enable row level security;

-- A trip is visible to whoever runs the season's travel, and to anybody who is
-- ON it. The second clause is not a nicety: without it a man could read his own
-- leg and not the flight number it points at.
drop policy if exists trips_select on trips;
create policy trips_select on trips for select using (
  is_admin()
  or has_permission('travel.view')
  or exists (
    select 1
      from journey_legs l
      join season_participants sp on sp.id = l.participant_id
     where l.trip_id = trips.id and sp.profile_id = auth.uid()
  )
);

drop policy if exists trips_insert on trips;
create policy trips_insert on trips for insert
  with check (is_admin() or has_permission('travel.edit'));

-- `travel.confirm` may update a trip too — marking a flight departed or landed
-- is recording what happened, not redesigning the schedule. What it must never
-- do is write anybody's leg; that stays a separate, deliberate act (BR-6).
drop policy if exists trips_update on trips;
create policy trips_update on trips for update using (
  is_admin() or has_permission('travel.edit') or has_permission('travel.confirm')
);

drop policy if exists trips_delete on trips;
create policy trips_delete on trips for delete
  using (is_admin() or has_permission('travel.delete'));

-- Legs: the whole register to whoever keeps it, and his own to everybody.
drop policy if exists journey_legs_select on journey_legs;
create policy journey_legs_select on journey_legs for select using (
  is_admin()
  or has_permission('travel.view')
  or exists (
    select 1 from season_participants sp
     where sp.id = journey_legs.participant_id and sp.profile_id = auth.uid()
  )
);

-- Putting a man on a flight is `travel.assign` and nothing else. A man may not
-- insert his own leg through this policy either — his self-arranged movements
-- go through `record_self_leg` (0130), which is where the rules about what he
-- may claim for himself are written down in one place.
drop policy if exists journey_legs_insert on journey_legs;
create policy journey_legs_insert on journey_legs for insert
  with check (is_admin() or has_permission('travel.assign'));

-- Deliberately NOT extended to the traveller. Confirming his own arrival is a
-- function call with a narrow signature (`confirm_leg`, 0130); a general update
-- policy would let him rewrite his flight number, and RLS cannot restrict which
-- columns an update touches.
drop policy if exists journey_legs_update on journey_legs;
create policy journey_legs_update on journey_legs for update using (
  is_admin()
  or has_permission('travel.assign')
  or has_permission('travel.confirm')
);

drop policy if exists journey_legs_delete on journey_legs;
create policy journey_legs_delete on journey_legs for delete
  using (is_admin() or has_permission('travel.assign'));

-- Attachments defer to the row they hang off, exactly as 0031's do: that row's
-- own policy is the single source of truth about who may read this, and
-- restating it here would be a second place for it to drift.
drop policy if exists trip_attachments_select on trip_attachments;
create policy trip_attachments_select on trip_attachments for select using (
  exists (select 1 from trips t where t.id = trip_attachments.trip_id)
);

drop policy if exists trip_attachments_write on trip_attachments;
create policy trip_attachments_write on trip_attachments for all
  using (is_admin() or has_permission('travel.edit'))
  with check (is_admin() or has_permission('travel.edit'));

drop policy if exists leg_attachments_select on leg_attachments;
create policy leg_attachments_select on leg_attachments for select using (
  exists (select 1 from journey_legs l where l.id = leg_attachments.leg_id)
);

-- A man may attach his own boarding pass. He is the one holding it.
drop policy if exists leg_attachments_write on leg_attachments;
create policy leg_attachments_write on leg_attachments for all
  using (
    is_admin()
    or has_permission('travel.assign')
    or has_permission('travel.confirm')
    or exists (
      select 1 from journey_legs l
      join season_participants sp on sp.id = l.participant_id
       where l.id = leg_attachments.leg_id and sp.profile_id = auth.uid()
    )
  )
  with check (
    is_admin()
    or has_permission('travel.assign')
    or has_permission('travel.confirm')
    or exists (
      select 1 from journey_legs l
      join season_participants sp on sp.id = l.participant_id
       where l.id = leg_attachments.leg_id and sp.profile_id = auth.uid()
    )
  );

-- ================================================================ 10. storage
--
-- One bucket, two path prefixes: `trips/{trip_id}/…` and `legs/{leg_id}/…`.
-- One bucket rather than two because the read rule is the same shape in both
-- cases — ask the row — and the prefix is enough to know which row to ask.

insert into storage.buckets (id, name, public)
values ('travel', 'travel', false)
on conflict (id) do nothing;

create or replace function can_read_travel_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_prefix text;
  v_id uuid;
begin
  if is_admin() or has_permission('travel.view') then
    return true;
  end if;

  begin
    v_prefix := (storage.foldername(p_path))[1];
    v_id := (storage.foldername(p_path))[2]::uuid;
  exception when others then
    return false;
  end;

  if v_prefix = 'trips' then
    -- Readable by anybody travelling on it: the manifest and the schedule PDF
    -- are exactly what a passenger is meant to have.
    return exists (
      select 1 from journey_legs l
      join season_participants sp on sp.id = l.participant_id
       where l.trip_id = v_id and sp.profile_id = auth.uid()
    );
  elsif v_prefix = 'legs' then
    return exists (
      select 1 from journey_legs l
      join season_participants sp on sp.id = l.participant_id
       where l.id = v_id and sp.profile_id = auth.uid()
    );
  end if;

  return false;
end;
$$;

create or replace function can_write_travel_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_prefix text;
  v_id uuid;
begin
  if is_admin()
     or has_permission('travel.edit')
     or has_permission('travel.assign')
     or has_permission('travel.confirm') then
    return true;
  end if;

  begin
    v_prefix := (storage.foldername(p_path))[1];
    v_id := (storage.foldername(p_path))[2]::uuid;
  exception when others then
    return false;
  end;

  -- His own boarding pass, onto his own leg. Nothing else.
  return v_prefix = 'legs' and exists (
    select 1 from journey_legs l
    join season_participants sp on sp.id = l.participant_id
     where l.id = v_id and sp.profile_id = auth.uid()
  );
end;
$$;

drop policy if exists travel_files_read on storage.objects;
create policy travel_files_read on storage.objects for select
  to authenticated using (
    bucket_id = 'travel' and public.can_read_travel_file(name)
  );

drop policy if exists travel_files_write on storage.objects;
create policy travel_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'travel' and public.can_write_travel_file(name)
  );

drop policy if exists travel_files_update on storage.objects;
create policy travel_files_update on storage.objects for update
  to authenticated using (
    bucket_id = 'travel' and public.can_write_travel_file(name)
  );

drop policy if exists travel_files_delete on storage.objects;
create policy travel_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'travel' and public.can_write_travel_file(name)
  );

-- ============================================================== 11. the record
--
-- 0077 attached its trigger to the tables that existed the day it ran, and said
-- in as many words that a table created afterwards starts unaudited and must
-- attach its own. 0122 went back for three that never did. These do it here.
--
-- It matters more than usual for this feature: "what was planned, what changed,
-- and what actually happened" is a stated requirement, and half of it — who
-- moved this man off that flight, and when — is answerable only from the log.

drop trigger if exists audit_row on trips;
create trigger audit_row after insert or update or delete on trips
  for each row execute function audit_row_change();

drop trigger if exists audit_row on journey_legs;
create trigger audit_row after insert or update or delete on journey_legs
  for each row execute function audit_row_change();

-- ================================================ 12. a point that is in use
--
-- The foreign keys already refuse to let مطار جدة be deleted while flights
-- point at it. `reference_item_in_use` is what turns that refusal into a
-- sentence the master-data screen can show — the argument 0030 made for the
-- city and 0085 repeated for the job title, and it applies here for the same
-- reason: a constraint error in English is not an explanation.
--
-- Restated whole on top of 0085's version, for the same reason as the label
-- function above.
create or replace function reference_item_in_use(p_item_id uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select
    exists (
      select 1
      from modules m
      join module_type_fields f on f.module_type_id = m.module_type_id
      where f.kind = 'reference'
        and m.data ->> f.key = p_item_id::text
    )
    or exists (
      select 1 from module_nodes where reference_item_id = p_item_id
    )
    or exists (
      select 1
      from reference_items i
      join reference_set_fields f on f.set_id = i.set_id
      where f.kind = 'reference'
        and i.data ->> f.key = p_item_id::text
    )
    or exists (
      select 1 from profiles
      where city_id = p_item_id
         or job_title_id = p_item_id
         or mission_type_id = p_item_id
    )
    -- New in 0129. Both ends of both tables: a point is in use whether it is
    -- where a flight leaves from or where a man drove to.
    or exists (
      select 1 from trips
      where from_point_id = p_item_id or to_point_id = p_item_id
    )
    or exists (
      select 1 from journey_legs
      where from_point_id = p_item_id or to_point_id = p_item_id
    );
$$;

-- ------------------------------------------------------------ what they SAY
--
-- A trigger with no label is half the job, as 0122 put it. `audit_record_label`
-- falls back on six columns — `name_ar`, `title`, `name`, `label`, `code`,
-- `email` — and neither of these two tables carries any of them, so every line
-- they wrote would read as a bare uuid in a column of Arabic sentences.
--
-- Restated whole on top of 0122's version: the body is one CASE and Postgres
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
    -- New in 0129. The flight number first when there is one, because that is
    -- what the room calls it; the route always, because a trip with no number
    -- (a coach, a car) is still a line between two places.
    when 'trips' then
      nullif(concat_ws(' — ',
        nullif(btrim(coalesce(p_row ->> 'trip_number', '')), ''),
        concat_ws(' ← ',
          (select ri.name_ar from reference_items ri
            where ri.id = (p_row ->> 'from_point_id')::uuid),
          (select ri.name_ar from reference_items ri
            where ri.id = (p_row ->> 'to_point_id')::uuid))), '')
    -- Whose movement, and on what. The man's name comes first for the same
    -- reason it does on a check-in: every question ever asked of this row is
    -- about a person.
    when 'journey_legs' then
      concat_ws(' — ',
        (select audit_actor_name(sp.profile_id) from season_participants sp
          where sp.id = (p_row ->> 'participant_id')::uuid),
        coalesce(
          (select nullif(concat_ws(' ',
                    nullif(btrim(coalesce(t.trip_number, '')), ''),
                    to_char(t.planned_departure_at, 'YYYY-MM-DD')), '')
             from trips t where t.id = (p_row ->> 'trip_id')::uuid),
          -- No trip: he arranged it himself, and the honest label says so
          -- rather than leaving the second half of the line blank.
          'ترتيب ذاتي'))
    else null
  end;

  return coalesce(v,
    p_row ->> 'name_ar', p_row ->> 'title', p_row ->> 'name',
    p_row ->> 'label', p_row ->> 'code', p_row ->> 'email');
exception when others then
  return null;
end;
$$;
