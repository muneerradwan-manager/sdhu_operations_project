-- Two city lists, not one.
--
-- A hotel sits in a Saudi city (Makkah, Madinah). A cluster is a Syrian body
-- and belongs to a Syrian governorate. Pointing both at a single `cities` list
-- would have offered Makkah as a cluster's home city and Damascus as a hotel's
-- location — so the original list is renamed to what it actually held, and a
-- second one is created beside it.
--
-- Clusters also gain a phone number: the head of a cluster is the person a
-- tower supervisor calls, and the number belongs next to the name.

-- 1. The existing list was seeded as `cities` holding Makkah and Madinah.
--    Name it for what it is; hotels keep pointing at the same row.
update reference_sets
   set code = 'saudi_cities',
       name_ar = 'المدن السعودية',
       name_en = 'Saudi cities'
 where code = 'cities';

-- The hotel field was labelled "النوع" back when the list was unnamed and read
-- as "Makkah hotel or Madinah hotel". With the list named, it is a city.
update reference_set_fields f
   set label_ar = 'المدينة',
       label_en = 'City'
  from reference_sets s
 where s.id = f.set_id
   and s.code = 'hotels'
   and f.key = 'city';

-- 2. Syrian cities, seeded with the fourteen governorates. Admin-editable like
--    every other list — this is a starting point, not a fixed set.
insert into reference_sets (code, name_ar, name_en)
values ('syrian_cities', 'المدن السورية', 'Syrian cities')
on conflict (code) do nothing;

insert into reference_items (set_id, name_ar, name_en, sort_order)
select rs.id, v.name_ar, v.name_en, v.sort_order
from (values
  ('دمشق',        'Damascus',    1),
  ('ريف دمشق',    'Rif Dimashq', 2),
  ('حلب',         'Aleppo',      3),
  ('حمص',         'Homs',        4),
  ('حماة',        'Hama',        5),
  ('اللاذقية',    'Latakia',     6),
  ('طرطوس',       'Tartus',      7),
  ('إدلب',        'Idlib',       8),
  ('دير الزور',   'Deir ez-Zor', 9),
  ('الرقة',       'Raqqa',      10),
  ('الحسكة',      'Al-Hasakah', 11),
  ('درعا',        'Daraa',      12),
  ('السويداء',    'As-Suwayda', 13),
  ('القنيطرة',    'Quneitra',   14)
) as v(name_ar, name_en, sort_order)
join reference_sets rs on rs.code = 'syrian_cities'
on conflict (set_id, name_ar) do nothing;

-- 3. Point the cluster's city field at the Syrian list.
update reference_set_fields f
   set reference_set_id = target.id
  from reference_sets s, reference_sets target
 where s.id = f.set_id
   and s.code = 'clusters'
   and f.key = 'city'
   and target.code = 'syrian_cities';

-- Any cluster already saved with a Saudi city now points outside its own list
-- and would render blank. Clear those values so the field reads as empty and
-- asks to be filled, rather than silently holding an unresolvable id.
update reference_items i
   set data = i.data - 'city'
  from reference_sets s
 where s.id = i.set_id
   and s.code = 'clusters'
   and i.data ->> 'city' in (
     select ri.id::text
     from reference_items ri
     join reference_sets rs on rs.id = ri.set_id
     where rs.code = 'saudi_cities'
   );

-- 4. The cluster's phone number, sitting between the deputy and the city.
update reference_set_fields f
   set sort_order = 4
  from reference_sets s
 where s.id = f.set_id
   and s.code = 'clusters'
   and f.key = 'city';

insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, is_required, sort_order)
select s.id, 'phone', 'رقم الهاتف', 'Phone number', 'phone', false, 3
from reference_sets s
where s.code = 'clusters'
on conflict (set_id, key) do nothing;
