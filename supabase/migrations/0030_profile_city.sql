-- Which Syrian city an employee is from.
--
-- The list already exists: 0023 seeded `syrian_cities` with the fourteen
-- governorates, admin-editable like every other reference list. So this is not
-- a new list — it is the profile finally pointing at the one that is there,
-- instead of the fourteen being available to clusters and to nobody else.
--
-- Optional on purpose. Every account created before today has no city, and the
-- column has to be answerable later without locking anyone out of an app they
-- already registered for.

alter table profiles
  add column if not exists city_id uuid
    references reference_items (id) on delete restrict;

create index if not exists idx_profiles_city on profiles (city_id);

-- ---------------------------------------------------------------- readable now
--
-- The catalog is readable by `is_admin() or is_approved()`, and the person who
-- needs this list is neither: he is filling in the form that will make him
-- pending. Without this he would meet an empty dropdown and could not finish
-- registering at all.
--
-- Only the Syrian cities, and only the reading of them. It is the same
-- exception `job_titles` has carried since 0007, and for the same reason —
-- a list of governorates is not a secret, it is a form field.

drop policy if exists reference_sets_select_signup on reference_sets;
create policy reference_sets_select_signup on reference_sets for select
  to authenticated using (code = 'syrian_cities');

drop policy if exists reference_items_select_signup on reference_items;
create policy reference_items_select_signup on reference_items for select
  to authenticated using (
    exists (
      select 1 from reference_sets s
      where s.id = reference_items.set_id and s.code = 'syrian_cities'
    )
  );

-- ------------------------------------------------------------------- in use
--
-- A governorate somebody is registered in cannot be deleted from the list. The
-- foreign key would refuse it anyway; naming it here is what lets the app show
-- the translated explanation instead of a raw constraint error.

create or replace function reference_item_in_use(p_item_id uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select
    exists (
      select 1
      from modules m
      join module_type_fields f on f.module_type_id = m.module_type_id
      where f.kind = 'reference'
        and m.data ->> f.key = p_item_id::text
    )
    or exists (
      select 1 from module_nodes where reference_item_id = p_item_id
    )
    or exists (
      select 1
      from reference_items i
      join reference_set_fields f on f.set_id = i.set_id
      where f.kind = 'reference'
        and i.data ->> f.key = p_item_id::text
    )
    or exists (
      select 1 from profiles where city_id = p_item_id
    );
$$;
