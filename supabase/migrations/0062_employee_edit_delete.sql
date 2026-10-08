-- Correcting and removing an employee record.
--
-- 0061 gave the two actions their permission codes. This is what makes them do
-- anything: until now `profiles` could be updated by its owner and by an admin
-- and by nobody else, so `employees.edit` was a switch wired to nothing.
--
-- Deleting is not here, and deliberately. A profile row is not the account —
-- `profiles.id` references `auth.users` — so removing the row would leave a
-- login behind with nothing attached to it, and RLS cannot delete from the auth
-- schema anyway. Deletion goes through the `admin-delete-user` Edge Function,
-- which holds the service role, checks `employees.delete` itself, and removes
-- the auth user so the cascade takes the profile with it.

-- ------------------------------------------------------------------- editing

-- The guard trigger (0011) still stands between an editor and the columns that
-- decide what someone IS: is_admin, is_external, account_status and the rest are
-- reverted for any caller who is not an admin. So this widens who may correct a
-- record without widening what may be corrected — a name, a phone, a job title,
-- a date of birth. Which is exactly the list that comes off a paper decision
-- wrong, and exactly the list an editor is being trusted with.
drop policy if exists profiles_update_self on profiles;
create policy profiles_update_self on profiles for update
  using (
    id = auth.uid()
    or is_admin()
    or has_permission('employees.edit')
  )
  with check (
    id = auth.uid()
    or is_admin()
    or has_permission('employees.edit')
  );

-- An editor must also be able to READ the person they are correcting, whatever
-- else they hold. `employees.view` is the ordinary way in, and an account with
-- edit but not view could otherwise open nothing to edit.
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select
  using (
    id = auth.uid()
    or is_admin()
    or has_permission('employees.view')
    or has_permission('employees.edit')
    or shares_a_module_with(id)
  );
