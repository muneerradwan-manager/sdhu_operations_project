-- A report may carry a number, and usually does.
--
-- Everything the Administration issues is numbered — قـرار اداري 3172, تكليف
-- 3142 — and a report published from one of those decisions is referred to by
-- that number long before anybody remembers its title. Somebody asking about
-- "3190" should be able to find it.
--
-- Optional, and it has to be: a meal timetable is published without one, and a
-- required field that half the reports cannot fill is a field people put a dash
-- in. On the report rather than in its `data`, because it is not one type's
-- field — every kind of report may have one, general and special alike.
alter table reports
  add column if not exists number text;

comment on column reports.number is
  'The reference number the report was issued under, when it has one. Free '
  'text: they are written ''3190'' and ''3190/47'' and both are the number as '
  'the Administration wrote it.';

-- Searched by it, and there will be hundreds before long.
create index if not exists idx_reports_number on reports (number)
  where number is not null;
