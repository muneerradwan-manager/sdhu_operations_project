-- Resetting an employee's password.
--
-- A password is not a column on `profiles` — it lives in the auth schema, which
-- RLS cannot reach and which only the service role may write. So there is no
-- policy to widen here: the whole of this action happens inside the
-- `admin-set-password` Edge Function, and all this migration does is give the
-- function a permission to check.
--
-- Its own code rather than `employees.edit`, and for the same reason delete got
-- one: correcting a misspelled surname and taking over somebody's login are not
-- the same trust. Whoever enters the roster from paper needs the first and has
-- no business with the second. The function additionally refuses to reset an
-- ADMINISTRATOR's password for anyone who is not one — otherwise the grant is a
-- route to the account that issued it.

insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('employees.password', 'Reset an employee''s password', 8)
) as v(code, description, sort_order)
join permissions p on p.code = 'employees'
on conflict (code) do nothing;
