-- ============================================================================
-- مواقع الفنادق والمخيمات — موسم 1447
--
-- NOT a migration. It writes CONTENT — where the mission's hotels and camps
-- actually are — and content belongs under seeds, where nothing runs against a
-- database by accident. Run it by hand in the SQL editor.
--
-- WHERE THESE NUMBERS CAME FROM. The Administration's address sheet holds
-- shortened `maps.app.goo.gl` links, and a short link carries no position at
-- all — the coordinates are on the far side of a redirect. Each of the 44 was
-- followed once, and what is written below is the canonical `?q=lat,lng` this
-- app reads. Nothing here depends on Google's URL shape, and `node_location()`
-- can read a position without following anything — which is what puts a place
-- on the season map.
--
-- WHY THE HOTELS ARE LISTED BY THEIR CATALOGUE NAME. The sheet and the master
-- data do not spell them alike: the sheet writes "فندق فيوليت" where the
-- catalogue holds "فيوليت 3 - 10000966", and "فندق هياء" for
-- "إبراهيم علي العقل (هياء)". Matching those inside SQL would mean fuzzy
-- comparison against live rows, where a wrong guess pins one hotel onto
-- another and nothing says so. The pairing was done once, by reading both
-- lists, and is written out here so that it can be READ and corrected.
--
-- ---------------------------------------------------------------------------
-- WHAT TO CHECK. The last statement prints it, and three things are known:
--
--   * 44 places land on 28 distinct points. SEVEN Madinah hotels share one —
--     the central district, pinned once instead of per building. They will
--     stack into a single marker on the map.
--   * Two pairs carry the IDENTICAL link in the sheet — بركة اليقين with
--     زاد اليقين, and ميزاب الخير with ميلينيوم الدانة. One link for two
--     hotels is a copy-paste, and one of each pair is in the wrong place.
--   * NOT SEEDED, because neither has an entry in the hotels list:
--       - فندق اورنيز
--       - فندق روتانا جبل عمر
--     "فندق اورنيز" is almost certainly "منصور الثبيتي (اورينز)" — the same
--     hotel with two letters transposed. Left out rather than guessed at; add
--     it by hand if that is right.
--
-- ---------------------------------------------------------------------------
-- EVERY STATEMENT STANDS ALONE, and the repetition below is the reason.
--
-- The first version of this file put the addresses in a temporary table and
-- read it from the statements underneath. It failed with `relation
-- "_hotel_pins" does not exist`: Supabase's SQL editor does not necessarily run
-- a script as one session, so a temporary table can be gone before the next
-- statement asks for it. The list is therefore inlined into each statement as
-- a `values` CTE — longer to read, and it cannot fail that way.
--
-- Each statement is also safe to run twice: they set a value rather than insert
-- a row, so running the file again writes the same coordinates over themselves.
-- ============================================================================

-- ------------------------------------------------------------------- hotels
--
-- Into `location_url`, which the hotels list has carried since 0019 and which
-- 0056 re-declared as a location rather than a bare URL.
with pins (name, url) as (
  values
    ('أنجم - 10001487', 'https://www.google.com/maps?q=21.420395,39.830174'),   -- فندق أنجم
    ('إبراهيم علي العقل (هياء) - 10011798', 'https://www.google.com/maps?q=21.412833,39.873914'),   -- فندق هياء
    ('افق الخيمة - 10012747', 'https://www.google.com/maps?q=21.424361,39.80168'),   -- فندق افق الخيمة
    ('البلد روافد - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- البلد روافد
    ('الدار روافد - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- الدار روافد
    ('الرسالة الماسي - 10007923', 'https://www.google.com/maps?q=21.374279,39.84483'),   -- فندق الرسالة الماسي
    ('المناخة روتانا - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- المناخة روتانا
    ('ام ملينيوم - 10002236', 'https://www.google.com/maps?q=21.40066,39.823137'),   -- فندق ام ملينيوم
    ('انكيرا - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- انكيرا
    ('بركة اليقين - 10010172', 'https://www.google.com/maps?q=21.440655,39.804381'),   -- فندق بركة اليقين
    ('جاد كدي - 10007042', 'https://www.google.com/maps?q=21.385485,39.839831'),   -- فندق الجاد كدي
    ('جوهرة ال صبغة 1 - 10012631', 'https://www.google.com/maps?q=21.438201,39.868248'),   -- فندق ال صبغة
    ('جوهرة النزهة - 10011735', 'https://www.google.com/maps?q=21.443981,39.844608'),   -- فندق جوهرة النزهة
    ('دار الايمان الحرم - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- دار الايمان الحرم
    ('دفلى 2 - 10011067', 'https://www.google.com/maps?q=21.443981,39.844608'),   -- فندق دفلى 2
    ('زاد اليقين - 10010919', 'https://www.google.com/maps?q=21.440655,39.804381'),   -- فندق زاد اليقين
    ('زمزم بولمان - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.456346,39.626976'),   -- زمزم بولمان
    ('سنود الريان - 10001983', 'https://www.google.com/maps?q=21.416049,39.871001'),   -- فندق سنود الريان
    ('سنود المشاعر - 10012634', 'https://www.google.com/maps?q=21.438201,39.868248'),   -- فندق سنود المشاعر
    ('شعائر الحياة - 10007459', 'https://www.google.com/maps?q=21.443539,39.859518'),   -- فندق شعائر الحياة
    ('عفراء - 10000993', 'https://www.google.com/maps?q=21.404173,39.871114'),   -- فندق عفراء
    ('فجر النسك - 10011289', 'https://www.google.com/maps?q=21.395307,39.876087'),   -- فندق فجر النسك
    ('فيلفيت ان - 10012235', 'https://www.google.com/maps?q=21.392762,39.891137'),   -- فندق فيلفيت ان
    ('فيوليت 3 - 10000966', 'https://www.google.com/maps?q=21.434819,39.858679'),   -- فندق فيوليت
    ('كراون بلازا - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- كراون بلازا
    ('مرجانة الحجاز - 10012908', 'https://www.google.com/maps?q=21.403908,39.818468'),   -- فندق مرجانة الحجاز
    ('مياس - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- مياس
    ('ميزاب الخير - 10010182', 'https://www.google.com/maps?q=21.428893,39.865335'),   -- فندق ميزاب الخير
    ('ميلينيوم الدانة - 10006701', 'https://www.google.com/maps?q=21.428893,39.865335'),   -- فندق ميلينيوم الدانة
    ('نرجس الحديقة - 10007206', 'https://www.google.com/maps?q=21.400098,39.817917')   -- فندق نرجس الحديقة
)
update reference_items ri
   set data = jsonb_set(coalesce(ri.data, '{}'::jsonb), '{location_url}',
                        to_jsonb(pins.url))
  from pins, reference_sets rs
 where rs.id = ri.set_id
   and rs.code = 'hotels'
   and btrim(ri.name_ar) = pins.name;

-- ------------------------------------------------------ Mina & Arafat camps
--
-- Matched on the NUMBER, not the name. The sheet writes "مركز 14" and the file
-- writes "المخيم رقم 14" — the same place under two names the mission uses
-- interchangeably, and the digits are the only part both agree on.
--
-- The location field is found by its KIND rather than by a key, exactly as
-- `node_location()` finds it — so this keeps working if a type ever spells the
-- key differently. Two statements because a camp is named by hand in منى and
-- drawn from the `arafat_camps` list in عرفات: the number is on the node's own
-- label in one and on the reference item in the other.
with cp (kind, place, url) as (
  values
    ('مخيمات منى', 'مركز 10', 'https://www.google.com/maps?q=21.424128,39.89651'),
    ('مخيمات منى', 'مركز 11', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات منى', 'مركز 12', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات منى', 'مركز 14', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات منى', 'مركز 15', 'https://www.google.com/maps?q=21.357056,39.981289'),
    ('مخيمات منى', 'مركز 16', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات عرفات', 'مركز 10', 'https://www.google.com/maps?q=21.347387,39.990017'),
    ('مخيمات عرفات', 'مركز 11', 'https://www.google.com/maps?q=21.35564,39.987227'),
    ('مخيمات عرفات', 'مركز 14', 'https://www.google.com/maps?q=21.346421,39.983884'),
    ('مخيمات عرفات', 'مركز 15', 'https://www.google.com/maps?q=21.356354,39.977012'),
    ('مخيمات عرفات', 'مركز 16', 'https://www.google.com/maps?q=21.346421,39.983884'),
    ('مخيمات عرفات', 'مركز12', 'https://www.google.com/maps?q=21.347387,39.990017')
)
update module_nodes n
   set data = jsonb_set(coalesce(n.data, '{}'::jsonb),
                        array[f.key], to_jsonb(cp.url))
  from modules m, module_types mt, module_type_levels lv,
       module_type_fields f, cp
 where m.id = n.module_id
   and mt.id = m.module_type_id
   and lv.id = n.level_id
   and lv.is_place
   and f.module_type_id = mt.id
   and f.level_id = lv.id
   and f.kind = 'location'
   and (
        (mt.code = 'mina_camp_assignment'   and cp.kind = 'مخيمات منى')
     or (mt.code = 'arafat_camp_assignment' and cp.kind = 'مخيمات عرفات')
   )
   and nullif(regexp_replace(coalesce(n.label, ''), '[^0-9]', '', 'g'), '')
     = nullif(regexp_replace(cp.place,              '[^0-9]', '', 'g'), '');

with cp (kind, place, url) as (
  values
    ('مخيمات منى', 'مركز 10', 'https://www.google.com/maps?q=21.424128,39.89651'),
    ('مخيمات منى', 'مركز 11', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات منى', 'مركز 12', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات منى', 'مركز 14', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات منى', 'مركز 15', 'https://www.google.com/maps?q=21.357056,39.981289'),
    ('مخيمات منى', 'مركز 16', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات عرفات', 'مركز 10', 'https://www.google.com/maps?q=21.347387,39.990017'),
    ('مخيمات عرفات', 'مركز 11', 'https://www.google.com/maps?q=21.35564,39.987227'),
    ('مخيمات عرفات', 'مركز 14', 'https://www.google.com/maps?q=21.346421,39.983884'),
    ('مخيمات عرفات', 'مركز 15', 'https://www.google.com/maps?q=21.356354,39.977012'),
    ('مخيمات عرفات', 'مركز 16', 'https://www.google.com/maps?q=21.346421,39.983884'),
    ('مخيمات عرفات', 'مركز12', 'https://www.google.com/maps?q=21.347387,39.990017')
)
update module_nodes n
   set data = jsonb_set(coalesce(n.data, '{}'::jsonb),
                        array[f.key], to_jsonb(cp.url))
  from modules m, module_types mt, module_type_levels lv,
       module_type_fields f, reference_items ri, cp
 where m.id = n.module_id
   and mt.id = m.module_type_id
   and lv.id = n.level_id
   and lv.is_place
   and ri.id = n.reference_item_id
   and f.module_type_id = mt.id
   and f.level_id = lv.id
   and f.kind = 'location'
   and (
        (mt.code = 'mina_camp_assignment'   and cp.kind = 'مخيمات منى')
     or (mt.code = 'arafat_camp_assignment' and cp.kind = 'مخيمات عرفات')
   )
   and nullif(regexp_replace(ri.name_ar, '[^0-9]', '', 'g'), '')
     = nullif(regexp_replace(cp.place,    '[^0-9]', '', 'g'), '');

-- ------------------------------------------------------------------- report
--
-- What landed and — the line that matters — what did not. A seed that matched
-- nothing looks exactly like a seed that worked.
with pins (name, url) as (
  values
    ('أنجم - 10001487', 'https://www.google.com/maps?q=21.420395,39.830174'),   -- فندق أنجم
    ('إبراهيم علي العقل (هياء) - 10011798', 'https://www.google.com/maps?q=21.412833,39.873914'),   -- فندق هياء
    ('افق الخيمة - 10012747', 'https://www.google.com/maps?q=21.424361,39.80168'),   -- فندق افق الخيمة
    ('البلد روافد - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- البلد روافد
    ('الدار روافد - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- الدار روافد
    ('الرسالة الماسي - 10007923', 'https://www.google.com/maps?q=21.374279,39.84483'),   -- فندق الرسالة الماسي
    ('المناخة روتانا - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- المناخة روتانا
    ('ام ملينيوم - 10002236', 'https://www.google.com/maps?q=21.40066,39.823137'),   -- فندق ام ملينيوم
    ('انكيرا - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- انكيرا
    ('بركة اليقين - 10010172', 'https://www.google.com/maps?q=21.440655,39.804381'),   -- فندق بركة اليقين
    ('جاد كدي - 10007042', 'https://www.google.com/maps?q=21.385485,39.839831'),   -- فندق الجاد كدي
    ('جوهرة ال صبغة 1 - 10012631', 'https://www.google.com/maps?q=21.438201,39.868248'),   -- فندق ال صبغة
    ('جوهرة النزهة - 10011735', 'https://www.google.com/maps?q=21.443981,39.844608'),   -- فندق جوهرة النزهة
    ('دار الايمان الحرم - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- دار الايمان الحرم
    ('دفلى 2 - 10011067', 'https://www.google.com/maps?q=21.443981,39.844608'),   -- فندق دفلى 2
    ('زاد اليقين - 10010919', 'https://www.google.com/maps?q=21.440655,39.804381'),   -- فندق زاد اليقين
    ('زمزم بولمان - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.456346,39.626976'),   -- زمزم بولمان
    ('سنود الريان - 10001983', 'https://www.google.com/maps?q=21.416049,39.871001'),   -- فندق سنود الريان
    ('سنود المشاعر - 10012634', 'https://www.google.com/maps?q=21.438201,39.868248'),   -- فندق سنود المشاعر
    ('شعائر الحياة - 10007459', 'https://www.google.com/maps?q=21.443539,39.859518'),   -- فندق شعائر الحياة
    ('عفراء - 10000993', 'https://www.google.com/maps?q=21.404173,39.871114'),   -- فندق عفراء
    ('فجر النسك - 10011289', 'https://www.google.com/maps?q=21.395307,39.876087'),   -- فندق فجر النسك
    ('فيلفيت ان - 10012235', 'https://www.google.com/maps?q=21.392762,39.891137'),   -- فندق فيلفيت ان
    ('فيوليت 3 - 10000966', 'https://www.google.com/maps?q=21.434819,39.858679'),   -- فندق فيوليت
    ('كراون بلازا - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- كراون بلازا
    ('مرجانة الحجاز - 10012908', 'https://www.google.com/maps?q=21.403908,39.818468'),   -- فندق مرجانة الحجاز
    ('مياس - المدينة المنورة 1447', 'https://www.google.com/maps?q=24.465146,39.619661'),   -- مياس
    ('ميزاب الخير - 10010182', 'https://www.google.com/maps?q=21.428893,39.865335'),   -- فندق ميزاب الخير
    ('ميلينيوم الدانة - 10006701', 'https://www.google.com/maps?q=21.428893,39.865335'),   -- فندق ميلينيوم الدانة
    ('نرجس الحديقة - 10007206', 'https://www.google.com/maps?q=21.400098,39.817917')   -- فندق نرجس الحديقة
),
cp (kind, place, url) as (
  values
    ('مخيمات منى', 'مركز 10', 'https://www.google.com/maps?q=21.424128,39.89651'),
    ('مخيمات منى', 'مركز 11', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات منى', 'مركز 12', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات منى', 'مركز 14', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات منى', 'مركز 15', 'https://www.google.com/maps?q=21.357056,39.981289'),
    ('مخيمات منى', 'مركز 16', 'https://www.google.com/maps?q=21.421147,39.914453'),
    ('مخيمات عرفات', 'مركز 10', 'https://www.google.com/maps?q=21.347387,39.990017'),
    ('مخيمات عرفات', 'مركز 11', 'https://www.google.com/maps?q=21.35564,39.987227'),
    ('مخيمات عرفات', 'مركز 14', 'https://www.google.com/maps?q=21.346421,39.983884'),
    ('مخيمات عرفات', 'مركز 15', 'https://www.google.com/maps?q=21.356354,39.977012'),
    ('مخيمات عرفات', 'مركز 16', 'https://www.google.com/maps?q=21.346421,39.983884'),
    ('مخيمات عرفات', 'مركز12', 'https://www.google.com/maps?q=21.347387,39.990017')
)
select 'فندق' as kind, pins.name as place, pins.url,
       exists (
         select 1 from reference_items ri
           join reference_sets rs on rs.id = ri.set_id
          where rs.code = 'hotels'
            and btrim(ri.name_ar) = pins.name
            and ri.data ->> 'location_url' = pins.url
       ) as landed
  from pins
union all
select cp.kind, cp.place, cp.url,
       exists (
         select 1 from module_nodes n
          where n.data::text like '%' || cp.url || '%'
       )
  from cp
 order by landed, kind, place;
