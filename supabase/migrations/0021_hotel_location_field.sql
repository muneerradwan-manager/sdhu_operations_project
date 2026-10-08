-- Move the hotel's location field onto the new 'location' kind.
--
-- The stored VALUE does not change: it stays a map URL, so entries already
-- filled in keep working and "open link" keeps opening them. What changes is
-- how the field is filled — a map picker and a current-position button, with
-- manual entry still available underneath.
update reference_set_fields f
   set kind = 'location',
       label_ar = 'الموقع',
       label_en = 'Location'
  from reference_sets s
 where s.id = f.set_id
   and s.code = 'hotels'
   and f.key = 'location_url';
