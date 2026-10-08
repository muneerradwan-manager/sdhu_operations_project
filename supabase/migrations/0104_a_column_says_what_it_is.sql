-- A table's column says what its cells ARE.
--
-- Until now a table block's column was a bare string — its heading — with two
-- parallel bool lists (`spans`, `tags`) indexed by position. A column is an
-- object now: {"id","label","kind","set","span"}, with seven kinds (text,
-- number, date, time, time_range, reference, tags). The id is what lets a
-- rename keep its data and a reorder carry its cells; the kind is what lets
-- the editor offer a date picker for a date and this season's clusters for a
-- تكتل instead of a text box to misspell either into.
--
-- No schema change: `report_blocks.data` is free-form jsonb and `save_report`
-- writes it opaquely. This is a DATA migration, and every statement is
-- re-runnable — the `jsonb_typeof` guard on step 1 makes a second run a no-op.
--
-- ------------------------------------------------------ 1. strings become objects
--
-- Only where the first column is still a string. The id is 'c' || position,
-- because position IS the legacy identity — the rows are positional — and the
-- Dart parser derives exactly the same ids, so a block converted here and one
-- parsed there agree about which column is which.

update report_blocks b
   set data = (b.data - 'spans' - 'tags')
       || jsonb_build_object(
            'columns',
            (select jsonb_agg(
                      jsonb_strip_nulls(jsonb_build_object(
                        'id', 'c' || (c.ordinality - 1),
                        'label', c.value,
                        'kind',
                        case when (b.data -> 'tags' -> (c.ordinality - 1)::int)
                                  = 'true'::jsonb
                             then 'tags' else 'text' end,
                        'span',
                        case when (b.data -> 'spans' -> (c.ordinality - 1)::int)
                                  = 'true'::jsonb
                             then true end
                      ))
                      order by c.ordinality
                    )
               from jsonb_array_elements_text(b.data -> 'columns')
                    with ordinality as c(value, ordinality))
          )
 where b.kind = 'table'
   and jsonb_typeof(b.data -> 'columns') = 'array'
   and jsonb_array_length(b.data -> 'columns') > 0
   and jsonb_typeof(b.data -> 'columns' -> 0) = 'string';

-- ---------------------------------------------- 2. discover the reference columns
--
-- 0070 rewrote التاريخ/الوجبة/نوعها cells from names to reference-item ids, and
-- 0103 flattened them into the blocks verbatim — so the three converted meal
-- documents hold uuids where a reader wants names. The Dart reader resolves a
-- reference column; this says WHICH columns are references, and it does so
-- self-verifyingly: a column is retyped only when EVERY non-empty cell at its
-- position is already the id of an entry, and every one of those entries
-- belongs to one and the same set. It never fires on a column the data does
-- not already satisfy.

with candidates as (
  select b.id as block_id,
         (col.ordinality - 1)::int as position,
         min(rs.code) as set_code
    from report_blocks b
    cross join jsonb_array_elements(b.data -> 'columns')
         with ordinality as col(value, ordinality)
    cross join jsonb_array_elements(b.data -> 'rows') as row(value)
    left join lateral (
      select row.value ->> (col.ordinality - 1)::int as cell
    ) c on true
    -- The UUID column is cast to text, never the cell to uuid. Postgres does
    -- not promise to evaluate join conditions in order, so guarding a
    -- `cell::uuid` behind a regex still let the cast run first and abort the
    -- whole migration on the first cell that read «من الساعة 13:00…». A
    -- text-to-text comparison cannot error on any input.
    left join reference_items ri on ri.id::text = c.cell
    left join reference_sets rs on rs.id = ri.set_id
   where b.kind = 'table'
     and col.value ->> 'kind' = 'text'
   group by b.id, col.ordinality
  having count(*) filter (where coalesce(c.cell, '') <> '') > 0
     and count(*) filter (where coalesce(c.cell, '') <> '')
         = count(ri.id)
     and count(distinct rs.code) = 1
)
update report_blocks b
   set data = jsonb_set(
     b.data,
     '{columns}',
     (select jsonb_agg(
               case when (col.ordinality - 1)::int = cand.position
                    then col.value
                         || jsonb_build_object('kind', 'reference',
                                               'set', cand.set_code)
                    else col.value
               end
               order by col.ordinality)
        from jsonb_array_elements(b.data -> 'columns')
             with ordinality as col(value, ordinality))
   )
  from candidates cand
 where b.id = cand.block_id;

-- --------------------------------------------------- 3. discover the time ranges
--
-- A column whose every non-empty cell carries two clock times is a time range.
-- The CELLS are left alone: the Dart reader parses the legacy localized
-- sentence («من الساعة 13:00 إلى الساعة 16:00») as readily as the canonical
-- form, and the first save from the editor writes canonical. A read-mostly
-- migration is one that can be re-run without thinking.

with candidates as (
  select b.id as block_id,
         (col.ordinality - 1)::int as position
    from report_blocks b
    cross join jsonb_array_elements(b.data -> 'columns')
         with ordinality as col(value, ordinality)
    cross join jsonb_array_elements(b.data -> 'rows') as row(value)
   where b.kind = 'table'
     and col.value ->> 'kind' = 'text'
   group by b.id, col.ordinality
  having count(*) filter (
           where coalesce(row.value ->> (col.ordinality - 1)::int, '') <> ''
         ) > 0
     and count(*) filter (
           where coalesce(row.value ->> (col.ordinality - 1)::int, '') <> ''
         ) = count(*) filter (
           where row.value ->> (col.ordinality - 1)::int
                 ~ '\d{1,2}:\d{2}.*\d{1,2}:\d{2}'
         )
)
update report_blocks b
   set data = jsonb_set(
     b.data,
     '{columns}',
     (select jsonb_agg(
               case when (col.ordinality - 1)::int = cand.position
                    then col.value || jsonb_build_object('kind', 'time_range')
                    else col.value
               end
               order by col.ordinality)
        from jsonb_array_elements(b.data -> 'columns')
             with ordinality as col(value, ordinality))
   )
  from candidates cand
 where b.id = cand.block_id;

-- --------------------------------------------------------------- 4. the record
--
-- 0069 documented the shape inside `create table if not exists`, which no
-- later migration can amend. A `comment on` can, and is re-runnable.

comment on column report_blocks.data is
  'Per kind. A table holds {"columns":[{"id","label","kind","set","span"}],'
  '"rows":[[...]],"expand":<set code>,"expand_at":<int>,"expand_kind":<kind>}. '
  'Rows are positional against the columns with the expansion spliced at '
  'expand_at. Legacy blocks hold bare-string columns with parallel spans/tags '
  'lists; the Dart parser reads both and the first save normalises. Cell '
  'canonical forms: date yyyy-MM-dd, time HH:mm, time_range HH:mm-HH:mm, '
  'reference the entry''s id, tags newline-joined.';

-- ------------------------------------------------------------------ the report
--
-- `legacy_keys` must be zero: a block still carrying `spans`/`tags` was not
-- up-converted, and the first column's type says whether step 1 saw it.

select r.title,
       jsonb_array_length(b.data -> 'columns') as columns,
       (select count(*)
          from jsonb_array_elements(b.data -> 'columns') c
         where c.value ->> 'kind' <> 'text') as typed_columns,
       (case when b.data ? 'spans' or b.data ? 'tags' then 1 else 0 end)
         as legacy_keys
  from report_blocks b
  join reports r on r.id = b.report_id
 where b.kind = 'table'
 order by r.title;
