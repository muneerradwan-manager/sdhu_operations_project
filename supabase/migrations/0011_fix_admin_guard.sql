-- Fix: the privileged-columns guard must not fire for backend callers
-- (service_role / postgres / the SQL editor), where auth.uid() is null.
-- Otherwise the first-admin bootstrap is impossible: the trigger silently
-- reverts is_admin / account_status because it treats a null uid as "not admin".
--
-- RLS already prevents anon/unauthenticated clients from updating profiles at
-- all, so a null uid reaching this trigger means a trusted backend context.

create or replace function profiles_guard_privileged_columns() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  caller_is_admin boolean;
begin
  -- Backend / service-role / SQL editor: not a client update, allow as-is.
  if auth.uid() is null then
    return new;
  end if;

  select p.is_admin and p.account_status = 'approved'
    into caller_is_admin
  from public.profiles p
  where p.id = auth.uid();

  caller_is_admin := coalesce(caller_is_admin, false);

  if caller_is_admin then
    return new;
  end if;

  -- Privileged columns can never be changed by a non-admin end user...
  new.is_admin := old.is_admin;
  new.is_external := old.is_external;
  new.external_organization := old.external_organization;
  new.external_title := old.external_title;
  new.rejection_reason := old.rejection_reason;

  -- ...except a user may submit their own profile for review:
  -- incomplete/rejected -> pending only.
  if new.account_status is distinct from old.account_status then
    if old.account_status in ('incomplete', 'rejected')
       and new.account_status = 'pending' then
      -- allowed
    else
      new.account_status := old.account_status;
    end if;
  end if;

  return new;
end;
$$;
