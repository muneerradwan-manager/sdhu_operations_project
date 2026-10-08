-- Striking an urgent report off the register — and making the room LOOK UP.
--
-- Two things, and they belong in one migration because they are the two ends of
-- the same complaint about 0088: the register fills with reports nobody can ever
-- remove, and an emergency arrives as a line in a tray that a man holding a
-- phone in his pocket never sees.
--
-- ============================================================ 1. the deleting
--
-- 0088 gave incidents an insert policy, a select policy and an update policy,
-- and no delete policy at all — which in a table with RLS enabled means NOBODY
-- may delete one, not even an administrator. That was defensible while the
-- register was young. It stops being defensible in the second week of a season,
-- when the list an operations room reads at 3am is nine tenths test messages,
-- duplicates from a man who pressed send four times on a bad network, and
-- emergencies closed six days ago.
--
-- A register that cannot be emptied is a register that stops being read, and a
-- register that stops being read is the failure this feature exists to prevent.
--
-- Its own code rather than folding it into `incidents.handle`. Closing a report
-- says "somebody went"; deleting it says "this never happened", and the second
-- is not the first with more confidence. Whoever answers the emergencies is not
-- automatically the person who may erase the evidence that they were raised.
--
-- And because this is the one action in the register that destroys rather than
-- records, the audit trigger 0088 forgot goes on in the same breath. See §3.

insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('incidents.delete', 'Delete urgent reports from the register', 3)
) as v(code, description, sort_order)
join permissions p on p.code = 'incidents'
on conflict (code) do nothing;

-- Erasing one requires being able to see them, the same ground `incidents.handle`
-- stands on. The trigger from 0073 enforces it; stated here so the permissions
-- editor can explain itself to whoever is granting it.
insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from permissions c, permissions r
where c.code = 'incidents.delete' and r.code = 'incidents.receive'
on conflict do nothing;

-- The policy the table never had. Deliberately NOT extended to the reporter:
-- a man who raises an emergency and then thinks better of it must not be able
-- to take it back out of the room's list — the room has already been woken, and
-- "it turned out to be nothing" is something they close, not something he
-- deletes.
drop policy if exists incidents_delete on incidents;
create policy incidents_delete on incidents for delete
  using (is_admin() or has_permission('incidents.delete'));

-- ===================================================== 2. the photographs too
--
-- `incident_attachments` cascades on the row. The OBJECTS in storage do not:
-- nothing in Postgres owns them, and a delete that leaves them behind is a
-- private bucket quietly accumulating photographs of emergencies that no longer
-- exist, readable by nobody and paid for forever.
--
-- So the two functions below RETURN the paths they orphaned, and the app removes
-- them from the bucket afterwards. Best-effort by design: the row going is what
-- matters, and a storage call that fails must not roll back the deletion.
drop policy if exists incident_files_delete on storage.objects;
create policy incident_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'incidents'
    and (
      public.can_write_incident_file(name)
      or public.is_admin()
      or public.has_permission('incidents.delete')
    ));

-- ============================================================= 3. the logging
--
-- 0077 attached its generic trigger to every table that existed WHEN IT RAN,
-- and left a note for future migrations to do the same for theirs. 0088 did not
-- read the note: `incidents` and `incident_attachments` have been unaudited
-- since the day they were created — every state change, and now every deletion,
-- leaving no trace of who did it.
--
-- That was a gap while the register only ever grew. With a delete policy above
-- it, it is the exact hole the log exists to close: "who removed the report
-- about the bus" must have an answer.
drop trigger if exists audit_row on incidents;
create trigger audit_row after insert or update or delete on incidents
  for each row execute function audit_row_change();

drop trigger if exists audit_row on incident_attachments;
create trigger audit_row after insert or update or delete on incident_attachments
  for each row execute function audit_row_change();

-- An incident row carries none of the six columns `audit_record_label` falls
-- back on — no name, no title, no label — so every line it wrote would have read
-- as a bare uuid. The body is what identifies it to a human being.
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
    -- New in 0121. What the report said, cut to a line — the register's rows
    -- are free text and nothing else on them names the thing.
    when 'incidents' then
      nullif(left(btrim(coalesce(p_row ->> 'body', '')), 80), '')
    else null
  end;

  return coalesce(v,
    p_row ->> 'name_ar', p_row ->> 'title', p_row ->> 'name',
    p_row ->> 'label', p_row ->> 'code', p_row ->> 'email');
exception when others then
  return null;
end;
$$;

-- ============================================================ 4. striking one
--
-- Returns the storage paths that are now orphaned, for the caller to remove
-- from the bucket. An empty array is the normal case: most reports carry no
-- photograph.
create or replace function delete_incident(p_incident_id uuid)
  returns text[]
  language plpgsql security definer set search_path = public as $$
declare
  v_paths text[];
begin
  if not (is_admin() or has_permission('incidents.delete')) then
    raise exception 'not authorized';
  end if;

  -- Read BEFORE the delete: the cascade takes the attachment rows with the
  -- incident, and after that there is nothing left to ask where the files were.
  select coalesce(array_agg(a.path), '{}')
    into v_paths
    from incident_attachments a
   where a.incident_id = p_incident_id;

  delete from incidents where id = p_incident_id;

  if not found then
    raise exception 'incident_not_found';
  end if;

  return v_paths;
end;
$$;

revoke execute on function delete_incident(uuid) from public, anon;
grant execute on function delete_incident(uuid) to authenticated;

-- ========================================================== 5. clearing it out
--
-- The whole register in one act, which is what the end of a season actually
-- needs — six hundred rows removed one confirmation at a time is a job nobody
-- does, so the list is carried into the next season instead.
--
-- [p_only_closed] is the safety, and it defaults to the safe answer. Clearing
-- the finished ones is housekeeping; clearing everything takes an open
-- emergency off the screen of every other person watching the register, and the
-- caller has to say so deliberately.
create or replace function delete_all_incidents(p_only_closed boolean default true)
  returns table (deleted int, paths text[])
  language plpgsql security definer set search_path = public as $$
declare
  v_ids uuid[];
  v_paths text[];
  v_count int;
begin
  if not (is_admin() or has_permission('incidents.delete')) then
    raise exception 'not authorized';
  end if;

  select coalesce(array_agg(i.id), '{}')
    into v_ids
    from incidents i
   where not coalesce(p_only_closed, true) or i.state = 'closed';

  select coalesce(array_agg(a.path), '{}')
    into v_paths
    from incident_attachments a
   where a.incident_id = any (v_ids);

  delete from incidents where id = any (v_ids);
  get diagnostics v_count = row_count;

  return query select v_count, v_paths;
end;
$$;

revoke execute on function delete_all_incidents(boolean) from public, anon;
grant execute on function delete_all_incidents(boolean) to authenticated;
