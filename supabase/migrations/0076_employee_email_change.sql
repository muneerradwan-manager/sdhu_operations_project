-- Changing an employee's email address.
--
-- Like the password (0072), the address an account signs in with lives in the
-- auth schema, which RLS cannot reach and which only the service role may
-- write. So there is no policy to widen here: the whole of this action happens
-- inside the `admin-set-email` Edge Function, and all this migration does is
-- give the function a permission to check.
--
-- Its own code rather than `employees.edit`, for the same reason the password
-- got one: the email IS the login. Whoever corrects a misspelled surname has no
-- business renaming the credential a person signs in with. The function
-- additionally refuses an ADMINISTRATOR's account to anyone who is not one —
-- point the address at a mailbox you own and the account is yours.
--
-- Uniqueness needs nothing from us: `auth.users` already refuses an address
-- that is signed in elsewhere. And the `profiles.email` mirror (0026) follows
-- by itself — the auth-side write fires `on_auth_user_email_changed`, which is
-- the one door through the mirror's guard.

insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('employees.email', 'Change an employee''s email address', 9)
) as v(code, description, sort_order)
join permissions p on p.code = 'employees'
on conflict (code) do nothing;

-- Changing where an account signs in presumes seeing the account.
insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from permissions c
join permissions r on r.code = 'employees.view'
where c.code = 'employees.email'
on conflict do nothing;
