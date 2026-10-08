-- What starts the work, and what ends it, said by the file rather than by its kind.
--
-- The first section of creating a file has been the same four facts on every
-- type since 0058 — `starts_on`, `ends_on`, `decision_number`, `report_cadence`
-- — with two exceptions that were not facts of the file at all: the type's
-- `start_condition` and `end_condition` (0024). Those are prose about a KIND of
-- file, the same sentence every season, printed into the form where an input
-- belongs. So a file whose type states them showed six rows and one whose type
-- does not showed four, and neither could say anything of its own about the day
-- it opened.
--
-- These two columns are that thing. Optional, both of them: most files are
-- opened on a date and need no sentence beside it, and the note about the end
-- is usually not writable until the end has happened.
--
-- The type's conditions are untouched and stay where they are read — they still
-- say what event opens and closes files of this kind. A note is the answer for
-- ONE file, in the words of whoever opened it.

alter table modules
  add column if not exists start_note text,
  add column if not exists end_note text;

comment on column modules.start_note is
  'ملاحظة بداية العمل — optional, per file. What this file''s start was, in the '
  'words of whoever opened it. Distinct from module_types.start_condition, '
  'which is prose about every file of the kind.';

comment on column modules.end_note is
  'ملاحظة نهاية العمل — optional, per file. Distinct from '
  'module_types.end_condition, which states the event that closes files of this '
  'kind, the same sentence every season.';
