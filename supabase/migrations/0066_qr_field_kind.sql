-- A report may carry a code to be scanned: a link to the ministry's page, a
-- menu, a form pinned to a noticeboard in a tower.
--
-- Its own field KIND rather than a column on the report, so that any type may
-- declare one, or three, or none — the same way a location or a phone number is
-- declared. A plain 'url' will not do: a link is opened, a code is displayed.
--
-- Split from 0067 because Postgres refuses to USE a new enum value in the same
-- transaction that added it, and 0068 puts a field on this kind immediately.
alter type module_field_kind add value if not exists 'qr';
