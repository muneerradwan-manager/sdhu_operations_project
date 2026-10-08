-- The thing that cannot wait.
--
-- This app already has a place for "something went wrong": the complaints
-- register (0079). It is deliberately slow and structurally secret — the
-- accused cannot learn who complained, a thread can be locked, three separate
-- complainants suspend an account. Every one of those properties is right for
-- what it is, and every one of them is wrong for a bus broken down on the road
-- to Arafat with two hundred pilgrims on it.
--
-- A complaint asks for a JUDGEMENT, later. An incident asks for SOMEBODY TO
-- COME, now. They are not the same record and must not share a table: a form
-- that makes a man choose which of five categories his emergency falls under,
-- and hides his name from the person who could send help, is a form he will
-- close and telephone somebody instead — which is exactly what this is meant to
-- replace.
--
-- So the design is the opposite of the complaint's at every point:
--
--   * **No secrecy.** The reporter's name is the first thing shown. Whoever
--     receives it needs to call him back within the minute.
--   * **Almost no form.** A line of text. Everything else — where he is, when,
--     who he is, which file he is in — the app already knows and attaches.
--   * **Nothing is required to send.** Not a photograph, not a category, not a
--     location. A report that took thirty seconds to compose is a report that
--     was never sent.
--   * **It has a lifecycle**, because "did anybody go?" is the only question
--     that matters afterwards, and a register that cannot answer it is a diary.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'incident_state') then
    -- Three, and the middle one is the point. Two states cannot tell "somebody
    -- has seen this" from "somebody is on their way", and during those five
    -- days that is the difference the operations room is actually managing.
    create type incident_state as enum ('open', 'in_progress', 'closed');
  end if;
end
$$;

create table if not exists incidents (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles (id) on delete cascade,

  -- Which file he was in when he sent it, if any. Not required: the worst
  -- moments are not tidy, and a man who is not currently inside a file still
  -- has an emergency worth hearing.
  module_id uuid references modules (id) on delete set null,
  node_id uuid references module_nodes (id) on delete set null,

  body text not null,

  -- Where the phone said he was. The single most useful field on the record and
  -- the one nobody has to fill in.
  latitude double precision,
  longitude double precision,
  accuracy_m double precision,

  state incident_state not null default 'open',

  -- Who picked it up, and when it stopped being open. Both null while it is.
  handled_by uuid references profiles (id) on delete set null,
  handled_at timestamptz,
  closed_at timestamptz,
  resolution text,

  created_at timestamptz not null default now()
);

create index if not exists idx_incidents_open
  on incidents (state, created_at desc);
create index if not exists idx_incidents_reporter
  on incidents (reporter_id, created_at desc);

-- Evidence, on the same footing as everywhere else in this app.
create table if not exists incident_attachments (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references incidents (id) on delete cascade,
  kind attachment_kind not null,
  path text not null,
  name text not null,
  mime_type text,
  size_bytes bigint,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_incident_attachments
  on incident_attachments (incident_id, sort_order);

alter table incidents enable row level security;
alter table incident_attachments enable row level security;

-- ------------------------------------------------------------- the permission
--
-- One code, and it is a DUTY rather than a privilege: whoever holds it is on
-- the receiving end of every emergency in the mission and is expected to answer
-- it. The Administration grants it to the operations room.
--
-- FILING one is deliberately absent, exactly as it is for complaints. Anybody
-- with a working account may report an emergency; a system where only certain
-- people may say that a bus has broken down is a system that does not find out
-- about the bus.
insert into permissions (code, description, sort_order)
values ('incidents', 'Urgent reports section', 11)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('incidents.receive', 'Receive and read every urgent report', 1),
  ('incidents.handle',  'Take on an urgent report and close it', 2)
) as v(code, description, sort_order)
join permissions p on p.code = 'incidents'
on conflict (code) do nothing;

-- Acting on one requires being able to see them. The trigger from 0073 enforces
-- this; stated here so the editor can explain itself.
insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from permissions c, permissions r
where c.code = 'incidents.handle' and r.code = 'incidents.receive'
on conflict do nothing;

-- ------------------------------------------------------------------ policies
--
-- Read: the man who sent it, and the room that receives them. No third case —
-- an emergency is not gossip, and the register is not a feed.
drop policy if exists incidents_select on incidents;
create policy incidents_select on incidents for select
  using (
    reporter_id = auth.uid()
    or is_admin()
    or has_permission('incidents.receive')
  );

-- Anyone may raise one, for himself only. `reporter_id = auth.uid()` is what
-- makes the name on the record mean something.
drop policy if exists incidents_insert on incidents;
create policy incidents_insert on incidents for insert
  with check (reporter_id = auth.uid() and is_approved());

-- Moving it along belongs to the room. The reporter deliberately cannot close
-- his own: "it is fine now" from the man who raised it is not the same fact as
-- "somebody went and dealt with it", and only the second one is worth keeping.
drop policy if exists incidents_update on incidents;
create policy incidents_update on incidents for update
  using (is_admin() or has_permission('incidents.handle'))
  with check (is_admin() or has_permission('incidents.handle'));

drop policy if exists incident_attachments_select on incident_attachments;
create policy incident_attachments_select on incident_attachments for select
  using (
    exists (
      select 1 from incidents i
       where i.id = incident_id
         and (
           i.reporter_id = auth.uid()
           or is_admin()
           or has_permission('incidents.receive')
         )
    )
  );

drop policy if exists incident_attachments_insert on incident_attachments;
create policy incident_attachments_insert on incident_attachments for insert
  with check (
    exists (
      select 1 from incidents i
       where i.id = incident_id and i.reporter_id = auth.uid()
    )
  );

-- ------------------------------------------------- asking about someone else
--
-- `has_permission` asks about the CALLER, which is all anything in this schema
-- has ever needed. Sending an alarm means asking about EVERYBODY ELSE, and
-- there was no way to do that until now.
--
-- It mirrors `has_permission` (0012) exactly, including the two conditions that
-- are easy to leave out and expensive to leave out: a suspended account and an
-- unapproved one hold no permissions. Without them, the operations room's alarm
-- would go to somebody the Administration has already switched off — which is
-- an emergency delivered to a person who cannot act on it and, worse, counted
-- as delivered.
create or replace function has_permission_for(p_profile_id uuid, p_code text)
  returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles pr
     where pr.id = p_profile_id
       and pr.is_admin
       and not pr.is_suspended
       and pr.account_status = 'approved'
  ) or exists (
    select 1
      from user_permissions up
      join permissions perm on perm.id = up.permission_id
      join profiles pr on pr.id = up.user_id
     where up.user_id = p_profile_id
       and perm.code = p_code
       and not pr.is_suspended
       and pr.account_status = 'approved'
  );
$$;

revoke execute on function has_permission_for(uuid, text) from public, anon;

-- ------------------------------------------------------------------- raising
--
-- One call, and it does the telling as well as the recording.
--
-- The notification is sent HERE rather than by a trigger or by the app, and the
-- reason is that this is the one message in the system that must not be lost to
-- a client that closed, a network that dropped or a queue that was not drained.
-- The row and the alarm are written in one transaction: if the incident exists,
-- the room has been told.
create or replace function raise_incident(
  p_body text,
  p_module_id uuid default null,
  p_node_id uuid default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_accuracy double precision default null
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_name text;
  v_where text;
begin
  if not is_approved() then
    raise exception 'not authorized';
  end if;
  if btrim(coalesce(p_body, '')) = '' then
    raise exception 'incident_body_required';
  end if;

  insert into incidents (
    reporter_id, module_id, node_id, body, latitude, longitude, accuracy_m
  )
  values (
    auth.uid(), p_module_id, p_node_id, btrim(p_body), p_lat, p_lng, p_accuracy
  )
  returning id into v_id;

  select concat_ws(' ', p.first_name, p.father_name, p.surname)
    into v_name
    from profiles p where p.id = auth.uid();

  -- The place, if the app could say where he was. Put in the BODY of the
  -- notification rather than only in the payload: whoever is woken by this
  -- reads a line of text on a lock screen, and "بلاغ عاجل" alone tells him
  -- nothing he can act on.
  select coalesce(n.label, ri.name_ar, mt.name_ar)
    into v_where
    from modules m
    left join module_types mt on mt.id = m.module_type_id
    left join module_nodes n on n.id = p_node_id
    left join reference_items ri on ri.id = n.reference_item_id
   where m.id = p_module_id;

  insert into notifications (recipient_id, sender_id, title, body, data)
  select p.id,
         auth.uid(),
         'بلاغ عاجل',
         concat_ws(' — ',
           nullif(coalesce(v_name, ''), ''),
           nullif(coalesce(v_where, ''), ''),
           left(btrim(p_body), 120)
         ),
         jsonb_build_object(
           'type', 'incident',
           'incident_id', v_id,
           'module_id', p_module_id
         )
    from profiles p
    -- The status conditions live inside has_permission_for; repeating them
    -- here would be two places to keep in step. Only "not the man who sent it"
    -- belongs to this query.
   where p.id <> auth.uid()
     and has_permission_for(p.id, 'incidents.receive');

  return v_id;
end;
$$;

revoke execute on function raise_incident(
  text, uuid, uuid, double precision, double precision, double precision
) from public, anon;
grant execute on function raise_incident(
  text, uuid, uuid, double precision, double precision, double precision
) to authenticated;

revoke execute on function has_permission_for(uuid, text) from public, anon;

-- ------------------------------------------------------------------ handling
--
-- Taking one on, and letting it go.
create or replace function set_incident_state(
  p_incident_id uuid,
  p_state incident_state,
  p_resolution text default null
) returns void
  language plpgsql security definer set search_path = public as $$
begin
  if not (is_admin() or has_permission('incidents.handle')) then
    raise exception 'not authorized';
  end if;

  update incidents
     set state = p_state,
         -- Stamped on the FIRST person to pick it up and not overwritten
         -- afterwards. The question the register answers is "how long did this
         -- sit unanswered", and a field that moves every time somebody edits
         -- the row cannot answer it.
         handled_by = coalesce(handled_by, auth.uid()),
         handled_at = case
           when p_state = 'open' then null
           else coalesce(handled_at, now())
         end,
         closed_at = case when p_state = 'closed' then now() else null end,
         resolution = coalesce(nullif(btrim(coalesce(p_resolution, '')), ''),
                               resolution)
   where id = p_incident_id;

  if not found then
    raise exception 'incident_not_found';
  end if;
end;
$$;

revoke execute on function set_incident_state(uuid, incident_state, text)
  from public, anon;
grant execute on function set_incident_state(uuid, incident_state, text)
  to authenticated;

-- --------------------------------------------------------------- the register
--
-- Open ones first, then by age. Not by "newest first" as every other list in
-- this app is: an emergency that has been sitting for forty minutes matters
-- more than one raised a moment ago, and putting the new one on top is how the
-- old one is never looked at again.
create or replace function incidents_list(
  p_include_closed boolean default false,
  p_limit int default 100
) returns table (
  id uuid,
  body text,
  state incident_state,
  created_at timestamptz,
  reporter_id uuid,
  reporter_name text,
  reporter_phone text,
  module_id uuid,
  module_name text,
  node_label text,
  latitude double precision,
  longitude double precision,
  handled_by_name text,
  handled_at timestamptz,
  resolution text,
  attachment_count int
)
  language sql stable security definer set search_path = public as $$
  select i.id,
         i.body,
         i.state,
         i.created_at,
         i.reporter_id,
         concat_ws(' ', rp.first_name, rp.father_name, rp.surname),
         -- The Saudi number first: this is a register read during the season,
         -- inside the Kingdom, by somebody about to telephone him.
         coalesce(rp.phone_sa, rp.phone_sy),
         i.module_id,
         mt.name_ar,
         coalesce(n.label, ri.name_ar),
         i.latitude,
         i.longitude,
         concat_ws(' ', hp.first_name, hp.father_name, hp.surname),
         i.handled_at,
         i.resolution,
         (select count(*)::int from incident_attachments a
           where a.incident_id = i.id)
    from incidents i
    join profiles rp on rp.id = i.reporter_id
    left join profiles hp on hp.id = i.handled_by
    left join modules m on m.id = i.module_id
    left join module_types mt on mt.id = m.module_type_id
    left join module_nodes n on n.id = i.node_id
    left join reference_items ri on ri.id = n.reference_item_id
   where (p_include_closed or i.state <> 'closed')
     and (
       i.reporter_id = auth.uid()
       or is_admin()
       or has_permission('incidents.receive')
     )
   order by (i.state = 'closed'), i.created_at
   limit greatest(coalesce(p_limit, 100), 1);
$$;

revoke execute on function incidents_list(boolean, int) from public, anon;
grant execute on function incidents_list(boolean, int) to authenticated;

-- ------------------------------------------------------------------- storage
--
-- The seventh bucket. Path: `{incident_id}/{i}_{file}` — the id first, so one
-- rule covers everything an incident owns, and nothing in the path identifies
-- the reporter.
--
-- No secrecy to protect here, unlike complaints: the reporter's name is on the
-- record by design. The rule is simply that a photograph of an emergency is
-- readable by whoever may read the emergency.
insert into storage.buckets (id, name, public)
values ('incidents', 'incidents', false)
on conflict (id) do nothing;

create or replace function incident_file_id(p_path text) returns uuid
  language plpgsql immutable set search_path = public as $$
declare
  v_first text := split_part(p_path, '/', 1);
begin
  -- A path that does not begin with a uuid belongs to nothing and is refused by
  -- the callers below. Caught rather than allowed to raise: a malformed name
  -- must not turn a policy check into an error.
  return v_first::uuid;
exception when others then
  return null;
end;
$$;

create or replace function can_read_incident_file(p_path text) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from incidents i
     where i.id = incident_file_id(p_path)
       and (
         i.reporter_id = auth.uid()
         or is_admin()
         or has_permission('incidents.receive')
       )
  );
$$;

-- Written only by the man who raised it, and only onto his own. An emergency
-- somebody else can add photographs to is an emergency whose evidence cannot be
-- trusted.
create or replace function can_write_incident_file(p_path text) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from incidents i
     where i.id = incident_file_id(p_path)
       and i.reporter_id = auth.uid()
  );
$$;

drop policy if exists incident_files_read on storage.objects;
create policy incident_files_read on storage.objects for select
  to authenticated using (
    bucket_id = 'incidents' and public.can_read_incident_file(name));

drop policy if exists incident_files_write on storage.objects;
create policy incident_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'incidents' and public.can_write_incident_file(name));

drop policy if exists incident_files_update on storage.objects;
create policy incident_files_update on storage.objects for update
  to authenticated
  using      (bucket_id = 'incidents' and public.can_write_incident_file(name))
  with check (bucket_id = 'incidents' and public.can_write_incident_file(name));

drop policy if exists incident_files_delete on storage.objects;
create policy incident_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'incidents'
    and (public.can_write_incident_file(name) or public.is_admin()));
