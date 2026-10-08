-- Two numbers the Administration asked for, and a permission that never worked.

-- ------------------------------------------------------- what a place holds
--
-- A فندق has a ceiling and a تكتل has a size, and the two are the arithmetic
-- everyone does by hand when the towers file is drawn up: does this cluster fit
-- in that hotel. Both are optional — 3142 states neither, and a required field
-- the source decision does not carry cannot be filled in honestly (0061 says
-- the same thing about the camps' الطاقة الاستيعابية).
--
-- They sit on the master-data ENTRY rather than on the node: a hotel's capacity
-- is a fact about the hotel in this season's contract, true wherever it is
-- used, and re-entering it per file is how two files come to disagree.

insert into reference_set_fields
  (set_id, key, label_ar, label_en, kind, is_required, sort_order)
select rs.id, v.key, v.label_ar, v.label_en, v.kind::module_field_kind,
       false, v.sort_order
from (values
  ('hotels',   'capacity',    'الحد الأقصى للسعة',  'Maximum capacity', 'number', 3),
  ('clusters', 'total_count', 'العدد الكلي للحجاج', 'Total pilgrims',   'number', 5)
) as v(set_code, key, label_ar, label_en, kind, sort_order)
join reference_sets rs on rs.code = v.set_code
on conflict (set_id, key) do nothing;

-- ------------------------------------------------ who may read a grant sheet
--
-- 0013 created `permissions.manage` and the app has gated its permission editor
-- on it ever since. The table it edits never learned: `user_permissions` has
-- been admin-only since 0007, so anyone granted `permissions.manage` and not
-- made an admin saw an editor that could load nothing and save nothing.
--
-- Reading is widened the same way, and for the same reason the employee detail
-- screen now shows a card of what someone holds: seeing the grants IS the first
-- half of changing them, and a manager who cannot see them cannot manage them.
--
-- `has_permission` already returns true for an admin, so this replaces the old
-- rule rather than sitting beside it.
drop policy if exists user_permissions_select on user_permissions;
create policy user_permissions_select on user_permissions for select
  using (user_id = auth.uid() or has_permission('permissions.manage'));

drop policy if exists user_permissions_write on user_permissions;
create policy user_permissions_write on user_permissions for all
  using (has_permission('permissions.manage'))
  with check (has_permission('permissions.manage'));
