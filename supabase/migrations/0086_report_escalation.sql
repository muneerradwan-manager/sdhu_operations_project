-- Noticing what did NOT happen.
--
-- Everything in this app until now is a reaction to somebody doing something: a
-- file is created, a duty is moved, a complaint is filed, and a trigger or an
-- RPC answers. Nothing anywhere watches for the absence of an act. But in a
-- season that lasts days, the absence IS the emergency — a camp whose evening
-- report never came is the camp somebody has to go and look at, and under the
-- old arrangement nobody found out until the season was over and the file was
-- read back.
--
-- So: one scheduled pass a day that asks who owed a report and did not file it,
-- tells him, and — if he still has not the next day — tells the man above him.
--
-- SCOPE, deliberately narrow. Only the periodic report, and only `daily` and
-- `weekly`. A `once` file asks for a report with no date attached to it, so
-- there is no day on which it is late; inventing one would mean inventing a
-- deadline the Administration never set. Overdue DUTIES are a separate question
-- with a separate answer and are not touched here.

-- --------------------------------------------------------------- the period
--
-- Extracted from `submit_module_report` (0044) rather than copied.
--
-- This is the whole correctness of the feature. If the watcher's idea of "the
-- current period" differs from the filer's by so much as an hour, it nags a man
-- about a window he has already filed for, or stays silent about the one he has
-- not. One expression, used by both.
--
-- It resolves against the database's clock, which is UTC — the same clock
-- `submit_module_report` has always used. That is not ideal for a mission
-- operating at UTC+3, and it is deliberately NOT corrected here: correcting it
-- in one of the two places would create exactly the disagreement this function
-- exists to prevent. If it is ever fixed it must be fixed here, once, and both
-- callers follow.
-- STABLE, not IMMUTABLE. `current_date` changes between statements, and a
-- function marked immutable may have its result folded and reused — which here
-- would mean a pass that keeps asking about yesterday.
create or replace function module_report_period(p_cadence report_cadence)
  returns date
  language sql stable as $$
  select case p_cadence
    when 'daily'  then current_date
    when 'weekly' then (date_trunc('week', current_date))::date
    else null
  end;
$$;

-- ------------------------------------------------------------- the register
--
-- What is recorded is the MISS, not the reminder.
--
-- The difference matters. A table of notifications sent answers "did we tell
-- him?"; a table of misses answers "is it still not filed, and how long has
-- that been true?" — which is the question the escalation turns on. It also
-- makes the pass idempotent: running it twice in an hour, or twice after a
-- crash, cannot produce two reminders, because the second run sees a row that
-- already reached the rung it would have sent.
create table if not exists report_misses (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules (id) on delete cascade,
  -- Who owed it. Every member owes his own — see the unique index on
  -- module_reports (0044) and the wording the app uses for the cadence.
  profile_id uuid not null references profiles (id) on delete cascade,
  period_start date not null,
  -- How far up the ladder this has been carried. 0 = the man himself, 1 = the
  -- post above his, 2 = whoever holds the file. It only ever climbs.
  rung smallint not null default -1,
  first_seen_at timestamptz not null default now(),
  last_escalated_at timestamptz,
  unique (module_id, profile_id, period_start)
);

create index if not exists idx_report_misses_open
  on report_misses (module_id, period_start);

alter table report_misses enable row level security;

-- Readable by exactly whoever may already read the reports themselves, and by
-- the man it is about. Written by nobody: every row here is put there by the
-- scheduled pass below, which runs as definer.
--
-- `modules.reports` and NOT `modules.manage`. The coarse code was retired by
-- migration 0073, which split it and then DELETED its row — so
-- `has_permission('modules.manage')` is now a clause that can never be true,
-- and a policy resting on it would quietly grant nothing to the very people
-- this register is for. 0073 re-pointed `module_reports_select` at
-- `modules.reports` for this reason; this policy has to say the same thing, or
-- a manager could read a member's report and not the note saying it never came.
drop policy if exists report_misses_select on report_misses;
create policy report_misses_select on report_misses for select
  using (
    profile_id = auth.uid()
    or is_admin()
    or has_permission('modules.reports')
  );

-- ---------------------------------------------------------------- who is up
--
-- The ladder is not invented: it is already in the shape of the file. A type
-- declares its LEVELS, level 1 being the outermost, and each node names its
-- parent (0024). So the man above a tower supervisor is whoever holds a post on
-- that tower's sector, and above him is whoever holds a post on the file
-- itself. Walking that is the whole of the escalation.
--
-- Returns nobody rather than raising when the ladder runs out — a file with no
-- sectors above a man simply escalates straight to its own holders, and a file
-- whose holders are the man himself escalates to nobody, which is correct: he
-- is the top, and there is no one to tell.
-- The returned column is `target_id` rather than `profile_id` on purpose. A
-- RETURNS TABLE column becomes a variable inside the body, and one named
-- `profile_id` would make every unqualified reference to the `profile_id`
-- COLUMN of module_members ambiguous — an error at call time, not at creation
-- time, which is the worst moment to find it.
create or replace function module_report_escalation_targets(
  p_module_id uuid,
  p_profile_id uuid,
  p_rung smallint
) returns table (target_id uuid)
  language plpgsql stable security definer set search_path = public as $$
begin
  if p_rung <= 0 then
    -- The man himself.
    return query select p_profile_id;
    return;
  end if;

  if p_rung = 1 then
    -- Everyone holding a post on a node ABOVE any node he holds one on. A
    -- person may hold posts in several towers; each is climbed.
    return query
      with mine as (
        select n.id, n.parent_id
          from module_node_members nm
          join module_nodes n on n.id = nm.node_id
         where nm.profile_id = p_profile_id
           and n.module_id = p_module_id
      )
      select distinct up.profile_id
        from mine
        join module_node_members up on up.node_id = mine.parent_id
       where up.profile_id <> p_profile_id;

    -- Falls through to nothing when he holds no node post, or when his nodes
    -- are already at the top level. The next rung catches him.
    return;
  end if;

  -- Rung 2 and beyond: whoever holds the file itself.
  return query
    select distinct mm.profile_id
      from module_members mm
     where mm.module_id = p_module_id
       and mm.profile_id <> p_profile_id;
end;
$$;

-- ------------------------------------------------------------------ the pass
--
-- Run once a day. Everything it does is derived from the state of the tables at
-- the moment it runs, so a missed run costs a day's reminders and nothing else
-- — there is no cursor to fall behind and no queue to drain.
create or replace function escalate_missing_reports()
  returns integer
  language plpgsql security definer set search_path = public as $$
declare
  v_sent integer := 0;
  v_miss record;
  v_target record;
  v_title text;
  v_body text;
  v_module text;
begin
  -- 1. Clear what has since been filed.
  --
  -- First, so that a man who filed an hour ago is not escalated for a miss
  -- recorded this morning. Deleted rather than marked: the register is of what
  -- is OUTSTANDING, and a resolved miss is not a fact anybody needs kept.
  delete from report_misses rm
   where exists (
     select 1 from module_reports r
      where r.module_id = rm.module_id
        and r.author_id = rm.profile_id
        and r.period_start is not distinct from rm.period_start
   );

  -- 2. Record everyone who owes one now and has not filed.
  --
  -- Only files that are switched on and actually running: an inactive file has
  -- not been released to its members, and a file whose end date has passed is
  -- not owed anything further.
  --
  -- And only where the period is CLOSING. This is the difference between a
  -- reminder and a nuisance. A daily report is late by the evening of its own
  -- day, so the pass may speak. A weekly one is not late on Monday evening —
  -- the man has the rest of the week — and a system that told him so every
  -- night from Monday would be ignored by Wednesday and useless by the season.
  -- `date_trunc('week')` is the Monday, so the sixth day after it is the
  -- Sunday: the last evening on which filing is still possible.
  insert into report_misses (module_id, profile_id, period_start)
  select m.id, people.profile_id, module_report_period(m.report_cadence)
    from modules m
    cross join lateral (
      select mm.profile_id
        from module_members mm
       where mm.module_id = m.id
      union
      select nm.profile_id
        from module_node_members nm
        join module_nodes n on n.id = nm.node_id
       where n.module_id = m.id
    ) people
   where m.is_active
     and m.report_cadence in ('daily', 'weekly')
     and (m.starts_on is null or m.starts_on <= current_date)
     and (m.ends_on is null or m.ends_on >= current_date)
     and (
       m.report_cadence = 'daily'
       or current_date >= module_report_period(m.report_cadence) + 6
     )
     and not exists (
       select 1 from module_reports r
        where r.module_id = m.id
          and r.author_id = people.profile_id
          and r.period_start = module_report_period(m.report_cadence)
     )
  on conflict (module_id, profile_id, period_start) do nothing;

  -- 3. Carry each outstanding miss one rung further.
  --
  -- One rung per pass, and the pass runs daily — so "the day after" is what
  -- the interval between runs means, not a duration measured in the row. That
  -- keeps the rule legible: a man is told today, his supervisor tomorrow, the
  -- file's holders the day after.
  for v_miss in
    select rm.*,
           mt.name_ar as type_name,
           -- Same three parts, in the same order, as the app's own `fullName`.
           nullif(
             concat_ws(' ', p.first_name, p.father_name, p.surname), ''
           ) as owed_by
      from report_misses rm
      join modules m on m.id = rm.module_id
      join module_types mt on mt.id = m.module_type_id
      join profiles p on p.id = rm.profile_id
     where rm.rung < 2
       -- Twenty hours rather than twenty-four: the pass is scheduled daily, and
       -- a run that starts a few minutes late must not push the whole ladder
       -- back a day for want of four minutes.
       and (rm.last_escalated_at is null
            or rm.last_escalated_at < now() - interval '20 hours')
  loop
    v_module := coalesce(v_miss.type_name, '');

    if v_miss.rung < 0 then
      v_title := 'تقرير لم يُرفع';
      v_body := 'لم يصل تقريرك عن ' || v_module || ' لهذه الفترة.';
    else
      -- Named. A supervisor told that "somebody" is late has been given a
      -- worry rather than a thing to do, and the point of carrying it up the
      -- ladder is that the man above can go and ask.
      v_title := 'تقرير متأخر في ' || v_module;
      v_body := coalesce(v_miss.owed_by, 'أحد الأعضاء')
        || ' لم يرفع تقريره، وقد مضى على ذلك يوم.';
    end if;

    for v_target in
      select * from module_report_escalation_targets(
        v_miss.module_id, v_miss.profile_id, (v_miss.rung + 1)::smallint
      )
    loop
      insert into notifications (recipient_id, sender_id, title, body, data)
      values (
        v_target.target_id,
        -- No sender. This is the system noticing, not a person complaining,
        -- and putting somebody's name on it would make it one.
        null,
        v_title,
        v_body,
        jsonb_build_object(
          'type', 'report_overdue',
          'module_id', v_miss.module_id,
          'period_start', v_miss.period_start,
          'about_profile_id', v_miss.profile_id
        )
      );
      v_sent := v_sent + 1;
    end loop;

    -- Advanced whether or not anybody was found at that rung: a file with no
    -- sector above a man must not sit forever on rung 1 re-finding nobody.
    update report_misses
       set rung = v_miss.rung + 1, last_escalated_at = now()
     where id = v_miss.id;
  end loop;

  return v_sent;
end;
$$;

-- Executable by nobody the app can sign in as.
--
-- Not merely tidiness: this function writes notifications to other people's
-- inboxes and advances a register. Left callable by `authenticated`, any
-- account could run it in a loop and empty the escalation ladder into the
-- leadership's notifications in a few seconds. The scheduler runs it as the
-- database owner, and an administrator setting it up runs it from the SQL
-- editor, which is the same thing.
revoke execute on function escalate_missing_reports()
  from public, anon, authenticated;

-- ---------------------------------------------------------------- the clock
--
-- 17:00 UTC is 20:00 in Makkah: the end of the working day, late enough that a
-- report not filed by then is genuinely late, and early enough that being told
-- still leaves the evening to do something about it.
--
-- Wrapped in a guard because `pg_cron` is an extension that has to be enabled
-- on the project first, and a migration that dies on a database without it
-- would block every migration after it.
--
-- If the notice below appears, NOTHING IS SCHEDULED — the table and the
-- functions exist and no one is calling them, which looks exactly like a
-- working feature until the first report goes unnoticed. To finish the job:
--
--   create extension pg_cron;
--
-- Plainly, with no `with schema`: pg_cron's control file fixes its schema to
-- `cron` and is not relocatable, so naming any other one is an error rather
-- than a preference. On Supabase it can also be switched on from
-- Database → Extensions, which is the same thing through a button.
--
-- Then re-run this migration. Every statement in it is written to be repeatable.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- Unscheduled first so the migration can be re-run: `cron.schedule` on an
    -- existing name replaces it on newer pg_cron and errors on older, and this
    -- file should not care which is installed.
    if exists (select 1 from cron.job where jobname = 'escalate-missing-reports')
    then
      perform cron.unschedule('escalate-missing-reports');
    end if;
    perform cron.schedule(
      'escalate-missing-reports',
      '0 17 * * *',
      $cron$select escalate_missing_reports()$cron$
    );
  else
    raise notice
      'pg_cron is not installed — report escalation will not run. Enable the '
      'extension and re-run migration 0086.';
  end if;
end
$$;
