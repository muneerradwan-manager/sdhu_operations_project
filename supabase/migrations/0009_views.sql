-- Permanent staff = internal, approved employees. Listings/reports use this
-- so the "exclude externals and unapproved" rule lives in one place.
-- security_invoker so the caller's RLS on profiles still applies.
create view permanent_employees
  with (security_invoker = true) as
  select *
  from profiles
  where is_external = false
    and account_status = 'approved';
