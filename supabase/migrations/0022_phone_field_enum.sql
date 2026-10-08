-- A phone number is not plain text: it wants a numeric keypad when entered and
-- a tap-to-call when read. This app coordinates by phone, so it earns a kind.
--
-- Split from 0023 for the usual reason: Postgres refuses to USE a new enum
-- value in the transaction that added it, and 0023 seeds a phone field.
alter type module_field_kind add value if not exists 'phone';
