-- A hotel's location is not just any link: it names a point on the ground, and
-- the admin should be able to drop a pin on a map or take their current
-- position instead of pasting a URL.
--
-- That gets its own field kind rather than overloading 'url' — a plain link
-- field (a website, a form) must not offer a "use my location" button.
--
-- Split from 0021 because Postgres refuses to USE a new enum value in the same
-- transaction that added it, and 0021 retargets the hotel field immediately.
alter type module_field_kind add value if not exists 'location';
