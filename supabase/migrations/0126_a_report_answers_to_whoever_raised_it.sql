-- بلاغاتي: a door open to everyone, onto exactly what they filed.
--
-- `incidents_list` has answered one question since 0088: "what is on the
-- register", and `p_include_closed` / `p_limit` are both about reading that
-- register well. Whoever calls it without `incidents.receive` already gets
-- only their own reports back — the WHERE clause has always fallen back to
-- `reporter_id = auth.uid()` — but that is an ACCIDENT of the predicate's
-- shape, not a promise. Ask the same function while holding `incidents.receive`
-- (or being admin) and it answers with the WHOLE register, open cases from
-- everyone included. That is exactly right for the operations room's screen
-- and exactly wrong for a supervisor who raised one report last Tuesday and
-- wants to know what happened to it: he would get back a busy season's worth
-- of everyone else's emergencies with his own possibly pushed off the end of
-- `p_limit` by open reports that are not his.
--
-- So a third question, asked explicitly rather than inferred from who is
-- calling: p_mine_only. True means the register the caller receives is not
-- narrowed by permission at all — it is EVERY report this account raised, full
-- stop, the same list an ordinary member sees and an admin does not usually
-- get to see filtered down to. False is the register exactly as before.
--
-- Dropped and recreated rather than `create or replace`: a new parameter is a
-- new signature to Postgres, and the old two-argument form left standing
-- beside it would make every existing call ambiguous. See 0120 §"the
-- register" for the same argument made the first time this function grew.
drop function if exists incidents_list(boolean, int);

create or replace function incidents_list(
  p_include_closed boolean default false,
  p_limit int default 100,
  p_mine_only boolean default false
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
         coalesce(rp.phone_sa, rp.phone_sy),
         i.module_id,
         mt.name_ar,
         coalesce(n.label, ri.name_ar),
         i.subject_profile_id,
         concat_ws(' ', sp.first_name, sp.father_name, sp.surname),
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
       case
         when p_mine_only then i.reporter_id = auth.uid()
         else (
           i.reporter_id = auth.uid()
           or is_admin()
           or has_permission('incidents.receive')
         )
       end
     )
   order by (i.state = 'closed'), i.created_at
   limit greatest(coalesce(p_limit, 100), 1);
$$;

revoke execute on function incidents_list(boolean, int, boolean) from public, anon;
grant execute on function incidents_list(boolean, int, boolean) to authenticated;
