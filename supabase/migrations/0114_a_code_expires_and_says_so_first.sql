-- A code that is never rotated, and a rotation nobody was ready for.
--
-- 0098 gave every place a secret and one way to change it: a person presses
-- تجديد الرمز and every printed copy dies that instant. That is right for the
-- emergency — somebody photographed the sticker — and it is the only thing
-- there is, which leaves the ordinary case unserved: a season's codes, printed
-- once, are still the same codes months later, and nobody is reminded.
--
-- So codes expire on a schedule now. The interval is a POLICY rather than a
-- constant, and it is deliberately long.
--
-- ------------------------------------------------------- why not every day
--
-- Daily rotation was asked for and is the one shape this cannot take. The code
-- is a STICKER ON A WALL: rotating it does not update anything, it kills forty
-- pieces of paper across مكة and منى, and until somebody has reprinted them and
-- walked out to stick them up, NOBODY CAN CHECK IN ANYWHERE. A daily rotation
-- is a daily morning of that, and the morning it is not done is a day with no
-- register at all.
--
-- What it would buy is small, besides. A photographed code does not admit
-- anybody from anywhere: since 0098 the server refuses a check-in taken outside
-- the place's radius, so whoever holds the photograph still has to be standing
-- at the gate — where he could have scanned the wall. The secret guards against
-- a code REUSED at distance, and the coordinates already refuse that.
--
-- -------------------------------------------------------- so: warn, then rotate
--
-- Two things run daily; neither of them is a daily rotation:
--
--   1. a warning, `warn_before_days` before a code comes due, to everyone who
--      may rotate — so the reprint is done BEFORE the paper on the wall dies;
--   2. the rotation itself, once the code is `rotate_every_days` old, followed
--      by a second message saying the posters are now dead and must be replaced.
--
-- The warning is what makes this usable. A rotation nobody expected is
-- indistinguishable from an outage.

-- ================================================================ 1. the policy

create table if not exists place_code_policy (
  -- One row, forever. The `check` is what makes that true rather than hoped.
  id                boolean primary key default true check (id),

  -- Long by default: an operational season runs a few weeks, so thirty days is
  -- about one rotation per season — the code is refreshed between contracts
  -- without anybody reprinting mid-Hajj. Raise or lower it with one UPDATE.
  rotate_every_days integer not null default 30
    check (rotate_every_days between 7 and 365),

  -- How much notice. Three days is a working span in which somebody can print
  -- a stack and get it onto the gates.
  warn_before_days  integer not null default 3
    check (warn_before_days between 0 and 30),

  -- The whole schedule off, without dropping the policy or the job. What is
  -- left is 0098 exactly: rotation by hand, when a person decides.
  is_enabled        boolean not null default true,

  updated_at        timestamptz not null default now()
);

insert into place_code_policy (id) values (true) on conflict (id) do nothing;

alter table place_code_policy enable row level security;

-- Whoever may read a code may read when it dies. The date is on the poster's
-- card in the app, and it is not a secret — it is the thing that stops a
-- rotation from being a surprise.
drop policy if exists place_code_policy_select on place_code_policy;
create policy place_code_policy_select on place_code_policy for select
  using (is_admin() or has_permission('checkin.codes'));

-- Changing how long every sticker in the season lives is an administrative act
-- and belongs to an administrator.
drop policy if exists place_code_policy_update on place_code_policy;
create policy place_code_policy_update on place_code_policy for update
  using (is_admin()) with check (is_admin());

-- No insert and no delete policy: the single row is made here and stays.

-- 0077 audits the tables that existed when it ran; this one did not.
drop trigger if exists audit_row on place_code_policy;
create trigger audit_row after insert or update or delete on place_code_policy
  for each row execute function audit_row_change();

-- --------------------------------------------------------------- the warning mark
--
-- Set when a code's warning has gone out, cleared by the rotation itself. So
-- the warning is sent once per cycle rather than once per day for three days —
-- three identical notifications teach a room to stop reading them.

alter table place_codes
  add column if not exists warned_at timestamptz;

comment on column place_codes.warned_at is
  'When the "this code is about to expire" notice went out for the CURRENT '
  'cycle. Cleared on rotation, so each cycle warns once.';

-- ============================================================= 2. when it is due

create or replace function place_code_due_at(p_rotated_at timestamptz)
  returns timestamptz
  language sql stable security definer set search_path = public as $$
  select case
    when not p.is_enabled then null
    else p_rotated_at + make_interval(days => p.rotate_every_days)
  end
  from place_code_policy p
  where p.id;
$$;

comment on function place_code_due_at(timestamptz) is
  'When a code last rotated at the given time comes due. Null while the '
  'schedule is switched off, which is what the poster card reads as "no '
  'automatic rotation".';

revoke execute on function place_code_due_at(timestamptz) from public, anon;

-- The poster's own query answers it too, so the card needs no second round
-- trip. The signature changes, and a function''s OUT columns cannot be altered
-- by CREATE OR REPLACE — it has to go first.
drop function if exists place_code(uuid);

create function place_code(p_item_id uuid)
  returns table (
    item_id     uuid,
    place_name  text,
    set_name_ar text,
    secret      text,
    lat         double precision,
    lng         double precision,
    radius_m    double precision,
    rotated_at  timestamptz,
    due_at      timestamptz
  )
  language plpgsql stable security definer set search_path = public as $$
begin
  -- Restated by hand: a `security definer` function does not inherit the RLS on
  -- place_codes, so without this line the policy guards nothing.
  if not (is_admin() or has_permission('checkin.codes')) then
    raise exception 'check_in_codes_denied' using errcode = 'check_violation';
  end if;

  return query
  select ri.id, ri.name_ar, rs.name_ar, pc.secret,
         loc.lat, loc.lng, place_radius_m(ri.id), pc.rotated_at,
         place_code_due_at(pc.rotated_at)
    from reference_items ri
    join reference_sets rs on rs.id = ri.set_id and rs.is_place
    join place_codes pc on pc.item_id = ri.id
    left join lateral place_location(ri.id) loc on true
   where ri.id = p_item_id;
end;
$$;

comment on function place_code(uuid) is
  'Everything a poster needs, in one round trip, and the day it stops working. '
  'The coordinates come from place_location so a poster can never be built '
  'against a pin the server does not agree with.';

-- Stated rather than inherited. 0098 created this with CREATE OR REPLACE and
-- lived on the schema's default privileges; a DROP and CREATE does not keep
-- what the old function was granted, and a poster card that cannot call this
-- is the whole feature dark. The function guards itself on `checkin.codes`
-- either way — see its first statement.
grant execute on function place_code(uuid) to authenticated;

-- ========================================================== 3. who gets told

create or replace function place_code_notice_targets()
  returns table (profile_id uuid)
  language sql stable security definer set search_path = public as $$
  -- Whoever may rotate is whoever has to reprint. Admins included, and the
  -- same two conditions 0088 was careful about: a message to a suspended or
  -- unapproved account is a message counted as delivered to nobody.
  select pr.id
    from profiles pr
   where not pr.is_suspended
     and pr.account_status = 'approved'
     and (
       pr.is_admin
       or exists (
         select 1
           from user_permissions up
           join permissions perm on perm.id = up.permission_id
          where up.user_id = pr.id
            and perm.code = 'checkin.rotate'
       )
     );
$$;

-- Enumerating who holds a permission is not something a client asks for.
revoke execute on function place_code_notice_targets()
  from public, anon, authenticated;

-- ====================================================== 4. the daily maintenance
--
-- One function, run once a day. It warns about what is nearly due and rotates
-- what is over, in that order, and it says how many of each so the caller — and
-- the cron log — can see it did something.
--
-- Both messages are ONE notification per person carrying a COUNT, not one per
-- place. The work they provoke is a batch print of a whole list, which the app
-- already has a button for; forty separate notifications would be forty rows to
-- dismiss before finding the one action.

create or replace function run_place_code_rotation()
  returns table (warned integer, rotated integer)
  language plpgsql security definer set search_path = public as $$
declare
  v_policy   place_code_policy%rowtype;
  v_warned   integer := 0;
  v_rotated  integer := 0;
  v_due_on   date;
  v_target   record;
begin
  select * into v_policy from place_code_policy where id;
  if not found or not v_policy.is_enabled then
    return query select 0, 0;
    return;
  end if;

  -- ------------------------------------------------------------------ warn
  --
  -- Codes coming due inside the notice window that have not been warned since
  -- they last rotated. `warned_at > rotated_at` is the test rather than
  -- `warned_at is not null`, so a code rotated by hand yesterday starts a fresh
  -- cycle and will be warned again when its own time comes.
  with due_soon as (
    select pc.item_id,
           pc.rotated_at + make_interval(days => v_policy.rotate_every_days)
             as due_at
      from place_codes pc
     where (pc.warned_at is null or pc.warned_at <= pc.rotated_at)
  ), marked as (
    update place_codes pc
       set warned_at = now()
      from due_soon d
     where d.item_id = pc.item_id
       and d.due_at <= now() + make_interval(days => v_policy.warn_before_days)
       -- Not the ones already over: those are rotated below, and telling
       -- somebody a thing is "about to" happen in the same run that makes it
       -- happen is two messages that contradict each other.
       and d.due_at > now()
    returning pc.item_id, d.due_at
  )
  select count(*)::integer, min(m.due_at)::date into v_warned, v_due_on
    from marked m;

  if v_warned > 0 then
    for v_target in select * from place_code_notice_targets() loop
      insert into notifications (recipient_id, sender_id, title, body, data)
      values (
        v_target.profile_id,
        -- No sender. This is the calendar, not a person.
        null,
        'رموز أماكن على وشك الانتهاء',
        v_warned::text || ' من رموز الأماكن ستتجدّد تلقائياً بدءاً من '
          || to_char(v_due_on, 'YYYY-MM-DD')
          || '. اطبع البديل وألصقه قبل ذلك اليوم، وإلا تعذّر تسجيل الوصول.',
        jsonb_build_object(
          'type', 'place_codes_expiring',
          'count', v_warned,
          'due_on', v_due_on
        )
      );
    end loop;
  end if;

  -- ---------------------------------------------------------------- rotate
  --
  -- The same statement rotate_place_code() runs, minus the permission check —
  -- there is no caller to check — and with `rotated_by` left null, because
  -- nobody did this. `warned_at` is not cleared: it is compared against
  -- `rotated_at`, and moving that forward is what starts the next cycle.
  with over_due as (
    update place_codes pc
       set secret = substr(replace(gen_random_uuid()::text, '-', ''), 1, 16),
           rotated_at = now(),
           rotated_by = null
     where pc.rotated_at
             + make_interval(days => v_policy.rotate_every_days) <= now()
    returning pc.item_id
  )
  select count(*)::integer into v_rotated from over_due;

  if v_rotated > 0 then
    for v_target in select * from place_code_notice_targets() loop
      insert into notifications (recipient_id, sender_id, title, body, data)
      values (
        v_target.profile_id,
        null,
        'تجدّدت رموز أماكن',
        'تجدّد ' || v_rotated::text
          || ' من رموز الأماكن تلقائياً. كل ملصق مطبوع لها توقّف عن العمل — '
          || 'أعد الطباعة والإلصاق الآن.',
        jsonb_build_object('type', 'place_codes_rotated', 'count', v_rotated)
      );
    end loop;
  end if;

  return query select v_warned, v_rotated;
end;
$$;

comment on function run_place_code_rotation() is
  'The daily pass: warns about codes coming due, then rotates the ones that '
  'are over. Returns how many of each. Idempotent within a day — a code warned '
  'this cycle is not warned again, and a rotated code restarts its cycle.';

-- Nobody calls this from a client. It rotates secrets and writes notifications
-- to other people, which is the shape of thing 0107 revoked for the same
-- reason.
revoke execute on function run_place_code_rotation() from public, anon, authenticated;

-- =============================================================== 5. the schedule

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (
      select 1 from cron.job where jobname = 'rotate-place-codes'
    ) then
      perform cron.unschedule('rotate-place-codes');
    end if;
    -- 02:40, once a day. The hour is quiet and the minute is nobody else's —
    -- 0109 prunes at 03:20 and the notification batch runs on its own trigger.
    perform cron.schedule(
      'rotate-place-codes',
      '40 2 * * *',
      $cron$select run_place_code_rotation()$cron$
    );
  else
    raise notice
      'pg_cron is not installed — place codes will never rotate on their own. '
      'Enable the extension and re-run migration 0114.';
  end if;
end
$$;

-- ================================================================ 6. first run
--
-- Not run here, and the reason is the whole of this file: every code in the
-- database was last rotated when it was seeded, which for season 1447 is
-- months ago. A first pass inside this migration would find all of them over
-- due and rotate the lot — killing every poster already on a wall, at whatever
-- hour the deploy happened, with the warning that is supposed to precede it
-- arriving never.
--
-- Instead the clock starts now, for every code, so the first automatic rotation
-- is a full interval away and the warning goes out three days before it.
update place_codes set rotated_at = now(), warned_at = null;
