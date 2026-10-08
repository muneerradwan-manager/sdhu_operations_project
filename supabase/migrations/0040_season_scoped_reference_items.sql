-- Hotels and clusters belong to a season. Cities do not.
--
-- The mission contracts a set of hotels for 1447 and a different set for 1448,
-- and the same is true of the clusters. Until now `reference_items` held one
-- flat list per set, so switching the season changed nothing: the hotels of
-- last year were still on offer for the towers of this one.
--
-- The scoping cannot go on the table, because the table also holds the Syrian
-- and Saudi cities, and دمشق is not contracted per year — it simply exists. So
-- the SET says whether its entries belong to a season, and only the entries of
-- such a set carry one.
--
-- One rule matters more than the rest here, and it shapes everything below:
--
--   the PICKER offers the entries of this season; the RESOLVER knows all.
--
-- A tower in the 1448 file points at a 1448 hotel row. Looking at that file
-- from 1447 must still show the hotel name — so nothing that resolves an id
-- to a name is ever filtered by season. Only the lists you choose FROM are.

alter table reference_sets
  add column if not exists is_season_scoped boolean not null default false;

alter table reference_items
  add column if not exists season_id uuid references seasons (id) on delete restrict;

create index if not exists idx_reference_items_season
  on reference_items (season_id);

update reference_sets
   set is_season_scoped = true
 where code in ('hotels', 'clusters');

-- ------------------------------------------------------------------ backfill
--
-- An entry already standing in a file belongs to the season of that file —
-- not a guess, it is recorded in `module_nodes`. Anything left over is put in
-- the current season, which is the only defensible default and is one edit away
-- from being corrected.

-- The set test is an EXISTS rather than a join: the row being updated cannot be
-- referenced from inside the FROM clause of an UPDATE.
--
-- An entry used in the files of two seasons takes one of them arbitrarily. It
-- is a backfill of rows that were never season-aware, not a rule: from here on
-- each season gets its own entry, and the duplicate is one edit away.
update reference_items i
   set season_id = m.season_id
  from module_nodes n
  join modules m on m.id = n.module_id
 where n.reference_item_id = i.id
   and i.season_id is null
   and exists (
     select 1 from reference_sets s
      where s.id = i.set_id and s.is_season_scoped
   );

update reference_items i
   set season_id = (select id from seasons where is_current limit 1)
 where i.season_id is null
   and exists (
     select 1 from reference_sets s
      where s.id = i.set_id and s.is_season_scoped
   )
   and exists (select 1 from seasons where is_current);

-- ----------------------------------------------------------------- uniqueness
--
-- 0017 made a name unique within its set. That was right when a set was one
-- list; now the same فندق الصفوة is a legitimate row in 1447 and again in 1448,
-- and the old constraint would refuse the second. Unique per (set, season, name)
-- instead, with a null season folded to a fixed uuid so that the unscoped sets,
-- where every season_id is null, keep exactly the old behaviour.

do $$
declare
  v_name text;
begin
  select conname into v_name
    from pg_constraint
   where conrelid = 'reference_items'::regclass
     and contype = 'u'
     and pg_get_constraintdef(oid) like '%set_id%name_ar%';
  if v_name is not null then
    execute format('alter table reference_items drop constraint %I', v_name);
  end if;
end
$$;

create unique index if not exists uq_reference_items_name_per_season
  on reference_items (
    set_id,
    name_ar,
    coalesce(season_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );
