-- القطاعات and المراكز belong to a season, like everything else the season is
-- arranged out of.
--
-- 0095 left these two unscoped, and the reasoning was wrong. It ran: "القطاع
-- الثالث is the same name next season, and scoping it would mean retyping the
-- list every year to say so." The premise about the name is true and the
-- conclusion does not follow — 0043 exists precisely so that a season's list is
-- CARRIED rather than retyped, and it is the same button the hotels and the
-- clusters already use every year.
--
-- And the name being stable was never the question. What a قطاع IS — how many
-- there are, which towers fall under it, which offices staff it — is settled
-- afresh each season. Unscoped, editing this year's five sectors reaches back
-- and silently rewrites what last season's files say they were. The whole point
-- of a season-scoped list is that last year's arrangement survives being
-- looked at.
--
-- So all six lists the season is built from are scoped now:
--   الفنادق (0040) · التكتلات (0040) · المجموعات (0064) · المخيمات (0095)
--   القطاعات · المراكز  ← here
--
-- Nothing in the app changes. The import action already shows itself on any
-- list that says it is season-scoped, and the pickers already narrow by season.

update reference_sets
   set is_season_scoped = true
 where code in ('sectors', 'centers');

-- ------------------------------------------------------ the entries, dated
--
-- This must not be skipped, and it is the whole risk of the migration. An entry
-- with a null season in a list that has just become scoped is invisible:
-- `itemsForSeason` keeps only the rows whose season matches, so every قطاع and
-- every مركز would vanish from the pickers at once while still sitting in the
-- table, and the files that stand on them would keep rendering — which is the
-- worst shape of a bug, because nothing looks broken until somebody tries to
-- add a node.
--
-- The season is not guessed. An entry standing in a file belongs to the season
-- of that file, and `module_nodes` records which. The shape is 0040's, down to
-- the EXISTS: the row being updated cannot be named inside the FROM clause of
-- an UPDATE.

update reference_items i
   set season_id = m.season_id
  from module_nodes n
  join modules m on m.id = n.module_id
 where n.reference_item_id = i.id
   and i.season_id is null
   and exists (
     select 1 from reference_sets s
      where s.id = i.set_id and s.code in ('sectors', 'centers')
   );

-- Whatever stands in no file yet — a sector entered before its towers were —
-- goes to the current season. The only defensible default, and one edit away
-- from being corrected.
update reference_items i
   set season_id = (select id from seasons where is_current limit 1)
 where i.season_id is null
   and exists (
     select 1 from reference_sets s
      where s.id = i.set_id and s.code in ('sectors', 'centers')
   )
   and exists (select 1 from seasons where is_current);

-- ------------------------------------------------------------------ the report
--
-- `undated` is the column that matters: anything above zero is an entry that
-- has just become invisible to the pickers, and it names its own list.

select rs.code as list,
       rs.is_season_scoped as seasonal,
       count(ri.id) as entries,
       count(ri.id) filter (where ri.season_id is null) as undated,
       coalesce(string_agg(distinct s.hijri_year::text, ' · '), '—') as seasons
  from reference_sets rs
  left join reference_items ri on ri.set_id = rs.id
  left join seasons s on s.id = ri.season_id
 where rs.code in ('sectors', 'centers', 'camps', 'hotels', 'clusters',
                   'groups')
 group by rs.code, rs.is_season_scoped
 order by rs.code;
