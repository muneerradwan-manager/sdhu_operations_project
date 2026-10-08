-- Account suspension support.
-- A suspended account keeps its data and history but loses all access until an
-- admin reactivates it. Modeled as a boolean (more flexible than an enum value).

alter table profiles
  add column if not exists is_suspended boolean not null default false;

-- Admins must not be admin while suspended, and suspension is a privileged
-- column only admins may change.
create or replace function is_admin() returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles
    where id = auth.uid()
      and is_admin
      and not is_suspended
      and account_status = 'approved'
  );
$$;

-- A suspended user must not exercise granted permissions either.
create or replace function has_permission(p_code text) returns boolean
  language sql stable security definer set search_path = public as $$
  select is_admin() or exists (
    select 1
    from user_permissions up
    join permissions p on p.id = up.permission_id
    join profiles pr on pr.id = up.user_id
    where up.user_id = auth.uid()
      and p.code = p_code
      and not pr.is_suspended
      and pr.account_status = 'approved'
  );
$$;

-- Extend the privileged-columns guard so non-admins can't change is_suspended.
create or replace function profiles_guard_privileged_columns() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  caller_is_admin boolean;
begin
  if auth.uid() is null then
    return new;
  end if;

  select p.is_admin and p.account_status = 'approved' and not p.is_suspended
    into caller_is_admin
  from public.profiles p
  where p.id = auth.uid();

  caller_is_admin := coalesce(caller_is_admin, false);

  if caller_is_admin then
    return new;
  end if;

  new.is_admin := old.is_admin;
  new.is_external := old.is_external;
  new.external_organization := old.external_organization;
  new.external_title := old.external_title;
  new.rejection_reason := old.rejection_reason;
  new.is_suspended := old.is_suspended;

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
