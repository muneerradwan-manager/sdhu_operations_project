-- A colleague in the file still has a name.
--
-- Opening an operational file as somebody merely POSTED to it returned the
-- nodes, the levels, the roles — and every member came back as:
--
--   {"profile_id": "02d809ff-…", "role_id": "78699768-…", "profiles": null}
--
-- Null, on every row, for a man looking at the برج he himself supervises. The
-- screen has the assignment and no person to hang on it.
--
-- ------------------------------------------------------------- what happened
--
-- `profiles_select` has carried a colleague clause since 0017, and 0024 widened
-- it to reach through the node tree when files stopped being flat lists:
--
--   or shares_a_module_with(id)
--
-- 0062 restated the policy and kept it. 0073 restated it again and kept it,
-- alongside the approvals-queue clause it had just written. Then 0100 restated
-- it a third time to add `export.data` — and restated it from the two lines it
-- was thinking about rather than from the policy that was actually installed.
-- Three clauses went out with the rewrite, none of them mentioned anywhere in
-- that migration:
--
--   1. has_permission('employees.edit')      — 0062: an editor with edit but
--      not view could open nothing to edit.
--   2. approvals.view over pending/incomplete/rejected — 0073: the approvals
--      queue is visible to whoever decides on it, and only the accounts that
--      ARE requests; the approved directory stays behind employees.view.
--   3. shares_a_module_with(id)              — 0017/0024: the everyday one.
--
-- Nothing about the export grant required dropping any of them. A `drop policy`
-- followed by a `create policy` typed from memory is the one edit in this
-- schema that loses rules silently: there is no error, no failing write, and
-- the loss only shows up as an absence on a screen weeks later.
--
-- ---------------------------------------------- the distinction being restored
--
-- The Administration's rule has two halves and they are not the same grant:
--
--   `employees.view`      — open the الموظفون directory: EVERY employee in the
--                           mission, searchable, whether or not you work with
--                           any of them. A senior read, granted deliberately.
--
--   posted to a file      — see the people IN THAT FILE. Not a permission at
--                           all; it follows from the posting. A tower
--                           supervisor phoning his sector supervisor is the
--                           everyday use of this app, and he holds no grant.
--
-- `shares_a_module_with` is exactly that second half and no wider: it opens a
-- profile to me only where a module_id of mine meets a module_id of his,
-- through module_members or through module_node_members. Someone posted to one
-- برج reaches the people of that file. He does not reach the directory.
--
-- Restated whole below, so the next rewrite reads six clauses instead of two.

drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select
  using (
    id = auth.uid()
    or is_admin()
    -- the directory
    or has_permission('employees.view')
    -- 0062: an editor must be able to read whom he is correcting
    or has_permission('employees.edit')
    -- 0100: the export is a senior read, and takes the roster with it
    or has_permission('export.data')
    -- 0073: the queue, and only the accounts that are requests
    or (has_permission('approvals.view')
        and account_status in ('pending', 'incomplete', 'rejected'))
    -- 0017/0024: the colleagues of a file I am posted to
    or shares_a_module_with(id)
  );

-- ================================================================ the report
--
-- What a member sees of the file he serves in. Run as any posted account: the
-- names come back, and `profiles` is no longer null.

select p.policyname,
       p.qual
  from pg_policies p
 where p.schemaname = 'public'
   and p.tablename  = 'profiles'
   and p.policyname = 'profiles_select';
