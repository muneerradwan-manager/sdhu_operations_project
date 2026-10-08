-- A complaint could name nobody.
--
-- Filing one takes no permission, and that is deliberate: 0079 grants it to
-- every approved account, and `permission_codes.dart` says why — a record of
-- what went wrong that only some people may write is not a record of what went
-- wrong. But the form that files it has to offer something to point at, and
-- the picker read the four tables directly:
--
--     profiles          employees.view, or someone you share a file with
--     modules           modules.view_all / .members, or a file you are in
--     reports           published only
--     reference_items   any approved account          ← the only one that worked
--
-- So an ordinary employee opened the form, chose "an employee", and was handed
-- an empty list. He may complain about anyone and could name no one.
--
-- The tempting fix is to make `employees.view` a prerequisite of filing. It is
-- the wrong one twice over. There is no permission to file — nothing to hang a
-- prerequisite on — and `employees.view` is not a list of names: it is the
-- directory, with the phones and the documents and the pages behind it. Handing
-- it to everyone who wants to complain would empty the permission out through a
-- side door, and `modules.view_all` (which includes drafts) with it.
--
-- What the form needs is narrower than any of those permissions: an id and a
-- name. So it gets its own function, SECURITY DEFINER, for the same reason
-- `assignable_employees` is (0029) — the row security that hides these tables
-- is right, and the answer to a question it cannot express is a function that
-- returns less, not a policy that shows more. Three columns leave here. Not a
-- phone, not a document, not an account's standing.

-- ============================================================ who may file one
--
-- The predicate the insert policy already applied, given a name so that the
-- picker and the policy cannot come to disagree about who may file — an offer
-- to complain, followed by a refusal to accept it, is worse than neither.
--
-- Worth knowing where it stands: `is_approved()` is false for an account this
-- very feature auto-suspended. Answering the complaints against you is allowed
-- on purpose (0079 §the reply guard), filing a new one is not. Whether the
-- third man complained about should be able to complain back is a decision, and
-- it is now a decision made in one line rather than in two places.
create or replace function can_file_complaint() returns boolean
  language sql stable security definer set search_path = public as $$
  select is_approved();
$$;

drop policy if exists complaints_insert on complaints;
create policy complaints_insert on complaints for insert
  with check (complainant_id = auth.uid() and can_file_complaint());

-- ====================================================== what may be pointed at
--
-- One function for all seven kinds, because the picker asks one question and
-- the answer differs only in which table it is read from. What each kind
-- returns, and why it is that and not everything:
--
--   employee   every approved account but your own. The whole point: you cannot
--              complain about someone you cannot name.
--   module     released files only. A draft is visible to its managers alone,
--              and nobody complains about a file that was never handed out.
--   report     published, plus your own drafts — the two you could have read.
--   hotel /    the set's active items, which any approved account could already
--   cluster /  read; here for one shape rather than two code paths.
--   group
--   other      nothing, and needs nothing. It is the escape hatch for a
--              complaint that is about none of the above.
--
-- Names come from audit_record_label so that the name offered in the picker is
-- the name stored on the complaint (0081 made the same argument). Two naming
-- functions would be two answers to "what is this row called", and they drift.
create or replace function complaint_targets(
  p_target_type text,
  p_query text default null,
  p_limit int default 100
)
returns table (id uuid, name text, photo_url text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_type complaint_target_type := p_target_type::complaint_target_type;
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 200);
begin
  if not can_file_complaint() then
    return;
  end if;

  case v_type
    when 'employee' then
      return query
      select p.id,
             nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
             p.photo_url
        from profiles p
       where p.account_status = 'approved'
         and p.id <> auth.uid()
         and (v_query is null
              or concat_ws(' ', p.first_name, p.father_name, p.surname)
                   ilike '%' || v_query || '%')
       order by 2
       limit v_limit;

    when 'module' then
      return query
      select m.id, audit_record_label('modules', to_jsonb(m)), null::text
        from modules m
       where m.is_active
         and (v_query is null
              or audit_record_label('modules', to_jsonb(m))
                   ilike '%' || v_query || '%')
       order by m.created_at desc
       limit v_limit;

    when 'report' then
      return query
      select r.id, r.title, null::text
        from reports r
       where (r.is_published or r.created_by = auth.uid())
         and (v_query is null or coalesce(r.title, '') ilike '%' || v_query || '%')
       order by r.updated_at desc
       limit v_limit;

    when 'other' then
      return;

    else
      -- hotel, cluster, group. The set's code is the enum value's own name in
      -- the plural — the mismatch 0081 was written to fix.
      return query
      select ri.id, ri.name_ar, null::text
        from reference_items ri
        join reference_sets rs on rs.id = ri.set_id
       where rs.code = v_type::text || 's'
         and ri.is_active
         and (v_query is null or ri.name_ar ilike '%' || v_query || '%')
       order by ri.sort_order
       limit v_limit;
  end case;
end;
$$;

revoke execute on function can_file_complaint() from public, anon;
grant  execute on function can_file_complaint() to authenticated;
revoke execute on function complaint_targets(text, text, int) from public, anon;
grant  execute on function complaint_targets(text, text, int) to authenticated;
