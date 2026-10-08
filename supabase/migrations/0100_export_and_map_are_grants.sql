-- Taking the data out, and seeing the season drawn, become grants.
--
-- Both were deliberately open and both comments said so, so both arguments are
-- answered here rather than quietly deleted.
--
-- **The map** was left unguarded because `season_map` narrows per reader: a
-- member gets the places of files he is IN, whoever runs files gets them all.
-- The argument was that a guard would either lock a member out of a map of his
-- own camp or be a weaker second copy of a rule already enforced. That is still
-- true of the ROWS, and the Administration has decided the SCREEN is a
-- different question — the season laid out whole is an operations-room view,
-- and a member does not need one to serve in his tower. The RPC keeps its own
-- narrowing untouched; this only decides who may open the page.
--
-- **The export** was left unguarded because it offered only what the reader
-- could already open, so it could not widen anything. That changes here, and
-- this is the part to read twice.

-- ================================================================ 1. the codes

insert into permissions (code, description, sort_order)
values ('export', 'Data export section', 13)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select 'export.data',
       'Export any dataset, including data the holder cannot open on screen',
       p.id, 1
from permissions p
where p.code = 'export'
on conflict (code) do nothing;

insert into permissions (code, description, sort_order)
values ('map', 'Season map section', 14)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select 'map.view', 'Open the season map', p.id, 1
from permissions p
where p.code = 'map'
on conflict (code) do nothing;

-- ====================================================== 2. what export.data IS
--
-- A senior read, and it must be granted as one. Until now the export screen
-- could not show anybody a row he could not already have scrolled to, because
-- every fetch goes through the same tables the screens read and RLS narrowed
-- both alike. The instruction is that whoever may take data out may take ANY of
-- it, and that cannot be done in the app: a Dart-side catalogue that offered
-- the employees to somebody without `employees.view` would produce an EMPTY
-- FILE, silently, because `profiles_select` would return nothing. An empty file
-- handed over as an export is worse than a refusal — the person believes he has
-- the data and finds out when somebody asks him for a name that is not in it.
--
-- So the widening happens where the narrowing lives. `export.data` is now the
-- second most powerful grant in the system after admin, and the description
-- above says so in the permissions editor.
--
-- TWO FENCES ARE KEPT, and they are the whole care in this migration.

-- ---------------------------------------------------------------- the roster
drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select
  using (
    id = auth.uid()
    or is_admin()
    or has_permission('employees.view')
    or has_permission('export.data')
  );

-- ------------------------------------------------------------ the season roll
drop policy if exists season_participants_select on season_participants;
create policy season_participants_select on season_participants for select
  using (
    profile_id = auth.uid()
    or has_permission('seasons.participants_view')
    or has_permission('export.data')
  );

-- --------------------------------------------------------------- master data
--
-- 0019 opened this to `is_admin() or is_approved()`, which already includes
-- anybody who could hold export.data. Restated rather than edited, so a reader
-- checking whether every dataset was covered finds the answer here instead of
-- concluding it was forgotten.

-- ------------------------------------------------- complaints and evaluations
--
-- **The fence.** Both policies deliberately hide a manager's OWN case from him:
--
--   or (can_read_all_complaints()
--       and (target_type <> 'employee'
--            or target_profile_id is distinct from auth.uid()))
--
-- 0079 says why, and it is the sharpest sentence in that migration: otherwise
-- `complaints.view` "would be the way to find out who accused you, and the
-- first person to notice would be the one it was hidden from."
--
-- A bare `or has_permission('export.data')` bolted onto those policies would
-- destroy that fence completely — a manager holding it could export the
-- complaints table and read who complained about him, which is the exact attack
-- 0079 was written to prevent, arriving through a door nobody was watching.
--
-- So the widening goes INSIDE the helper the fence is built around. The
-- `target_profile_id is distinct from auth.uid()` clause still stands in front
-- of every row, for export.data exactly as for complaints.view. A holder
-- exports every complaint in the season except the ones about himself, and that
-- is the correct answer: the export is a senior READ, not a way around
-- anonymity.

create or replace function can_read_all_complaints() returns boolean
  language sql stable security definer set search_path = public as $$
  select is_admin()
      or has_permission('complaints.view')
      or has_permission('export.data');
$$;

create or replace function can_read_all_evaluations() returns boolean
  language sql stable security definer set search_path = public as $$
  select is_admin()
      or has_permission('evaluations.view')
      or has_permission('export.data');
$$;

-- ------------------------------------------------------------------- the rest
--
-- The files, their members, their duties and the reports are read through
-- policies that already turn on `modules.view_all` or membership, and the
-- export catalogue marks those four datasets as needing no permission of their
-- own — a member exports his own files, which is what he sees. Widening them
-- would hand somebody the whole season's staffing on the strength of a grant
-- named "export", and nothing asked for that. If it is wanted later it is four
-- more `or has_permission('export.data')` clauses, and it should be a decision
-- taken on its own.

-- ================================================================= 3. the log
--
-- Every export is already an act with a reader and a timestamp; what was
-- missing was any reason to look. There is one now: this grant lets somebody
-- take out what he cannot open, so the GRANT itself is the thing worth an audit
-- trail, and `user_permissions` has carried one since 0077.
--
-- Stated rather than built: no new table. The question "who was given
-- export.data, by whom, and when" is already answerable.

-- ================================================================ the report

select p.code,
       p.description,
       (select count(*) from user_permissions up where up.permission_id = p.id)
         as granted_to
  from permissions p
 where p.code in ('export', 'export.data', 'map', 'map.view')
 order by p.code;
