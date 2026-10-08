-- The موقع of a فندق is a place, not a link.
--
-- 0019 gave the hotels a `location_url` of kind `url`, because `url` was the
-- only kind there was — the `location` kind arrived a migration later (0020),
-- and the field was never moved onto it. So the one column in this app that
-- most obviously names a place has been treated as a web address ever since:
-- entered by pasting rather than by dropping a pin, and shown to the reader as
-- a hundred characters of URL rather than as somewhere to go.
--
-- Nothing about the stored value changes. A location IS a map URL — that is
-- what `MapLocation` writes and what "open on the map" launches — so every row
-- already holds exactly what the location kind expects. What changes is that
-- the app now knows what it is looking at: the editor offers the map and the
-- current position beside the paste box, and every screen that shows a place
-- can offer to open it instead of printing it.

update reference_set_fields f
   set kind = 'location'::module_field_kind,
       label_ar = 'الموقع',
       label_en = 'Location'
  from reference_sets s
 where s.id = f.set_id
   and s.code = 'hotels'
   and f.key = 'location_url'
   and f.kind = 'url'::module_field_kind;
