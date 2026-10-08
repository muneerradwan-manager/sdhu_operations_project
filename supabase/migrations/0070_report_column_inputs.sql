-- How a column is FILLED, as against what it holds.
--
-- Every column of the three meal reports has been a text box, and four of them
-- should never have been:
--
--   التاريخ   is one of six days of the Mashaaer.
--   الوجبة    is one of three.
--   نوعها     is one of two.
--   المجموع   is the sum of the row. Typed, it is a second place for the same
--             number to live and the first place it goes wrong — a cluster's
--             count corrected and the total left standing.
--   التوقيت   is a span between two clock times, and 'من الساعة 13:00 إلى 16:00'
--             written by hand comes out four ways in fourteen rows.
--
-- The first three become MASTER DATA, not a list baked into a migration. They
-- are the same kind of thing as the hotels, the clusters, the groups and the
-- cities: real lists the Administration owns, that it must be able to correct
-- and add to without anyone writing SQL. A day is renamed the year the calendar
-- shifts; a fourth meal appears the year a fourth meal is served.
--
-- Which also means the column needs nothing new to say so — `reference_set_id`
-- and `kind = 'reference'` have meant "choose from this list" since 0067.
--
-- `input` remains for the two that are not lists: a span of clock times, and a
-- number worked out rather than entered. `kind` says what the value IS; this
-- says how it is ASKED for, and a number entered by a person and a number
-- computed are both numbers.

alter table report_type_columns
  add column if not exists input text;

comment on column report_type_columns.input is
  'How the editor asks for this column when a list will not do: ''time_range'' '
  'for a from–to span, ''sum'' for a value computed from the row rather than '
  'entered. Null for a plain field. A column that offers a CHOICE says so with '
  'kind = ''reference'' and a reference_set_id, like everything else does.';

-- ------------------------------------------------------------- the new lists
--
-- Not season-scoped: the days of the Mashaaer and the names of the meals are
-- the same every year. The hotels are contracted per season and the meals are
-- not, which is the whole distinction `is_season_scoped` draws.

insert into reference_sets (code, name_ar, name_en, is_season_scoped)
values
  ('mashaaer_days', 'أيام المشاعر',   'Days of the holy sites', false),
  ('meal_times',    'الوجبات',        'Meals',                  false),
  ('meal_natures',  'أنواع الوجبات',  'Meal kinds',             false)
on conflict (code) do nothing;

-- Seeded from the documents, because that is how the Administration writes
-- them: the day is named together with what happens on it.
--
-- Guarded with NOT EXISTS rather than ON CONFLICT: 0040 replaced the plain
-- (set_id, name_ar) constraint with an expression index that folds a null
-- season to a sentinel, and ON CONFLICT cannot name an expression index without
-- restating the whole expression. Asking is clearer than spelling it three
-- times.
insert into reference_items (set_id, name_ar, name_en, sort_order)
select rs.id, v.name_ar, v.name_en, v.sort_order
from (values
  ('8 ذي الحجة - تروية',  'Dhul-Hijjah 8 — Tarwiyah', 1),
  ('9 ذي الحجة - عرفات',  'Dhul-Hijjah 9 — Arafat',   2),
  ('10 ذي الحجة - تشريق', 'Dhul-Hijjah 10 — Tashreeq', 3),
  ('11 ذي الحجة - تشريق', 'Dhul-Hijjah 11 — Tashreeq', 4),
  ('12 ذي الحجة - تشريق', 'Dhul-Hijjah 12 — Tashreeq', 5),
  ('13 ذي الحجة - تشريق', 'Dhul-Hijjah 13 — Tashreeq', 6)
) as v(name_ar, name_en, sort_order)
join reference_sets rs on rs.code = 'mashaaer_days'
where not exists (
  select 1 from reference_items i
   where i.set_id = rs.id and i.name_ar = v.name_ar and i.season_id is null
);

insert into reference_items (set_id, name_ar, name_en, sort_order)
select rs.id, v.name_ar, v.name_en, v.sort_order
from (values
  ('فطور', 'Breakfast', 1),
  ('غداء', 'Lunch',     2),
  ('عشاء', 'Dinner',    3)
) as v(name_ar, name_en, sort_order)
join reference_sets rs on rs.code = 'meal_times'
where not exists (
  select 1 from reference_items i
   where i.set_id = rs.id and i.name_ar = v.name_ar and i.season_id is null
);

insert into reference_items (set_id, name_ar, name_en, sort_order)
select rs.id, v.name_ar, v.name_en, v.sort_order
from (values
  ('جافة',  'Dry', 1),
  ('ساخنة', 'Hot', 2)
) as v(name_ar, name_en, sort_order)
join reference_sets rs on rs.code = 'meal_natures'
where not exists (
  select 1 from reference_items i
   where i.set_id = rs.id and i.name_ar = v.name_ar and i.season_id is null
);

-- ------------------------------------------------- point the columns at them

update report_type_columns c
   set kind = 'reference', reference_set_id = rs.id
  from report_types t, reference_sets rs
 where t.id = c.report_type_id
   and rs.code = 'mashaaer_days'
   and t.code in (
     'mashaaer_meal_distribution',
     'mashaaer_meal_timing',
     'mashaaer_meal_components'
   )
   and c.key = 'day';

update report_type_columns c
   set kind = 'reference', reference_set_id = rs.id
  from report_types t, reference_sets rs
 where t.id = c.report_type_id
   and rs.code = 'meal_times'
   and t.code in (
     'mashaaer_meal_distribution',
     'mashaaer_meal_timing',
     'mashaaer_meal_components'
   )
   and c.key = 'meal';

update report_type_columns c
   set kind = 'reference', reference_set_id = rs.id
  from report_types t, reference_sets rs
 where t.id = c.report_type_id
   and rs.code = 'meal_natures'
   and t.code in ('mashaaer_meal_timing', 'mashaaer_meal_components')
   and c.key = 'nature';

update report_type_columns c
   set input = 'sum'
  from report_types t
 where t.id = c.report_type_id
   and t.code = 'mashaaer_meal_distribution'
   and c.key = 'total';

update report_type_columns c
   set input = 'time_range'
  from report_types t
 where t.id = c.report_type_id
   and t.code in ('mashaaer_meal_timing', 'mashaaer_meal_components')
   and c.key = 'window';

-- ------------------------------------------- and carry the rows over with them
--
-- The three reports were seeded with the day and the meal written as TEXT,
-- which is what those columns held at the time. A reference column stores an
-- id, so every row already entered has to be translated or it reads as blank —
-- the data is right, and only the way it points has changed.

update report_rows r
   set data = r.data
     || jsonb_build_object('day', (
          select i.id::text
            from reference_items i
            join reference_sets s on s.id = i.set_id
           where s.code = 'mashaaer_days'
             and i.name_ar = r.data ->> 'day'
        ))
 where jsonb_exists(r.data, 'day')
   and exists (
     select 1 from reference_items i
     join reference_sets s on s.id = i.set_id
     where s.code = 'mashaaer_days' and i.name_ar = r.data ->> 'day'
   );

update report_rows r
   set data = r.data
     || jsonb_build_object('meal', (
          select i.id::text
            from reference_items i
            join reference_sets s on s.id = i.set_id
           where s.code = 'meal_times'
             and i.name_ar = r.data ->> 'meal'
        ))
 where jsonb_exists(r.data, 'meal')
   and exists (
     select 1 from reference_items i
     join reference_sets s on s.id = i.set_id
     where s.code = 'meal_times' and i.name_ar = r.data ->> 'meal'
   );

update report_rows r
   set data = r.data
     || jsonb_build_object('nature', (
          select i.id::text
            from reference_items i
            join reference_sets s on s.id = i.set_id
           where s.code = 'meal_natures'
             and i.name_ar = r.data ->> 'nature'
        ))
 where jsonb_exists(r.data, 'nature')
   and exists (
     select 1 from reference_items i
     join reference_sets s on s.id = i.set_id
     where s.code = 'meal_natures' and i.name_ar = r.data ->> 'nature'
   );

-- ------------------------------------------------------------- the contents
--
-- المكونات is a LIST of things — خبز, زبدة, زيتون, شوربة عدس — and a textarea
-- makes it one blob whose items are separated by whatever the typist pressed.
-- As tags each item is a thing that can be added, removed and read at a glance,
-- and the row still stores them one per line, which is what was seeded and what
-- the published document shows.
update report_type_columns c
   set input = 'tags'
  from report_types t
 where t.id = c.report_type_id
   and t.code = 'mashaaer_meal_components'
   and c.key = 'components';
