-- Once per season: the three meal documents.
--
-- توزيع الوجبات, مواعيدها, ومكوناتها are published once for the whole season —
-- the Administration issues each as ONE document, and a second توزيع for the
-- same year would not be another report, it would be a contradiction of the
-- first. Corrections go into the report that exists.
--
-- A property of the TYPE, not a hard-coded list of three: the next once-a-year
-- document gets the same behaviour by flipping a column, which is the bargain
-- the whole catalog makes (a new kind of report is data, not a schema change).
--
-- "The season" includes the general bucket: a once-per-season type saved as
-- GENERAL (season_id null) is likewise one document, not many.

alter table report_types
  add column if not exists once_per_season boolean not null default false;

update report_types
   set once_per_season = true
 where code in (
   'mashaaer_meal_distribution',
   'mashaaer_meal_timing',
   'mashaaer_meal_components'
 );

-- A trigger rather than a unique index: the rule holds only for types that
-- declare it, and an index cannot ask another table. SECURITY DEFINER so the
-- existence check sees every report, not just what RLS shows the saver —
-- a duplicate hidden from the writer is still a duplicate.
create or replace function enforce_report_once_per_season() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from report_types t
     where t.id = new.report_type_id and t.once_per_season
  ) then
    return new;
  end if;

  -- Two people entering the same document at the same moment would both pass
  -- the check below; the lock makes the second wait and then fail honestly.
  perform pg_advisory_xact_lock(hashtextextended(
    'report_once:' || new.report_type_id::text
      || ':' || coalesce(new.season_id::text, 'general'), 0));

  if exists (
    select 1 from reports r
     where r.report_type_id = new.report_type_id
       and r.season_id is not distinct from new.season_id
       and r.id <> new.id
  ) then
    -- A token, not a sentence: the app matches on it and says this in the
    -- reader's language (error_text.dart).
    raise exception 'report_once_per_season';
  end if;
  return new;
end;
$$;

-- Dropped first: Postgres has no `create trigger if not exists`, and a
-- migration that cannot be run twice is a migration that fails a retry.
drop trigger if exists reports_once_per_season on reports;
create trigger reports_once_per_season
  before insert or update of report_type_id, season_id on reports
  for each row execute function enforce_report_once_per_season();
