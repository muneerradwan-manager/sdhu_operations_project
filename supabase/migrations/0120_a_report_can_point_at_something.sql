-- A report can point at something.
--
-- 0088 gave the urgent report one line of text and nothing else, on the rule
-- that every field added is a second added between deciding to report and the
-- report arriving. That rule still holds and nothing below breaks it:
-- everything here is optional, nothing is asked for, and a man who types a line
-- and presses send sends exactly what he sent before.
--
-- What it buys is the question the operations room asks the moment a report
-- lands: about WHAT? Until now the only answer the record could carry was the
-- file he happened to be standing in when he pressed the button — attached
-- silently, and null whenever he pressed it from anywhere else, which is most
-- of the time. Three answers are worth having and the schema could hold one:
--
--   * A FILE — already here, and unchanged.
--   * A PERSON. "The driver of coach 4 has not turned up." The room needs to
--     know who, and needs it as an id rather than as a name inside the prose,
--     because a name in prose cannot be telephoned from the register.
--   * A PLACE IN THE APP. "The roster screen is showing yesterday's list." This
--     is the report about the TOOL rather than about the mission, and it had
--     nowhere to go at all — it was being typed into the body and read by
--     whoever happened to understand it was not an emergency.
--
-- All three remain null on most reports, and that is the expected shape. The
-- worst moments are not tidy; a man who is not inside a file, not talking about
-- a particular person and not looking at a screen still has an emergency worth
-- hearing, and the send button has never cared.

alter table incidents
  -- Who it is about, which is NOT who filed it. `reporter_id` is the man to
  -- telephone back; this is the man being reported on, and the two are
  -- different people by construction — a report naming yourself is a report,
  -- not a subject.
  add column if not exists subject_profile_id uuid
    references profiles (id) on delete set null,

  -- Where in the app, when the report is about the app.
  --
  -- Stored as a route AND as the words the reporter saw on it, which looks like
  -- redundancy and is not. The route is what makes it a LINK — the register can
  -- open the screen being complained about. The label is what makes it
  -- READABLE, here and in the notification, by a database that does not own the
  -- app's menu and cannot turn `/employees` into "الموظفون" in two languages.
  --
  -- The label is also a snapshot, in exactly the way `body` is: it records what
  -- that screen was called on the day somebody reported it, which is what a
  -- register is for. A rename six months later must not rewrite the report.
  add column if not exists app_route text,
  add column if not exists app_label text;

-- Every report filed against one person, newest first — the question the
-- register cannot answer without it, and the one worth asking twice: three
-- urgent reports about the same man in five days is a fact about the man.
create index if not exists idx_incidents_subject
  on incidents (subject_profile_id, created_at desc)
  where subject_profile_id is not null;

-- ----------------------------------------------------------------- who reads
--
-- Deliberately UNCHANGED, and this is the decision worth stating rather than
-- the ones above.
--
-- The subject of a report does not gain the right to read it. `incidents_select`
-- still admits the reporter and the operations room and nobody else, so a man
-- named in an urgent report cannot look it up, cannot see who named him and
-- cannot see how long it sat open. That is not the complaints register's
-- structural secrecy (0079) arriving here by the back door — the reporter's own
-- name is still on the record, still shown first, still telephoned back within
-- the minute. It is only that being written ABOUT is not a claim on the record.

-- ------------------------------------------------------------------- raising
--
-- Dropped and recreated rather than replaced: two more defaulted parameters is
-- a NEW overload as far as Postgres is concerned, and the old six-argument form
-- left standing beside it makes every existing call ambiguous.
drop function if exists raise_incident(
  text, uuid, uuid, double precision, double precision, double precision
);

create or replace function raise_incident(
  p_body text,
  p_module_id uuid default null,
  p_node_id uuid default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_accuracy double precision default null,
  p_subject_profile_id uuid default null,
  p_app_route text default null,
  p_app_label text default null
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_name text;
  v_where text;
  v_subject text;
begin
  if not is_approved() then
    raise exception 'not authorized';
  end if;
  if btrim(coalesce(p_body, '')) = '' then
    raise exception 'incident_body_required';
  end if;

  insert into incidents (
    reporter_id, module_id, node_id, body, latitude, longitude, accuracy_m,
    subject_profile_id, app_route, app_label
  )
  values (
    auth.uid(), p_module_id, p_node_id, btrim(p_body), p_lat, p_lng, p_accuracy,
    -- Reporting yourself is not a subject, it is a report. Dropped rather than
    -- refused: a man in a hurry who taps his own name has still sent a valid
    -- emergency, and rejecting it over the tidiness of one optional column
    -- would be the worst trade in this whole feature.
    nullif(p_subject_profile_id, auth.uid()),
    nullif(btrim(coalesce(p_app_route, '')), ''),
    nullif(btrim(coalesce(p_app_label, '')), '')
  )
  returning id into v_id;

  select concat_ws(' ', p.first_name, p.father_name, p.surname)
    into v_name
    from profiles p where p.id = auth.uid();

  select concat_ws(' ', p.first_name, p.father_name, p.surname)
    into v_subject
    from profiles p where p.id = p_subject_profile_id;

  -- The place, if the app could say where he was. Put in the BODY of the
  -- notification rather than only in the payload: whoever is woken by this
  -- reads a line of text on a lock screen, and "بلاغ عاجل" alone tells him
  -- nothing he can act on.
  --
  -- Most specific first, and the order is the order of urgency rather than of
  -- precision: a tower, else the file, else the man it is about, else the
  -- screen. A report naming a person outranks one naming a screen, because one
  -- of the two is somebody who may not have turned up.
  select coalesce(n.label, ri.name_ar, mt.name_ar)
    into v_where
    from modules m
    left join module_types mt on mt.id = m.module_type_id
    left join module_nodes n on n.id = p_node_id
    left join reference_items ri on ri.id = n.reference_item_id
   where m.id = p_module_id;

  v_where := coalesce(
    nullif(coalesce(v_where, ''), ''),
    nullif(coalesce(v_subject, ''), ''),
    nullif(btrim(coalesce(p_app_label, '')), '')
  );

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
  text, uuid, uuid, double precision, double precision, double precision,
  uuid, text, text
) from public, anon;
grant execute on function raise_incident(
  text, uuid, uuid, double precision, double precision, double precision,
  uuid, text, text
) to authenticated;

-- --------------------------------------------------------------- the register
--
-- Dropped and recreated for the same reason as above and a stronger one: the
-- return type is part of the signature, and `create or replace` cannot change
-- it at all.
--
-- Ordering is untouched. Open ones first, then by AGE — an emergency that has
-- been sitting for forty minutes matters more than one raised a moment ago, and
-- putting the new one on top is how the old one is never looked at again.
drop function if exists incidents_list(boolean, int);

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
  subject_id uuid,
  subject_name text,
  subject_phone text,
  app_route text,
  app_label text,
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
         i.subject_profile_id,
         concat_ws(' ', sp.first_name, sp.father_name, sp.surname),
         -- The subject's number, on the same reasoning as the reporter's and
         -- for a different call: the room telephones the reporter to ask what
         -- happened, and the subject to find out where he is.
         coalesce(sp.phone_sa, sp.phone_sy),
         i.app_route,
         i.app_label,
         i.latitude,
         i.longitude,
         concat_ws(' ', hp.first_name, hp.father_name, hp.surname),
         i.handled_at,
         i.resolution,
         (select count(*)::int from incident_attachments a
           where a.incident_id = i.id)
    from incidents i
    join profiles rp on rp.id = i.reporter_id
    left join profiles sp on sp.id = i.subject_profile_id
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
