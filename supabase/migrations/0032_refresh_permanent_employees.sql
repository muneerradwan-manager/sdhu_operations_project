-- `permanent_employees` was stale, and had been for two migrations.
--
-- 0009 created it as `select * from profiles where …`. Postgres expands that
-- star ONCE, at creation, and stores the resulting column list — so the view has
-- carried exactly the columns `profiles` had in 0009 ever since. `email` (0026)
-- and `city_id` (0030) were added to the table and never appeared in it.
--
-- Which is not only a missing column. PostgREST works out what a view may be
-- joined to from the columns it actually exposes: with no `city_id` in the view
-- there is no path to `reference_items`, and asking for the city of a permanent
-- employee failed outright —
--
--   PGRST200: Could not find a relationship between 'permanent_employees'
--             and 'reference_items' in the schema cache
--
-- while the same embed on `profiles` worked, which is what made it look like a
-- problem with the query rather than with the view.
--
-- Replacing it re-expands the star against today's table. Only appends columns,
-- which is the one shape of change `create or replace view` accepts.

create or replace view permanent_employees
  with (security_invoker = true) as
  select *
  from profiles
  where is_external = false
    and account_status = 'approved';

-- PostgREST caches the schema and will keep refusing the join until it is told
-- to look again.
notify pgrst, 'reload schema';
