-- A برج is a فندق, and it belongs to a تكتل.
--
-- 0024 made a node's identity a single entry of a single list: a tower IS a
-- hotel, drawn from the hotels. The cluster was a field on the FILE back in
-- 0017 and was deleted when the tree arrived, because a file has many towers
-- and one field could not say which cluster which tower belonged to. It has had
-- nowhere to live since, and it is asked for at exactly the moment the tower is
-- entered: this hotel, its supervisor, his deputies, its mission members — and
-- the تكتل it falls under.
--
-- So a level may now name a SECOND list: not what a node is, but what it is
-- tied to. The tower level is tied to the clusters. Nothing else in the catalog
-- names one, and a level that does not is exactly what it was before.
--
-- And a تكتل is entered once, like the hotel. That is the whole use of writing
-- it down — a cluster standing in two towers is the mistake this is meant to
-- catch — so it is a partial unique index and not a convention, the same shape
-- `uq_module_nodes_entry` already has.

alter table module_type_levels
  add column if not exists secondary_reference_set_id uuid
    references reference_sets (id) on delete restrict;

comment on column module_type_levels.secondary_reference_set_id is
  'A second list a node at this level is tied to — the تكتل of a برج. Null for '
  'a level that ties to nothing, which is every level but one.';

alter table module_nodes
  add column if not exists secondary_reference_item_id uuid
    references reference_items (id) on delete restrict;

comment on column module_nodes.secondary_reference_item_id is
  'The entry chosen from the level''s secondary list. Null when the level names '
  'no such list.';

create unique index if not exists uq_module_nodes_secondary_entry
  on module_nodes (module_id, level_id, secondary_reference_item_id)
  where secondary_reference_item_id is not null;

-- The one level that has a second list.
update module_type_levels lv
   set secondary_reference_set_id = rs.id
  from module_types mt, reference_sets rs
 where mt.id = lv.module_type_id
   and mt.code = 'makkah_sectors_towers'
   and lv.code = 'tower'
   and rs.code = 'clusters';
