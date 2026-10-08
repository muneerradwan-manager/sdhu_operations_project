-- One-off: every existing account signs in with Password!123 from now on.
--
-- Run it in the Supabase SQL editor (or psql). Operational choice, 2026-08:
-- the administration hands accounts out in person, and one known password is
-- easier to hand out than many unknown ones. Everyone can change theirs later —
-- themselves from the profile screen, or the administration via the password
-- sheet (employees.password).
--
-- bcrypt with a fresh salt per row, same as GoTrue writes on a normal reset.
-- Sessions already signed in stay signed in; only the next sign-in changes.
update auth.users
   set encrypted_password = extensions.crypt('Password!123', extensions.gen_salt('bf')),
       updated_at = now();

-- To leave the administrators' passwords alone instead, use this WHERE:
-- where id not in (select id from public.profiles where is_admin);
