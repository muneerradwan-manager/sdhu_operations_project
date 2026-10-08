-- The return is announced before it comes.
--
-- A man's flight home is very often booked two days before it leaves. That is
-- not a failure of planning — it is how a charter season works — but it means
-- the interval between "there is now a return flight" and "the return flight
-- has left without him" can be forty-eight hours, and for most of that time he
-- is at a camp gate in منى with no reason to open the app.
--
-- So the app tells him. Twice, at 48 hours and again at 24, which are the two
-- moments where being told changes what a man does: the first is when he starts
-- packing and hands over his post, the second is when he arranges how he gets
-- to the airport.
--
-- ------------------------------------------------------------ and the room
--
-- Two of the four notices below go to the operations room instead, and they are
-- about the OPPOSITE problem — not a return that is coming, but one that was
-- never booked, and a movement whose hour passed with nobody saying whether it
-- happened. Those are the two failures this feature exists to prevent, and
-- neither of them announces itself: nothing happens, and then the season ends
-- with four people still in المدينة.
--
-- Everything rides on machinery that already exists: a row in `notifications`
-- is picked up by the trigger from 0107/0108, pushed through pg_net to the
-- `send-notification` function, and arrives as FCM. Nothing new is built here.

-- ============================================================ 1. said once
--
-- Two thresholds means two rows, not one `reminded_at` column. A single
-- timestamp cannot distinguish "we sent the 48-hour warning" from "we sent
-- both", so the day after the first one it would either send the second early
-- or never send it at all.
--
-- Keyed on the LEG rather than on the trip: sixty men share a flight and are
-- told about it separately, and a man rebooked onto another flight must be told
-- again about the new one.

create table if not exists travel_reminders (
  id uuid primary key default gen_random_uuid(),
  leg_id uuid not null references journey_legs (id) on delete cascade,
  -- Hours before departure. An integer and not an enum: the set of thresholds
  -- is a policy, and widening it later should not need a type migration.
  threshold_hours int not null,
  sent_at timestamptz not null default now(),
  unique (leg_id, threshold_hours)
);

create index if not exists idx_travel_reminders_leg
  on travel_reminders (leg_id);

alter table travel_reminders enable row level security;

-- Nobody reads this from the app; it is bookkeeping for the scheduler, which
-- runs as the owner and is not subject to policy. RLS is on with no permissive
-- policy, which is the honest way to say "not for clients" — the table is
-- enumerable in the API schema either way, and an empty result is better than
-- a hole.
drop policy if exists travel_reminders_admin on travel_reminders;
create policy travel_reminders_admin on travel_reminders for select
  using (is_admin());

-- =================================================== 2. your flight is soon
--
-- Live legs only, and outbound only. A man does not need waking at 3am about
-- the flight that brought him here a month ago, and one that was cancelled or
-- rebooked is not his flight any more.

create or replace function remind_upcoming_returns() returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_threshold int;
  v_leg record;
  v_sent int := 0;
begin
  foreach v_threshold in array array[48, 24] loop
    for v_leg in
      select l.id,
             sp.profile_id,
             coalesce(t.planned_departure_at, l.planned_departure_at) as departs_at,
             t.trip_number,
             fp.name_ar as from_name
        from journey_legs l
        join season_participants sp on sp.id = l.participant_id
        left join trips t on t.id = l.trip_id
        left join reference_items fp
          on fp.id = coalesce(t.from_point_id, l.from_point_id)
       where l.role = 'outbound'
         and l.status in ('planned', 'confirmed')
         and coalesce(t.status, 'scheduled') <> 'cancelled'
         and sp.status = 'active'
         and coalesce(t.planned_departure_at, l.planned_departure_at)
               between now()
               and now() + make_interval(hours => v_threshold)
         and not exists (
           select 1 from travel_reminders r
            where r.leg_id = l.id and r.threshold_hours = v_threshold)
    loop
      insert into notifications (recipient_id, sender_id, title, body, data)
      values (
        v_leg.profile_id,
        null,
        case when v_threshold = 24
          then 'رحلة عودتك غداً'
          else 'رحلة عودتك بعد يومين'
        end,
        concat_ws(' — ',
          nullif(btrim(coalesce(v_leg.trip_number, '')), ''),
          v_leg.from_name,
          to_char(v_leg.departs_at, 'YYYY-MM-DD HH24:MI')),
        jsonb_build_object('type', 'travel_return_soon', 'leg_id', v_leg.id)
      );

      insert into travel_reminders (leg_id, threshold_hours)
      values (v_leg.id, v_threshold)
      on conflict (leg_id, threshold_hours) do nothing;

      v_sent := v_sent + 1;
    end loop;
  end loop;

  return v_sent;
end;
$$;

revoke execute on function remind_upcoming_returns() from public, anon;

-- ================================================= 3. the room's two notices
--
-- Sent to whoever holds `travel.view_all` — the people who could actually do
-- something about it — and to nobody else. A count and not a list: forty names
-- in a push notification is a wall of text that gets swiped away, and the board
-- it points at has the names on it.
--
-- The unbooked-return notice only starts once the season has an end date within
-- sight. Before that, "no return flight" is the correct and expected state of
-- every man in the mission, and reporting it daily from ذو القعدة onwards would
-- train the room to ignore this notification by the time it means something.

create or replace function report_travel_gaps() returns integer
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_season seasons;
  v_days_left int;
  v_no_return int;
  v_unconfirmed int;
  v_sent int := 0;
begin
  select * into v_season from seasons where is_current;
  if v_season.id is null then
    return 0;
  end if;

  v_days_left := case
    when v_season.end_date is null then null
    else (v_season.end_date - current_date)
  end;

  select count(*) into v_no_return
    from travel_gaps(v_season.id) g where g.kind = 'no_outbound';

  select count(*) into v_unconfirmed
    from travel_gaps(v_season.id) g where g.kind = 'unconfirmed';

  -- Three weeks out is where a charter return stops being something that will
  -- be arranged and starts being something that has not been.
  if v_no_return > 0 and v_days_left is not null and v_days_left <= 21 then
    insert into notifications (recipient_id, sender_id, title, body, data)
    select p.id, null,
           'مشاركون بلا رحلة عودة',
           v_no_return || ' مشاركاً بلا رحلة عودة، والموسم ينتهي بعد '
             || v_days_left || ' يوماً',
           jsonb_build_object('type', 'travel_gaps', 'gap', 'no_outbound')
      from profiles p
     where p.account_status = 'approved'
       and not p.is_suspended
       and (p.is_admin or has_permission_for(p.id, 'travel.view_all'));
    v_sent := v_sent + 1;
  end if;

  -- No season-end condition on this one: a movement whose hour passed with
  -- nobody saying whether it happened is wrong in ذو القعدة exactly as much as
  -- it is wrong in ذو الحجة.
  if v_unconfirmed > 0 then
    insert into notifications (recipient_id, sender_id, title, body, data)
    select p.id, null,
           'حركات تنقّل بلا تأكيد',
           v_unconfirmed || ' حركة مضى موعدها ولم يُسجَّل ما حدث فيها',
           jsonb_build_object('type', 'travel_gaps', 'gap', 'unconfirmed')
      from profiles p
     where p.account_status = 'approved'
       and not p.is_suspended
       and (p.is_admin or has_permission_for(p.id, 'travel.view_all'));
    v_sent := v_sent + 1;
  end if;

  return v_sent;
end;
$$;

revoke execute on function report_travel_gaps() from public, anon;

-- ============================================== 4. told when the plan changes
--
-- A schedule change on a flight is ONE edit and sixty people who need to know
-- about it. This is the trigger that makes that true, and it is the only place
-- in this feature where the app writes a leg's worth of notifications without
-- somebody pressing a button — because unlike an arrival, a time change is not
-- a judgement about anybody. It is a fact about the aeroplane, and it is
-- already recorded by the time this runs.
--
-- Note what it does NOT do: it does not touch a single leg's status. BR-6
-- stands. The men are told; what happens to their bookings is decided by
-- people.

create or replace function on_trip_schedule_changed() returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_title text;
  v_body text;
begin
  if new.planned_departure_at is not distinct from old.planned_departure_at
     and new.status is not distinct from old.status then
    return new;
  end if;

  if new.status = 'cancelled' and old.status <> 'cancelled' then
    v_title := 'أُلغيت رحلتك';
  elsif new.planned_departure_at is distinct from old.planned_departure_at then
    v_title := 'تغيّر موعد رحلتك';
  else
    -- `departed`, `arrived`, `delayed` without a new time. The board shows
    -- these; waking sixty phones for them is noise.
    return new;
  end if;

  v_body := concat_ws(' — ',
    nullif(btrim(coalesce(new.trip_number, '')), ''),
    to_char(new.planned_departure_at, 'YYYY-MM-DD HH24:MI'));

  insert into notifications (recipient_id, sender_id, title, body, data)
  select sp.profile_id, auth.uid(), v_title, v_body,
         jsonb_build_object('type', 'travel_trip_changed',
                            'trip_id', new.id, 'leg_id', l.id)
    from journey_legs l
    join season_participants sp on sp.id = l.participant_id
   where l.trip_id = new.id
     and l.status in ('planned', 'confirmed');

  -- A cancelled flight invalidates the reminders already sent about it: if it
  -- is rescheduled rather than replaced, the men must be told again.
  if new.planned_departure_at is distinct from old.planned_departure_at then
    delete from travel_reminders r
     using journey_legs l
     where r.leg_id = l.id and l.trip_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trips_schedule_notify on trips;
create trigger trips_schedule_notify after update on trips
  for each row execute function on_trip_schedule_changed();

-- ================================================================ 5. the clock
--
-- Two jobs at two hours, and the split is deliberate.
--
-- The returns pass runs every four hours, not nightly: a return booked at
-- 09:00 for the following morning must not wait until 20:00 to be announced —
-- by then the 24-hour warning is a 15-hour warning, which is the difference
-- between packing tonight and packing in a hurry.
--
-- The room's summary runs once, at the same 17:00 UTC (20:00 in Makkah) that
-- 0086 and 0119 chose, and for their reason: late enough that the day is over,
-- early enough that being told still leaves an evening to do something.
--
-- Same guard as 0119. If the notice below appears NOTHING IS SCHEDULED — the
-- functions exist and nobody calls them, which looks exactly like a working
-- feature until the first man misses his flight home. To finish the job:
--
--   create extension pg_cron;
--
-- then re-run this migration; every statement in it is repeatable.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'remind-upcoming-returns')
    then
      perform cron.unschedule('remind-upcoming-returns');
    end if;
    perform cron.schedule(
      'remind-upcoming-returns',
      '0 */4 * * *',
      $cron$select remind_upcoming_returns()$cron$
    );

    if exists (select 1 from cron.job where jobname = 'report-travel-gaps')
    then
      perform cron.unschedule('report-travel-gaps');
    end if;
    perform cron.schedule(
      'report-travel-gaps',
      '0 17 * * *',
      $cron$select report_travel_gaps()$cron$
    );
  else
    raise notice
      'pg_cron is not installed — return reminders and the travel gaps '
      'summary will not run. Enable the extension and re-run migration 0131.';
  end if;
end
$$;
