-- The register that pointed at the paperwork.
--
-- Run this only after 0098 has been executed AND its report read: `unpinned`
-- must be zero, or the season starts with places nobody can check in at. This
-- is a separate file for exactly that reason — the two halves must be able to
-- be verified apart.
--
-- The rows are DELETED, not migrated, and that is a decision rather than
-- laziness. An old row has no secret, no radius, and a distance measured under
-- a rule that let everything through — 0087 accepted a check-in with no
-- position at all, and 0094 accepted one 900 metres out. Carrying them across
-- would put rows on the new board that the new board's own rule would have
-- refused, and the first question anybody asks of a register is whether
-- everything in it obeys the same rule.
--
-- Order is forced. `season_map` was rewritten in 0098 and no longer names
-- node_check_ins; had it not been, dropping the table would have SUCCEEDED —
-- Postgres records no dependency for a dollar-quoted `language sql` body — and
-- the map would have failed at the next person who opened it.
--
-- What stays: `metres_between` (0087), which check_in_at_place still uses, and
-- `node_location`, which 0098 rewrote to ask place_location and which the map
-- still reads.

drop function if exists module_presence(uuid, timestamptz);

drop function if exists check_in_here(
  uuid, uuid, check_in_method, double precision, double precision,
  double precision, text);

-- Unguarded on purpose: no `cascade`. If anything still names this table, this
-- raises and names the thing — which is worth far more than dropping it out
-- from under a function nobody has run yet today.
drop table if exists node_check_ins;

-- Nothing else uses it. One method now — a code plus a position — so an enum
-- with three values would only record that the system used to accept two more.
drop type if exists check_in_method;
