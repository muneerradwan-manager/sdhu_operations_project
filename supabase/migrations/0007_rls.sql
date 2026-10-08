-- Row Level Security

alter table profiles          enable row level security;
alter table job_titles        enable row level security;
alter table permissions       enable row level security;
alter table user_permissions  enable row level security;
alter table seasons           enable row level security;
alter table season_participants enable row level security;

-- ---- profiles ----
create policy profiles_select on profiles for select
  using (id = auth.uid() or is_admin() or has_permission('view_employees'));

create policy profiles_insert_self on profiles for insert
  with check (id = auth.uid());

create policy profiles_update_self on profiles for update
  using (id = auth.uid() or is_admin())
  with check (id = auth.uid() or is_admin());

-- ---- job_titles ----
-- Readable by any authenticated user (needed during profile completion, pre-approval)
create policy job_titles_select on job_titles for select
  to authenticated using (true);

create policy job_titles_write on job_titles for all
  using (is_admin()) with check (is_admin());

-- ---- permissions (catalog) ----
create policy permissions_admin_only on permissions for all
  using (is_admin()) with check (is_admin());

-- ---- user_permissions ----
create policy user_permissions_select on user_permissions for select
  using (user_id = auth.uid() or is_admin());

create policy user_permissions_write on user_permissions for all
  using (is_admin()) with check (is_admin());

-- ---- seasons ----
create policy seasons_select on seasons for select
  using (is_admin() or exists (
    select 1 from profiles
    where id = auth.uid() and account_status = 'approved'
  ));

create policy seasons_write on seasons for all
  using (is_admin()) with check (is_admin());

-- ---- season_participants ----
create policy season_participants_select on season_participants for select
  using (
    profile_id = auth.uid()
    or is_admin()
    or has_permission('view_season_participants')
  );

create policy season_participants_write on season_participants for all
  using (is_admin()) with check (is_admin());
