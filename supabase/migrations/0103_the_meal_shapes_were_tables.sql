-- توزيع الوجبات and مواعيدها ومكوناتها were never kinds of document.
--
-- They were three TABLES, and they became report types of their own because a
-- written document could not hold a table that did what they needed. 0102 gave
-- the table block those powers — a column per تكتل drawn from master data, a
-- value printed once against the rows it covers, a cell read as a list — so
-- the types have nothing left to justify them.
--
-- What they cost while they existed: a person opening the editor to write a
-- قرار was asked, before he had typed a title, to choose between عام and three
-- shapes of meal timetable. That is a structural question, put to somebody who
-- had come to write a decision, about a thing he was probably not writing.
--
-- ------------------------------------------------------------- what moves
--
-- Each of the three documents becomes a general one carrying a single table
-- block. The block is built from the type's own declaration, so nothing is
-- retyped and nothing is guessed:
--
--   * a plain column      → a heading, in sort order
--   * `spans_rows`        → the block's `spans`
--   * `input = 'tags'`    → the block's `tags`
--   * `source_set_id`     → the block's `expand`, as the set's CODE
--
-- The rows become positional lists in exactly the order a reader will resolve
-- the headings back to: the typed columns in sort order, then the entries of
-- the expanding list ordered by `sort_order, name_ar` and scoped to the
-- document's own season — which is `ReferenceSet.fromMap`'s sort and
-- `itemsForSeason`'s filter, restated here because a value under the wrong
-- heading is the one error nobody notices until the numbers are quoted.
--
-- Idempotent: a document that already carries blocks is skipped, so a second
-- run does not append a second copy of its own table.

-- ------------------------------------------------------- 1. rows into a block

insert into report_blocks (report_id, kind, data, sort_order)
select r.id,
       'table'::report_block_kind,
       jsonb_build_object(
         'columns',   coalesce(plain.labels, '[]'::jsonb),
         'spans',     coalesce(plain.spans,  '[]'::jsonb),
         'tags',      coalesce(plain.tags,   '[]'::jsonb),
         'expand',    expand.code,
         -- WHERE the generated columns go among the typed ones. توزيع الوجبات
         -- puts them between النسبة and المجموع, because the total is the sum
         -- across the clusters and belongs after the things it totals.
         -- Appending blindly would move a published document's column.
         'expand_at', expand.at,
         'rows',      coalesce(body.rows, '[]'::jsonb)
       ),
       1
  from reports r
  join report_types t on t.id = r.report_type_id
  -- The typed columns, in the order they are declared.
  left join lateral (
    select jsonb_agg(c.label_ar order by c.sort_order) as labels,
           jsonb_agg(c.spans_rows order by c.sort_order) as spans,
           jsonb_agg(coalesce(c.input, '') = 'tags' order by c.sort_order)
             as tags
      from report_type_columns c
     where c.report_type_id = t.id and c.source_set_id is null
  ) plain on true
  -- The one that expands, named by the CODE of the list it draws from so the
  -- document keeps resolving in a season whose entries differ.
  left join lateral (
    select rs.code,
           -- How many typed columns are declared BEFORE it.
           (select count(*)::int
              from report_type_columns c2
             where c2.report_type_id = t.id
               and c2.source_set_id is null
               and c2.sort_order < c.sort_order) as at,
           c.sort_order as ord
      from report_type_columns c
      join reference_sets rs on rs.id = c.source_set_id
     where c.report_type_id = t.id and c.source_set_id is not null
     order by c.sort_order
     limit 1
  ) expand on true
  -- Every row, as a list of values positioned against those headings.
  left join lateral (
    select jsonb_agg(row_values order by rr.sort_order) as rows
      from report_rows rr
      cross join lateral (
        select coalesce(jsonb_agg(v order by ord), '[]'::jsonb) as row_values
          from (
            -- The typed columns, at their declared position.
            select c.sort_order * 1000 as ord,
                   to_jsonb(coalesce(rr.data ->> c.key, '')) as v
              from report_type_columns c
             where c.report_type_id = t.id and c.source_set_id is null
            union all
            -- And the generated ones AT THE EXPANDING COLUMN'S OWN POSITION,
            -- not appended: multiplying the declared order by a thousand
            -- leaves room for them to sit between two typed columns, which is
            -- where the distribution table wants them. Ordered exactly as the
            -- reader resolves them — `ReferenceSet.fromMap` sorts by
            -- sort_order then name_ar, and `itemsForSeason` scopes to the
            -- document's season. A value under the wrong heading is the one
            -- error nobody notices until the numbers are quoted.
            select c.sort_order * 1000 + row_number() over (
                     order by ri.sort_order, ri.name_ar
                   ) as ord,
                   to_jsonb(coalesce(rr.data ->> ri.id::text, '')) as v
              from report_type_columns c
              join reference_sets rs on rs.id = c.source_set_id
              join reference_items ri on ri.set_id = rs.id
             where c.report_type_id = t.id
               and c.source_set_id is not null
               and (not rs.is_season_scoped or ri.season_id = r.season_id)
          ) cells
      ) built
     where rr.report_id = r.id
  ) body on true
 where t.code in (
         'mashaaer_meal_distribution',
         'mashaaer_meal_timing',
         'mashaaer_meal_components'
       )
   and not exists (
     select 1 from report_blocks b where b.report_id = r.id
   );

-- ------------------------------------------------------ 2. the documents move

-- `reports_guard_update` (0073) refuses any change to a report from somebody
-- without `reports.edit`, and it decides that from `auth.uid()`. A migration
-- run in the SQL editor has no `auth.uid()`, so the guard reads it as an
-- anonymous stranger editing a published document and raises "not authorized"
-- — which is exactly right for the case it was written for, and exactly wrong
-- for this one.
--
-- So it is switched off for the length of the statement and back on after,
-- inside ONE `do` block. That matters: a `do` block is a single transaction, so
-- if the update fails the disable rolls back with it and the guard cannot be
-- left off. Done as two loose statements, a failure between them would leave
-- the season's decisions unguarded until somebody noticed.
do $$
begin
  alter table reports disable trigger reports_guard_update;

  update reports r
     set report_type_id = g.id
    from report_types t, report_types g
   where t.id = r.report_type_id
     and g.code = 'general'
     and t.code in (
       'mashaaer_meal_distribution',
       'mashaaer_meal_timing',
       'mashaaer_meal_components'
     );

  alter table reports enable trigger reports_guard_update;
end
$$;

-- The rows are gone from the document's point of view: its content is the block
-- now, and leaving them would give it two bodies, one of which nothing reads.
delete from report_rows rr
 using reports r, report_types t
 where rr.report_id = r.id
   and t.id = r.report_type_id
   and t.code = 'general'
   and exists (select 1 from report_blocks b where b.report_id = r.id);

-- ------------------------------------------------------------ 3. the types go
--
-- Unguarded on the report_type_id foreign key, deliberately: if a document
-- still points at one of these, this raises and names it rather than deleting
-- the shape out from under it. Everything above should have moved them.

delete from report_type_columns c
 using report_types t
 where t.id = c.report_type_id
   and t.code in (
     'mashaaer_meal_distribution',
     'mashaaer_meal_timing',
     'mashaaer_meal_components'
   );

delete from report_type_fields f
 using report_types t
 where t.id = f.report_type_id
   and t.code in (
     'mashaaer_meal_distribution',
     'mashaaer_meal_timing',
     'mashaaer_meal_components'
   );

delete from report_types
 where code in (
   'mashaaer_meal_distribution',
   'mashaaer_meal_timing',
   'mashaaer_meal_components'
 );

-- ------------------------------------------------------------------ the report
--
-- One type left, and three documents carrying a block each. `orphan_rows` must
-- be zero: a row still attached to a converted document is a body nothing
-- reads.

select t.code,
       count(distinct r.id) as documents,
       count(distinct b.id) as blocks,
       count(distinct rr.id) as leftover_rows
  from report_types t
  left join reports r on r.report_type_id = t.id
  left join report_blocks b on b.report_id = r.id
  left join report_rows rr on rr.report_id = r.id
 group by t.code
 order by t.code;
