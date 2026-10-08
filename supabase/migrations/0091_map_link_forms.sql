-- The third shape a map link comes in.
--
-- `node_location` (0087) read two forms: the `?q=lat,lng` this app writes, and
-- the `@lat,lng` of a URL copied out of a browser's address bar. It missed the
-- one an administrator is most likely to produce.
--
-- Pressing Share in Google Maps gives `maps.app.goo.gl/XXXX`, which carries no
-- position at all — the coordinates are on the far side of a redirect. Follow
-- it and you land on:
--
--     https://www.google.com/maps/search/21.424128,+39.896510?entry=tts&…
--
-- which is a third shape neither pattern matched: the pair is in the PATH
-- rather than in a parameter, and there is a `+` after the comma. So a node
-- whose location was set from a share link read as a node with no location —
-- and a place with no location is dropped from `season_map` (0090) without a
-- word. The map simply had fewer pins on it than the file had places, and
-- nothing anywhere said why.
--
-- The app now resolves short links before storing and writes the canonical
-- `?q=lat,lng`, so this is the belt to that braces: it reads what is ALREADY
-- in the column, put there by every admin who pasted a Google link before
-- today.

create or replace function node_location(p_node_id uuid)
  returns table (lat double precision, lng double precision)
  language plpgsql stable security definer set search_path = public as $$
declare
  v_url text;
  v_match text[];
  -- One pair, matched three ways. `\+?` is what admits the resolved share
  -- link: Google writes "21.424128,+39.896510" and nothing else in this app
  -- ever does.
  c_pair constant text := '(-?\d{1,3}(?:\.\d+)?)\s*,\s*\+?\s*(-?\d{1,3}(?:\.\d+)?)';
begin
  select nullif(n.data ->> f.key, '')
    into v_url
    from module_nodes n
    join module_type_fields f
      on f.level_id = n.level_id
     and f.kind = 'location'
   where n.id = p_node_id
   order by f.sort_order
   limit 1;

  if v_url is null then
    return;
  end if;

  v_match := regexp_match(v_url, '[?&](?:q|query|ll|center)=' || c_pair);
  if v_match is null then
    v_match := regexp_match(v_url, '@' || c_pair);
  end if;
  if v_match is null then
    -- `/maps/search/…`, `/maps/place/…`, `/maps/dir/…` — where a resolved
    -- share link puts it.
    v_match := regexp_match(v_url, '/(?:maps/)?(?:search|place|dir)/' || c_pair);
  end if;
  if v_match is null then
    return;
  end if;

  lat := v_match[1]::double precision;
  lng := v_match[2]::double precision;
  -- A URL can carry any two numbers. Off the globe means it was not a position.
  if abs(lat) > 90 or abs(lng) > 180 then
    return;
  end if;
  return next;
end;
$$;
