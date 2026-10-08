-- Master-data entries need a link field (a hotel's location on a map), so the
-- field-kind enum gains 'url'.
--
-- This lives in its own migration on purpose: Postgres refuses to USE a new
-- enum value in the same transaction that added it, and 0019 seeds a 'url'
-- field straight away. Splitting the ALTER into its own file gives it its own
-- transaction and lets the seed run.
alter type module_field_kind add value if not exists 'url';
