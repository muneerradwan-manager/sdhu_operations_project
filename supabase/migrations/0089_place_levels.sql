-- Which levels are PLACES, and which are only arrangements.
--
-- A check-in code is a sticker screwed to something physical: a tower's
-- entrance, a camp's gate. Some levels of a file are that, and some are not,
-- and until now nothing recorded which — so the screen that lists them had to
-- guess, and every available guess is wrong for at least one of the five types:
--
--   * "the deepest level" — wrong for مكة. The tree there is
--     القطاع(1) → البرج/الفندق(2) → التكتل(3), and the تكتل was added later
--     (0061) BELOW the tower. A تكتل is a bloc of pilgrims inside a building,
--     not a building; taking the deepest level offers codes for the blocs and
--     none for the hotels, which is exactly backwards.
--   * "a level with a reference set" — wrong for the same reason: the تكتل
--     draws from `clusters` just as the tower draws from `hotels`.
--   * "not the outermost" — wrong for منى and عرفات, where المركز is an
--     arrangement and المخيم below it is the place.
--
-- So it is stated rather than inferred. A level says whether it is somewhere a
-- person can stand and a sticker can be fixed.
--
-- Default FALSE, deliberately. A level added by a future migration carries no
-- code until somebody says it is a place — which shows up as an empty list
-- with a sentence explaining why, and not as codes printed for something with
-- no gate to put them on. Two places answering to one code is the failure that
-- makes the whole register lie.

alter table module_type_levels
  add column if not exists is_place boolean not null default false;

comment on column module_type_levels.is_place is
  'Whether a node at this level is a physical place — somewhere a person '
  'stands and a check-in code can be fixed. A برج is; the قطاع above it and '
  'the تكتل below it are not. Read by the place-code screen (0087).';

-- ------------------------------------------------------------------ the seed
--
-- The three that exist today. Named by their own codes rather than by depth,
-- because depth is the thing that misled the screen in the first place.
--
--   makkah_sectors_towers  → البرج/الفندق, drawn from the hotels list
--   arafat_camp_assignment → المخيم, drawn from the Arafat camps list
--   mina_camp_assignment   → المخيم, named by hand
--
-- Left false everywhere else, and each of those is a considered answer rather
-- than an omission:
--   * القطاع and المركز are arrangements on paper — no gate.
--   * التكتل is a bloc of pilgrims inside a tower that already has a code.
--   * شركة الخدمة (المدينة) is a company, not a building.
--   * القطاع (المشاعر) is a team's patch, not a place it sits in.
update module_type_levels lv
   set is_place = true
  from module_types mt
 where mt.id = lv.module_type_id
   and (
     (mt.code = 'makkah_sectors_towers'  and lv.code = 'tower')
     or (mt.code = 'arafat_camp_assignment' and lv.code = 'camp')
     or (mt.code = 'mina_camp_assignment'   and lv.code = 'camp')
   );
