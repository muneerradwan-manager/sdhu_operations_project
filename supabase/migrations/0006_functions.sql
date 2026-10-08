-- Authorization helpers. SECURITY DEFINER + explicit search_path to avoid hijacking.

create function is_admin() returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles
    where id = auth.uid()
      and is_admin
      and account_status = 'approved'
  );
$$;

create function has_permission(p_code text) returns boolean
  language sql stable security definer set search_path = public as $$
  select is_admin() or exists (
    select 1
    from user_permissions up
    join permissions p on p.id = up.permission_id
    where up.user_id = auth.uid()
      and p.code = p_code
  );
$$;

-- The caller's own permission codes (so the UI can gate without reading the whole catalog)
create function my_permissions() returns setof text
  language sql stable security definer set search_path = public as $$
  select p.code
  from user_permissions up
  join permissions p on p.id = up.permission_id
  where up.user_id = auth.uid();
$$;

-- Set the current season atomically (admin only)
create function set_current_season(p_season_id uuid) returns void
  language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'not authorized';
  end if;
  update seasons set is_current = false where is_current;
  update seasons set is_current = true where id = p_season_id;
end;
$$;

-- Ensure a season exists for the given Hijri year and make it current only if it is
-- newer than the existing current season (guards against a wrong device clock).
create function ensure_current_season(p_hijri_year int, p_label text) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_season_id uuid;
  v_current_year int;
begin
  if not is_admin() then
    raise exception 'not authorized';
  end if;

  select id into v_season_id from seasons where hijri_year = p_hijri_year;

  if v_season_id is null then
    insert into seasons (hijri_year, gregorian_label)
    values (p_hijri_year, p_label)
    returning id into v_season_id;
  end if;

  select hijri_year into v_current_year from seasons where is_current;

  if v_current_year is null or p_hijri_year >= v_current_year then
    update seasons set is_current = false where is_current;
    update seasons set is_current = true where id = v_season_id;
  end if;

  return v_season_id;
end;
$$;
