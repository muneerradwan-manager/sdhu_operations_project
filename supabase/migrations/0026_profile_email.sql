-- The email address, where the app can actually reach it.
--
-- Every profile has had one all along — it is what the account signs in with —
-- but it lives in `auth.users`, which the client cannot read for anybody but
-- itself. So an employee's card showed a phone and no email, and there was no
-- query that could have shown one.
--
-- Mirrored onto `profiles` instead: it is a contact detail like the two phone
-- numbers beside it, and it belongs where the rest of the contact details are.
-- `auth.users` stays the owner of the value; nothing here ever writes back to
-- it, and no one but the triggers below writes the mirror.

alter table profiles
  add column if not exists email text;

update profiles p
   set email = u.email
  from auth.users u
 where u.id = p.id
   and p.email is distinct from u.email;

-- 1. New signups. 0003 created the profile row without one.
create or replace function handle_new_user() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, account_status)
  values (new.id, new.email, 'incomplete')
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

-- 2. Address changes. Rare, but a mirror that silently goes stale is worse
--    than no mirror: someone would write to an address nobody reads.
--
--    The flag is how the write below gets past the guard in step 3. Set
--    transaction-local (the `true`), so it cannot leak into another statement
--    and let an unrelated update through.
create or replace function sync_profile_email() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if new.email is distinct from old.email then
    perform set_config('app.email_sync', 'on', true);
    update public.profiles set email = new.email where id = new.id;
    perform set_config('app.email_sync', 'off', true);
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_changed on auth.users;
create trigger on_auth_user_email_changed after update of email on auth.users
  for each row execute function sync_profile_email();

-- 3. The column is a mirror, so nobody edits it through `profiles` — not even
--    an admin. A write here would be reverted by the next auth-side change, and
--    would meanwhile show an address that cannot sign in as though it could.
--    RLS is row-level and cannot protect one column, so this is the boundary.
create or replace function profiles_guard_email() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('app.email_sync', true), 'off') <> 'on' then
    new.email := old.email;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_guard_email_before_update on profiles;
create trigger profiles_guard_email_before_update before update on profiles
  for each row execute function profiles_guard_email();
