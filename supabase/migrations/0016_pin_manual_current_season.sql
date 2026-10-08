-- Manually choosing an older season as "current" had no lasting effect.
--
-- SeasonsCubit.load() calls ensure_current_season(device Hijri year) on every
-- admin load, and it runs again immediately after set_current_season. Its rule
-- `p_hijri_year >= current year` then promoted the newest season straight back
-- over the admin's choice, so the archive stayed archived and the newest season
-- stayed current.
--
-- Fix: a manual choice is recorded as a pin. `pinned_for_hijri_year` holds the
-- Hijri year that was running when the admin made the choice, and
-- ensure_current_season leaves a pinned season alone until the Hijri year rolls
-- over past it. The yearly auto-advance still happens — exactly once per new
-- year — without fighting an explicit admin decision.

-- Written to be safe to re-run: a first attempt may have landed the column
-- before failing on a later statement.
alter table seasons add column if not exists pinned_for_hijri_year int;

-- Set the current season atomically (admin only), recording it as a manual pin.
-- p_pinned_for_hijri_year is the caller's current Hijri year; null pins forever.
-- The single-argument version is dropped rather than replaced: adding a
-- defaulted second parameter would leave an ambiguous overload behind.
drop function if exists set_current_season(uuid);

create or replace function set_current_season(
  p_season_id uuid,
  p_pinned_for_hijri_year int default null
) returns void
  language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'not authorized';
  end if;

  if not exists (select 1 from seasons where id = p_season_id) then
    raise exception 'season not found';
  end if;

  update seasons
     set is_current = false,
         pinned_for_hijri_year = null
   where is_current or pinned_for_hijri_year is not null;

  update seasons
     set is_current = true,
         pinned_for_hijri_year = p_pinned_for_hijri_year
   where id = p_season_id;
end;
$$;

-- Ensure a season row exists for the given Hijri year, and make it current only
-- when that is newer than the season in place (guards against a wrong device
-- clock) and the season in place was not manually pinned for this Hijri year.
create or replace function ensure_current_season(p_hijri_year int, p_label text) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_season_id uuid;
  v_current_year int;
  v_pinned_for int;
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

  select hijri_year, pinned_for_hijri_year
    into v_current_year, v_pinned_for
    from seasons where is_current;

  -- A pin holds until the Hijri year advances past the year it was made in.
  if v_current_year is not null
     and v_pinned_for is not null
     and p_hijri_year <= v_pinned_for then
    return v_season_id;
  end if;

  if v_current_year is null or p_hijri_year > v_current_year then
    update seasons
       set is_current = false,
           pinned_for_hijri_year = null
     where is_current;
    update seasons set is_current = true where id = v_season_id;
  end if;

  return v_season_id;
end;
$$;
