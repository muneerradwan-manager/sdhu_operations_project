-- ============================================================
-- Bootstrap the first administrator.
--
-- Chicken-and-egg: is_admin can only be granted by an admin, but none exists
-- yet. Run this ONCE, manually, in the Supabase SQL Editor.
--
-- Steps:
--   1. Make sure migration 0011_fix_admin_guard.sql has been applied. Without it
--      the privileged-columns guard treats the SQL editor (auth.uid() = null) as
--      a non-admin and silently reverts the changes below.
--   2. Have the admin sign up in the app (email + password), OR create the user
--      from Authentication > Users in the dashboard, using the email below.
--      If email confirmation is enabled, confirm the address first.
--   3. Then run this script. It promotes that account to an approved admin.
-- ============================================================

update public.profiles p
set is_admin = true,
    account_status = 'approved'
from auth.users u
where u.id = p.id
  and u.email = 'muneer.radwan.manager@gmail.com';

-- Verify:
-- select p.id, u.email, p.is_admin, p.account_status
-- from public.profiles p join auth.users u on u.id = p.id
-- where u.email = 'muneer.radwan.manager@gmail.com';
