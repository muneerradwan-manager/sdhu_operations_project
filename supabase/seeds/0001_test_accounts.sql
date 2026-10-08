-- Two test accounts: one permanent employee, one external.
--
-- NOT a migration. It lives under supabase/seed/ because it writes people, not
-- structure, and nothing here should ever run against production by accident.
-- Run it by hand in the SQL editor.
--
--   firebase.projects.1997@gmail.com   موظف دائم
--   muneer.radwan.manager@gmail.com    موظف خارجي
--   password: Password!123
--
-- Three things about it are worth knowing before it runs.
--
-- 1. It gets past `profiles_guard_privileged_columns`, and has to. That trigger
--    decides who may write `is_external` and `account_status` by looking up
--    `auth.uid()` — which in the SQL editor is NULL, so the guard treats the
--    caller as a nobody and silently PINS both columns to their old values. An
--    UPDATE written the obvious way would report success and change nothing.
--    So the guard is switched off for the length of this script and back on at
--    the end.
--
-- 2. It adds both to the CURRENT season. An external employee now appears in
--    the directory only through their participation row, so without this the
--    external account would exist and be invisible.
--
-- 3. muneer.radwan.manager@gmail.com is very likely an existing account, and
--    on this database it is the administrator. Marking it external does not
--    take its admin rights away — `is_admin` is a separate column and is left
--    alone — but it does move it out of the permanent staff tab and into the
--    external one. If that is not what you meant, drop the second block.

begin;

-- Found by the FUNCTION it calls, not by name: the trigger is called
-- `profiles_guard_before_update` and the function
-- `profiles_guard_privileged_columns`, which is an easy thing to get wrong once
-- and a silent no-op if it is ever renamed.
do $$
declare
  t text;
begin
  for t in
    select tg.tgname
      from pg_trigger tg
      join pg_proc pr on pr.oid = tg.tgfoid
     where tg.tgrelid = 'public.profiles'::regclass
       and not tg.tgisinternal
       and pr.proname in (
         'profiles_guard_privileged_columns',
         'profiles_guard_email'
       )
  loop
    execute format('alter table profiles disable trigger %I', t);
  end loop;
end
$$;

-- ------------------------------------------------------------------ accounts
--
-- Created only if missing, so re-running this leaves an existing account and
-- its password alone.

do $$
declare
  v_email text;
  v_id uuid;
begin
  foreach v_email in array array[
    'firebase.projects.1997@gmail.com',
    'muneer.radwan.manager@gmail.com'
  ] loop
    if not exists (select 1 from auth.users where email = v_email) then
      v_id := gen_random_uuid();
      -- The eight token columns are set to '' and MUST be. They are nullable,
      -- so an insert that omits them succeeds and looks right — and then GoTrue
      -- reads them as plain text and cannot: every attempt to load that user
      -- answers "Database error querying schema", which is a 500 on sign-in, by
      -- password and by Google alike, and takes the whole admin user LISTING
      -- down with it, because one unreadable row breaks the scan for everyone.
      -- An earlier version of this script left them out and did exactly that.
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data,
        confirmation_token, recovery_token, email_change,
        email_change_token_new, email_change_token_current,
        phone_change, phone_change_token, reauthentication_token
      ) values (
        '00000000-0000-0000-0000-000000000000',
        v_id, 'authenticated', 'authenticated', v_email,
        extensions.crypt('Password!123', extensions.gen_salt('bf')),
        now(), now(), now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{}'::jsonb,
        '', '', '', '', '', '', '', ''
      );
      -- The account needs an identity row or password sign-in refuses it.
      insert into auth.identities (
        id, user_id, provider_id, provider, identity_data,
        last_sign_in_at, created_at, updated_at
      ) values (
        gen_random_uuid(), v_id, v_id::text, 'email',
        jsonb_build_object('sub', v_id::text, 'email', v_email,
                           'email_verified', true, 'phone_verified', false),
        now(), now(), now()
      );
    end if;
  end loop;
end
$$;

-- Repairs an account an earlier version of this script created before it knew
-- about the columns above. Harmless on a healthy row — coalesce leaves a value
-- that is already there — and it is the difference between an account that can
-- sign in and one that answers 500 to every attempt.
update auth.users set
  confirmation_token         = coalesce(confirmation_token, ''),
  recovery_token             = coalesce(recovery_token, ''),
  email_change               = coalesce(email_change, ''),
  email_change_token_new     = coalesce(email_change_token_new, ''),
  email_change_token_current = coalesce(email_change_token_current, ''),
  phone_change               = coalesce(phone_change, ''),
  phone_change_token         = coalesce(phone_change_token, ''),
  reauthentication_token     = coalesce(reauthentication_token, '')
where email in (
  'firebase.projects.1997@gmail.com',
  'muneer.radwan.manager@gmail.com'
);

-- ------------------------------------------------------------------ profiles
--
-- `on_auth_user_created` already made a row for each; this fills it in and
-- approves it. Approved and complete, because an account that has to be walked
-- through registration is no use as a test account.

update profiles p
   set first_name  = 'أحمد',
       father_name = 'سامي',
       surname     = 'الدائم',
       gender      = 'male',
       date_of_birth = date '1990-03-12',
       mission_type_id = (
         select ri.id from reference_items ri
           join reference_sets rs on rs.id = ri.set_id
          where rs.code = 'mission_types' and ri.is_active
          order by ri.sort_order limit 1
       ),
       phone_sy      = '0999000111',
       job_title_id  = (
         select ri.id from reference_items ri
           join reference_sets rs on rs.id = ri.set_id
          where rs.code = 'job_titles' and ri.is_active
          order by ri.name_ar limit 1
       ),
       account_status = 'approved',
       is_suspended  = false,
       is_external   = false,
       external_organization = null
  from auth.users u
 where u.id = p.id
   and u.email = 'firebase.projects.1997@gmail.com';

update profiles p
   set first_name  = 'منير',
       father_name = 'عبدالله',
       surname     = 'رضوان',
       gender      = 'male',
       date_of_birth = coalesce(p.date_of_birth, date '1988-06-05'),
       mission_type_id = coalesce(
         p.mission_type_id,
         (select ri.id from reference_items ri
            join reference_sets rs on rs.id = ri.set_id
           where rs.code = 'mission_types' and ri.is_active
           order by ri.sort_order limit 1)
       ),
       phone_sy      = coalesce(p.phone_sy, '0999000222'),
       job_title_id  = coalesce(
         p.job_title_id,
         (select ri.id from reference_items ri
            join reference_sets rs on rs.id = ri.set_id
           where rs.code = 'job_titles' and ri.is_active
           order by ri.name_ar limit 1)
       ),
       account_status = 'approved',
       is_suspended  = false,
       is_external   = true,
       external_organization = 'وزارة الخارجية'
  from auth.users u
 where u.id = p.id
   and u.email = 'muneer.radwan.manager@gmail.com';

-- -------------------------------------------------------------- participation
--
-- Without this the external account is invisible: the directory reads the
-- externals of a season through `season_participants`, not through `profiles`.

insert into season_participants (season_id, profile_id, status)
select s.id, p.id, 'active'
  from seasons s
  cross join profiles p
  join auth.users u on u.id = p.id
 where s.is_current
   and u.email in (
     'firebase.projects.1997@gmail.com',
     'muneer.radwan.manager@gmail.com'
   )
on conflict (season_id, profile_id) do update set status = 'active';

do $$
declare
  t text;
begin
  for t in
    select tg.tgname
      from pg_trigger tg
      join pg_proc pr on pr.oid = tg.tgfoid
     where tg.tgrelid = 'public.profiles'::regclass
       and not tg.tgisinternal
       and pr.proname in (
         'profiles_guard_privileged_columns',
         'profiles_guard_email'
       )
  loop
    execute format('alter table profiles enable trigger %I', t);
  end loop;
end
$$;

commit;

-- What landed.
select u.email, p.first_name, p.surname, p.account_status, p.is_external,
       p.is_admin, p.external_organization,
       exists (
         select 1 from season_participants sp
         join seasons s on s.id = sp.season_id
         where sp.profile_id = p.id and s.is_current and sp.status = 'active'
       ) as in_current_season
  from profiles p
  join auth.users u on u.id = p.id
 where u.email in (
   'firebase.projects.1997@gmail.com',
   'muneer.radwan.manager@gmail.com'
 );
