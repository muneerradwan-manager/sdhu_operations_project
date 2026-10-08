-- The master-data lists get shelves.
--
-- Fifteen cards in one grid, in code order, with nothing to say which of them
-- go together. The season's hotels sit beside the meal times; the قطاعات sit
-- beside the job titles. A reader looking for المخيمات reads all fifteen names
-- because there is no shape to skip past.
--
-- The home screen solved this with four shelves and the same argument (see
-- `_AdminGroup`): a heading is not decoration, it is what lets an eye skip.
--
-- **Why a column and not a map in Dart.** The grouping is editorial — nothing
-- in the schema says a فندق and a مخيم belong together while a مركز belongs
-- elsewhere, and no query can work it out. But putting it in Dart would mean
-- that a list added by a future migration lands nowhere until somebody edits
-- the app, which is exactly the coupling 0095 spent three migrations removing.
-- So the shelf is data: a new list names its shelf in its own migration, or
-- names none and falls into "أخرى" — VISIBLE, and asking to be filed.
--
-- The WORDING stays in the app, because a shelf title is content in two
-- languages and this column is a key, not a label.

alter table reference_sets
  add column if not exists section text;

comment on column reference_sets.section is
  'Which shelf this list is shown under on the master-data screen. A key, not '
  'a label — the app holds the wording in both languages. Null falls into the '
  'trailing "other" shelf rather than being hidden, because a list nobody can '
  'find is a list nobody can correct.';

-- ------------------------------------------------------------------ the shelves
--
-- Four, and each is a different KIND of thing rather than a different feature:
--
--   places     — ground somebody stands on, and what classifies it. These carry
--                coordinates and check-in codes (0098).
--   structure  — the divisions a file is built out of. Arrangements on paper:
--                nobody stands in a قطاع.
--   mission    — the people, and where they work from.
--   reports    — the fixed vocabularies a report's columns are filled from.

update reference_sets set section = 'places'
 where code in ('hotels', 'camps', 'cities', 'holy_sites');

update reference_sets set section = 'structure'
 where code in ('sectors', 'centers', 'clusters', 'groups', 'service_companies');

-- `syrian_cities` is the offices of إدارة الحج والعمرة (renamed in 0095), which
-- is where a member belongs — so it is a fact about people, not about places,
-- and its code is the only thing left saying otherwise.
update reference_sets set section = 'mission'
 where code in ('syrian_cities', 'job_titles', 'mission_types');

update reference_sets set section = 'reports'
 where code in ('mashaaer_days', 'meal_times', 'meal_natures');

-- ------------------------------------------------------------------ the report

select coalesce(section, '(none)') as shelf,
       count(*) as lists,
       string_agg(code, ' · ' order by code) as names
  from reference_sets
 group by section
 order by section nulls last;
