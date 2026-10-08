-- The first three report types: the meals of the Mashaaer.
--
-- Three documents the Administration publishes each year, and the reason the
-- reports section exists. Everyone eats, so everyone reads them; nobody is
-- assigned to them.
--
-- They are three types rather than one because they are three documents, and
-- the second is not a subset of the third by accident — توقيت is what a
-- supervisor pins up, مكونات is what he answers questions from. Folding them
-- together would mean publishing one and calling it the other.
--
-- All three are keyed the same way — (التاريخ, الوجبة) — and all three write the
-- date once and read it down the page, which is what `spans_rows` says.

-- ------------------------------------------------- 1. توزيع الوجبات على التكتلات

insert into report_types
  (code, name_ar, name_en, description_ar, description_en, sort_order)
values (
  'mashaaer_meal_distribution',
  'توزيع الوجبات على التكتلات',
  'Meal distribution across the clusters',
  'عدد الوجبات المقرَّرة لحجاج كل تكتل في أيام المشاعر، بحسب النسبة المعتمدة '
  'لكل وجبة.',
  'The number of meals allotted to each cluster''s pilgrims during the days of '
  'the holy sites, against the approved ratio for each meal.',
  1
)
on conflict (code) do nothing;

insert into report_type_columns
  (report_type_id, key, label_ar, label_en, kind, source_set_id, spans_rows, sort_order)
select rt.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
       rs.id, v.spans_rows, v.sort_order
from (values
  ('day',   'التاريخ', 'Date',  'text',   null,       true,  1),
  ('meal',  'الوجبة',  'Meal',  'text',   null,       false, 2),
  ('ratio', 'النسبة',  'Ratio', 'text',   null,       false, 3),
  -- One declaration, one column per تكتل of this report's season. The clusters
  -- are contracted per year, so the type cannot name them and must not try.
  ('clusters', 'التكتلات', 'Clusters', 'number', 'clusters', false, 4),
  ('total', 'المجموع', 'Total', 'number', null,       false, 5)
) as v(key, label_ar, label_en, kind, set_code, spans_rows, sort_order)
cross join report_types rt
left join reference_sets rs on rs.code = v.set_code
where rt.code = 'mashaaer_meal_distribution'
on conflict (report_type_id, key) do nothing;

-- ------------------------------------------------------- 2. توقيت الوجبات

insert into report_types
  (code, name_ar, name_en, description_ar, description_en, sort_order)
values (
  'mashaaer_meal_timing',
  'مواعيد تقديم الوجبات',
  'Meal service times',
  'مواعيد تقديم الوجبات أيام المشاعر ونوع كل وجبة — جافة أو ساخنة.',
  'When each meal is served during the days of the holy sites, and whether it '
  'is a dry or a hot meal.',
  2
)
on conflict (code) do nothing;

insert into report_type_columns
  (report_type_id, key, label_ar, label_en, kind, spans_rows, sort_order)
select rt.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
       v.spans_rows, v.sort_order
from (values
  ('day',    'التاريخ',  'Date',    'text', true,  1),
  ('meal',   'الوجبة',   'Meal',    'text', false, 2),
  ('nature', 'نوعها',    'Kind',    'text', false, 3),
  ('window', 'توقيتها',  'Served',  'text', false, 4)
) as v(key, label_ar, label_en, kind, spans_rows, sort_order)
cross join report_types rt
where rt.code = 'mashaaer_meal_timing'
on conflict (report_type_id, key) do nothing;

-- ------------------------------------------------------ 3. مكونات الوجبات

insert into report_types
  (code, name_ar, name_en, description_ar, description_en, sort_order)
values (
  'mashaaer_meal_components',
  'مكونات الوجبات',
  'What each meal contains',
  'مكوّنات كل وجبة من وجبات المشاعر، مع نوعها وموعد تقديمها.',
  'What each meal of the holy sites contains, with its kind and when it is '
  'served.',
  3
)
on conflict (code) do nothing;

insert into report_type_columns
  (report_type_id, key, label_ar, label_en, kind, spans_rows, sort_order)
select rt.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
       v.spans_rows, v.sort_order
from (values
  ('day',        'التاريخ',   'Date',       'text',     true,  1),
  ('meal',       'الوجبة',    'Meal',       'text',     false, 2),
  ('nature',     'نوعها',     'Kind',       'text',     false, 3),
  ('window',     'التوقيت',   'Served',     'text',     false, 4),
  -- A list, and it stays a list of lines rather than becoming five columns:
  -- the documents give a different number of items per meal, and the shortest
  -- has four while the longest has ten.
  ('components', 'المكونات',  'Contents',   'textarea', false, 5)
) as v(key, label_ar, label_en, kind, spans_rows, sort_order)
cross join report_types rt
where rt.code = 'mashaaer_meal_components'
on conflict (report_type_id, key) do nothing;

-- ------------------------------------------------- what all three may carry
--
-- Every report of every kind gets the same three header affordances: the paper
-- it was typed from, a link out, and a code to scan. They are declared per type
-- because a type is free not to want them — but these three all do, and the
-- documents they come from are real files somebody holds.

insert into report_type_fields
  (report_type_id, key, label_ar, label_en, kind, is_required, sort_order)
select rt.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
       false, v.sort_order
from (values
  ('note',        'ملاحظات',            'Notes',        'textarea', 1),
  ('source_url',  'رابط',               'Link',         'url',      2),
  ('qr',          'رمز للمسح',          'Scannable code', 'qr',     3),
  ('official_pdf','المستند الرسمي (PDF)', 'Official document', 'pdf', 4)
) as v(key, label_ar, label_en, kind, sort_order)
cross join report_types rt
where rt.code in (
  'mashaaer_meal_distribution',
  'mashaaer_meal_timing',
  'mashaaer_meal_components'
)
on conflict (report_type_id, key) do nothing;
