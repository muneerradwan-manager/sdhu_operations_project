-- The question the presence board cannot be asked.
--
-- 0098 gave the operations room `presence_board`: the latest check-in for each
-- person at each place. It answers "where is he" well, and it is the wrong
-- half of the question the room actually spends its five days on.
--
-- A board of arrivals is read by looking for a name and not finding it. That
-- works with eleven names. With four hundred it is not a search, it is a
-- census — and the one fact worth acting on is precisely the one nothing on
-- that screen draws: the post that is manned on paper and empty in the world.
-- Nobody notices an absence by scanning a list of presences.
--
-- This system already knows how to watch for what did NOT happen. 0086 built it
-- for the reports — a daily pass that finds who owed one and did not file it,
-- tells him, and tells whoever is above him the next day. Its own header calls
-- it "the first thing in this system that watches for what did not happen". The
-- machinery was right and it was pointed at one thing. This points the same
-- idea at attendance.
--
-- ------------------------------------------------------------- what "should"
--
-- Expected presence comes from the POSTINGS, and only from them: whoever holds
-- a role on a node whose level draws its name from a place — a hotel, a camp —
-- is expected at that place. Not "everybody in the season", which would put the
-- Administration's office staff on a list of people missing from Mina.
--
-- Note the asymmetry, because it is deliberate and it is 0098's: the posting
-- decides who is EXPECTED, and it does not decide who MAY check in. 0098 struck
-- membership out as a gate — "standing at it with the code in front of you is
-- the credential". A man covering for a colleague checks in and appears on the
-- board; he simply is not what this report is looking for. The report asks
-- after empty posts, not after strangers.
--
-- --------------------------------------------------------------- what "not"
--
-- A window, defaulting to twelve hours, and the same figure `presence_board`
-- defaults to — the two screens must not disagree about what "recently" means.
--
-- The absence of a row and a row that is too old are one answer here, both
-- meaning "nobody has confirmed this post is manned". They are still told
-- apart in the output: `last_seen` is null for the first and carries a time for
-- the second, and the room treats them differently. A man who checked in at
-- dawn and is now nine hours quiet is a telephone call; a man who has never
-- checked in at all may have never been given the code.
--
-- ------------------------------------------------------------ the telephones
--
-- Both numbers are in the result, and that is the point of the screen rather
-- than a convenience. Every row here is a name somebody is about to ring. A
-- report that produced a list of names and made the reader go and look each one
-- up in the directory would be adding a step to the only action it exists to
-- provoke.

create or replace function presence_gaps(
  p_within   interval default interval '12 hours',
  p_item_id  uuid default null,
  p_season_id uuid default null
)
  returns table (
    profile_id  uuid,
    full_name   text,
    phone_sy    text,
    phone_sa    text,
    item_id     uuid,
    place_name  text,
    set_code    text,
    module_id   uuid,
    module_name text,
    node_label  text,
    role_name   text,
    last_seen   timestamptz
  )
  language sql stable security definer set search_path = public as $$
  -- The guard, restated by hand: `security definer` does not inherit the
  -- policies on the tables below, and without this the function would hand the
  -- mission's postings and telephone numbers to anybody who called it.
  --
  -- Only `checkin.board` — no "your own gaps" branch of the kind
  -- `presence_board` has. A man does not need a report to tell him he has not
  -- checked in; this is a room's screen, and its rows are other people.
  select p.id,
         concat_ws(' ', p.first_name, p.father_name, p.surname),
         p.phone_sy,
         p.phone_sa,
         ri.id,
         ri.name_ar,
         rs.code,
         m.id,
         -- The TYPE's name, and there is nothing else it could be: a file has
         -- no name of its own. 0024 dropped `modules.title` when it settled the
         -- rule that there is one file of a kind per season — so the kind IS
         -- the identity, and `raise_incident` names a file the same way.
         mt.name_ar,
         coalesce(n.label, ri.name_ar),
         r.name_ar,
         seen.created_at
    from module_node_members nm
    join module_nodes n on n.id = nm.node_id
    join modules m on m.id = n.module_id
    left join module_types mt on mt.id = m.module_type_id
    join module_type_roles r on r.id = nm.role_id
    join profiles p on p.id = nm.profile_id
    -- The node must STAND FOR a place. A sector is a node too and nobody checks
    -- in to a sector; `is_place` (0098) is what says which lists are things in
    -- the world, and it is read rather than a list of codes written here — so
    -- a seventh kind of place arrives without touching this function.
    join reference_items ri on ri.id = n.reference_item_id
    join reference_sets rs on rs.id = ri.set_id and rs.is_place
    -- His latest check-in AT THAT PLACE, if there is one. Lateral rather than a
    -- grouped join: one row per posting is the shape wanted, and a person
    -- posted to two places must be judged separately at each.
    left join lateral (
      select c.created_at
        from place_check_ins c
       where c.profile_id = nm.profile_id
         and c.item_id = ri.id
       order by c.created_at desc
       limit 1
    ) seen on true
   where m.is_active
     and (p_item_id is null or ri.id = p_item_id)
     and (p_season_id is null or m.season_id = p_season_id)
     -- A suspended or unapproved account is not an empty post; it is an account
     -- that should not be posted at all, and it belongs on a different screen.
     and p.account_status = 'approved'
     and not p.is_suspended
     -- The whole condition, and the reason both halves are one clause: never
     -- seen and seen too long ago are the same answer to "is this post manned".
     and (seen.created_at is null or seen.created_at < now() - p_within)
     and (is_admin() or has_permission('checkin.board'))
   -- Never-seen first, then longest-quiet. The top of this list is where the
   -- room starts telephoning, so it has to be ordered by how worrying a row is
   -- rather than by place or by name.
   order by seen.created_at asc nulls first,
            ri.name_ar,
            concat_ws(' ', p.first_name, p.father_name, p.surname);
$$;

revoke execute on function presence_gaps(interval, uuid, uuid) from public, anon;
grant execute on function presence_gaps(interval, uuid, uuid) to authenticated;

-- ------------------------------------------------------------------- indexes
--
-- The lateral runs once per posting, so it is the one thing here that scales
-- with the size of the mission. This is the index it wants, and it is the same
-- shape the board's own `distinct on` reads.
create index if not exists idx_place_check_ins_profile_item
  on place_check_ins (profile_id, item_id, created_at desc);

-- ----------------------------------------------------------------- no grant
--
-- No new permission code. `checkin.board` already means "may see who is where",
-- and who is NOT where is the same fact read from the other side — a second
-- code would let an administrator grant one and withhold the other, which is a
-- distinction with nothing behind it.
