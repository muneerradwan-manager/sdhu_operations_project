-- المهمة تُخبر عن نفسها: تنتقل، وتُشعِر، وتقول متى تأخّرت.
--
-- 0105 sent one notification in the life of a task — «أُسندت إليك مهمة» — and
-- then went silent. Everything that happens afterwards is the part the two
-- people actually need told: the assignee said he finished, the assigner sent
-- it back, the man is stuck, the deadline was yesterday. All of it was visible
-- only to whoever thought to open the screen and look.
--
-- And 0117 made that worse before it made it better, because `submitted` only
-- means anything if somebody is told about it. A claim nobody hears is the old
-- «منجزة» with an extra step.
--
-- So, three things:
--
--   notice     one trigger over the events table 0117 writes. Every state
--              change already lands there; the party who is NOT the actor gets
--              told. No second list of call sites to keep in step.
--
--   reassign   moving work from one man to another without deleting it. What
--              was done stays done; what was claimed is unclaimed, because the
--              new carrier has claimed nothing.
--
--   lateness   a daily pass on 0086's pattern — same shape, same clock, same
--              guard around pg_cron. Only assigned work: a man's own reminder
--              being late is between him and himself.

-- ============================================================ 1. being told

-- Who to tell about a change, given who made it. The other side of the
-- exchange, always — and never the actor, who does not need to be informed of
-- his own decision.
create or replace function on_personal_task_event() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  t          personal_tasks;
  v_assigned boolean;
  v_to       uuid;
  v_title    text;
  v_body     text;
  v_actor    text;
begin
  if new.kind <> 'state' then
    return new;
  end if;

  select * into t from personal_tasks where id = new.task_id;
  if not found then return new; end if;

  v_assigned := t.created_by <> t.profile_id;
  -- A man's own notebook notifies nobody, exactly as 0105 had it.
  if not v_assigned then return new; end if;

  v_actor := coalesce(audit_actor_name(new.actor_id), 'أحدهم');

  -- The recipient is whichever party did not act.
  v_to := case when new.actor_id = t.profile_id then t.created_by
               else t.profile_id end;

  case new.to_state
    when 'submitted' then
      v_title := 'مهمة بانتظار قبولك';
      v_body  := v_actor || ' يقول إنه أنجز: ' || t.title;
    when 'done' then
      v_title := 'قُبلت مهمتك';
      v_body  := t.title;
    when 'returned' then
      v_title := 'أُعيدت إليك مهمة';
      v_body  := coalesce(
        (select c.body from personal_task_comments c
          where c.id = (new.payload ->> 'comment_id')::uuid),
        t.title);
    when 'blocked' then
      v_title := 'تعثّرت مهمة';
      v_body  := v_actor || ': ' || coalesce(
        (select c.body from personal_task_comments c
          where c.id = (new.payload ->> 'comment_id')::uuid),
        t.title);
    when 'cancelled' then
      v_title := 'أُلغيت مهمة';
      v_body  := t.title;
    else
      -- Picking work up, or putting it back down, is not news to anybody.
      return new;
  end case;

  insert into notifications (recipient_id, sender_id, title, body, data)
  values (v_to, new.actor_id, v_title, v_body,
          jsonb_build_object('type', 'personal_task_' || new.to_state,
                             'task_id', t.id));
  return new;
end;
$$;

drop trigger if exists personal_task_events_notify on personal_task_events;
create trigger personal_task_events_notify after insert on personal_task_events
  for each row execute function on_personal_task_event();

-- Somebody said something about a task without moving it. The other party is
-- told, because a question asked into a screen nobody reopens is not asked.
create or replace function on_personal_task_comment() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  t     personal_tasks;
  v_to  uuid;
begin
  -- Transition comments are announced by the event that carries them; this
  -- would make every return and every block arrive twice.
  if new.is_transition then return new; end if;

  select * into t from personal_tasks where id = new.task_id;
  if not found or t.created_by = t.profile_id then return new; end if;

  v_to := case when new.author_id = t.profile_id then t.created_by
               else t.profile_id end;
  if v_to = new.author_id then return new; end if;

  insert into notifications (recipient_id, sender_id, title, body, data)
  values (v_to, new.author_id,
          'تعليق على مهمة',
          coalesce(audit_actor_name(new.author_id), 'أحدهم') || ': ' || new.body,
          jsonb_build_object('type', 'personal_task_commented',
                             'task_id', t.id));
  return new;
end;
$$;

drop trigger if exists personal_task_comments_notify on personal_task_comments;
create trigger personal_task_comments_notify after insert on personal_task_comments
  for each row execute function on_personal_task_comment();

-- ========================================================== 2. moving it over

-- The man was moved to another sector, or was never the right one. Under 0105
-- the only way to do this was delete and rewrite, which threw away the thread,
-- the evidence and the fact that anybody had ever worked on it.
--
-- The state goes back to لم تبدأ and the claim stamps are cleared, because they
-- belong to the person who made them and he is no longer carrying this. What
-- was SAID stays: the new carrier reading why his predecessor was stuck is the
-- most useful thing on the screen.
create or replace function reassign_personal_task(
  p_task_id    uuid,
  p_profile_id uuid
) returns void
  language plpgsql security definer set search_path = public as $$
declare
  t     personal_tasks;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;
  if not can_edit_personal_task(p_task_id) then
    raise exception 'not allowed to reassign this task';
  end if;

  select * into t from personal_tasks where id = p_task_id for update;
  if not found then
    raise exception 'task_not_found';
  end if;
  if t.profile_id = p_profile_id then
    return;
  end if;
  if not exists (select 1 from profiles p where p.id = p_profile_id) then
    raise exception 'task_assignee_not_found';
  end if;

  -- Handing work to oneself would turn an assignment into a private note and
  -- drop it out of every follow-up screen — the same trap 0106 kept the picker
  -- away from.
  if p_profile_id = t.created_by then
    raise exception 'task_cannot_reassign_to_author';
  end if;

  update personal_tasks
     set profile_id   = p_profile_id,
         state        = 'not_started',
         started_at   = null,
         submitted_at = null,
         completed_at = null,
         accepted_by  = null,
         escalated_at = null,
         updated_at   = now(),
         updated_by   = v_uid
   where id = p_task_id;

  insert into personal_task_events
    (task_id, actor_id, kind, from_state, to_state, payload)
  values (p_task_id, v_uid, 'reassigned', t.state, 'not_started',
          jsonb_build_object('from', t.profile_id, 'to', p_profile_id));

  -- Both of them, and for opposite reasons: one has stopped carrying something
  -- he may have half done, the other has started.
  insert into notifications (recipient_id, sender_id, title, body, data)
  values
    (p_profile_id, v_uid, 'أُسندت إليك مهمة', t.title,
     jsonb_build_object('type', 'personal_task_assigned', 'task_id', t.id)),
    (t.profile_id, v_uid, 'نُقلت مهمة عنك', t.title,
     jsonb_build_object('type', 'personal_task_reassigned', 'task_id', t.id));
end;
$$;

revoke execute on function reassign_personal_task(uuid, uuid) from public, anon;
grant  execute on function reassign_personal_task(uuid, uuid) to authenticated;

-- ============================================================= 3. being late

-- One pass a day, deriving everything from the state of the table at the moment
-- it runs — 0086's rule, and for 0086's reason: a missed run costs a day of
-- reminders and nothing else.
--
-- Two rungs and no more. The first is the person who asked for the work, the
-- second is whoever administers the mission, and there is no third because the
-- personal task system has no hierarchy to climb — that is precisely what makes
-- it not the operational files.

-- Which rung a task has already reached. `escalated_at` alone cannot answer it:
-- it says a thing was reported, not how far up.
alter table personal_tasks
  add column if not exists escalation_rung smallint not null default 0;

-- Whether a profile is an administrator, asked about somebody other than the
-- caller. `is_admin()` answers only about auth.uid(), which the pass below does
-- not have — it runs on a clock, for nobody. Same three conditions, because an
-- administrator who is suspended is not one.
create or replace function is_admin_profile(p_profile_id uuid)
  returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p
     where p.id = p_profile_id
       and p.is_admin
       and not p.is_suspended
       and p.account_status = 'approved'
  );
$$;

-- The climb starts over whenever the facts under it change: the work was
-- finished or withdrawn, the deadline moved, or somebody else is carrying it
-- now. Written as a trigger rather than added to the four functions that cause
-- those things, so that a fifth one added later cannot forget.
create or replace function reset_personal_task_escalation() returns trigger
  language plpgsql set search_path = public as $$
begin
  if new.state in ('done', 'cancelled')
     or new.due_on is distinct from old.due_on
     or new.profile_id is distinct from old.profile_id then
    new.escalated_at    := null;
    new.escalation_rung := 0;
  end if;
  return new;
end;
$$;

drop trigger if exists personal_tasks_reset_escalation on personal_tasks;
create trigger personal_tasks_reset_escalation before update on personal_tasks
  for each row execute function reset_personal_task_escalation();

create or replace function escalate_late_tasks()
  returns integer
  language plpgsql security definer set search_path = public as $$
declare
  v_sent  integer := 0;
  v_task  record;
  v_admin record;
  v_today date := (now() at time zone 'Asia/Riyadh')::date;
begin
  for v_task in
    select t.*, audit_actor_name(t.profile_id) as owner_name,
           v_today - t.due_on as days_late
      from personal_tasks t
     where t.created_by <> t.profile_id            -- assigned work only
       and t.due_on is not null
       and t.due_on < v_today
       and t.state not in ('done', 'cancelled')
       -- Once per rung, and never a third time: a task reported yesterday is
       -- not news today, and a nightly repeat is how a channel gets muted.
       and (
         (t.escalation_rung = 0)
         or (t.escalation_rung = 1 and v_today - t.due_on >= 3)
       )
  loop
    if v_task.escalation_rung = 0 then
      -- Rung one: the person who asked. Named, because a supervisor told that
      -- "a task" is late has been given a worry rather than a thing to do.
      insert into notifications (recipient_id, sender_id, title, body, data)
      values (
        v_task.created_by,
        null,   -- the system noticing, not a person complaining
        'مهمة متأخرة',
        coalesce(v_task.owner_name, 'أحد المكلَّفين') || ' — ' || v_task.title
          || ' (تأخّرت ' || v_task.days_late || ' يوم)',
        jsonb_build_object('type', 'personal_task_overdue',
                           'task_id', v_task.id,
                           'about_profile_id', v_task.profile_id));
      v_sent := v_sent + 1;

      -- And the carrier himself, once, on the first day. Not a reprimand — the
      -- commonest reason a task is late is that it was forgotten.
      insert into notifications (recipient_id, sender_id, title, body, data)
      values (v_task.profile_id, null, 'مهمة تأخّرت', v_task.title,
              jsonb_build_object('type', 'personal_task_overdue',
                                 'task_id', v_task.id));
      v_sent := v_sent + 1;
    else
      -- Rung two, on the third day: the administration.
      for v_admin in
        select p.id from profiles p where is_admin_profile(p.id)
      loop
        insert into notifications (recipient_id, sender_id, title, body, data)
        values (
          v_admin.id, null,
          'مهمة متأخرة ثلاثة أيام',
          coalesce(v_task.owner_name, 'أحد المكلَّفين') || ' — ' || v_task.title,
          jsonb_build_object('type', 'personal_task_overdue',
                             'task_id', v_task.id,
                             'about_profile_id', v_task.profile_id));
        v_sent := v_sent + 1;
      end loop;
    end if;

    update personal_tasks
       set escalated_at = now(), escalation_rung = v_task.escalation_rung + 1
     where id = v_task.id;
  end loop;

  -- Tomorrow's work, said tonight. Separate from lateness and deliberately
  -- quieter: one line, to the carrier, and to nobody else.
  for v_task in
    select t.* from personal_tasks t
     where t.due_on = v_today + 1
       and t.state not in ('done', 'cancelled')
       and not exists (
         select 1 from notifications n
          where n.recipient_id = t.profile_id
            and n.data ->> 'type' = 'personal_task_due_soon'
            and n.data ->> 'task_id' = t.id::text
            and n.created_at > now() - interval '20 hours')
  loop
    insert into notifications (recipient_id, sender_id, title, body, data)
    values (v_task.profile_id, null, 'مهمة تستحق غداً', v_task.title,
            jsonb_build_object('type', 'personal_task_due_soon',
                               'task_id', v_task.id));
    v_sent := v_sent + 1;
  end loop;

  return v_sent;
end;
$$;

revoke execute on function escalate_late_tasks() from public, anon;

-- ---------------------------------------------------------------- the clock
--
-- 17:00 UTC — 20:00 in Makkah, the same hour 0086 chose and for the same
-- reason: late enough that the day is over, early enough that being told still
-- leaves an evening to do something.
--
-- Same guard, too. If the notice below appears NOTHING IS SCHEDULED: the
-- function exists and nobody calls it, which looks exactly like a working
-- feature until the first task goes quietly late. To finish the job:
--
--   create extension pg_cron;
--
-- then re-run this migration; every statement in it is repeatable.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'escalate-late-tasks')
    then
      perform cron.unschedule('escalate-late-tasks');
    end if;
    perform cron.schedule(
      'escalate-late-tasks',
      '0 17 * * *',
      $cron$select escalate_late_tasks()$cron$
    );
  else
    raise notice
      'pg_cron is not installed — task escalation will not run. Enable the '
      'extension and re-run migration 0119.';
  end if;
end
$$;

-- ============================================================= 4. the numbers

-- Four figures for the card on the dashboard. Cheap enough to ask on every
-- open, which is the only kind of number a home screen should carry.
create or replace function my_task_stats()
  returns table (
    open_count    int,
    overdue_count int,
    review_count  int,
    done_count    int
  )
  language plpgsql stable security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Riyadh')::date;
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;

  return query
  select
    -- On my list and not finished.
    (select count(*)::int from personal_tasks t
      where t.profile_id = v_uid and t.state not in ('done','cancelled')),
    -- On my list and past its date.
    (select count(*)::int from personal_tasks t
      where t.profile_id = v_uid and t.due_on < v_today
        and t.state not in ('done','cancelled')),
    -- Waiting on MY decision — work I asked for that somebody says is done.
    (select count(*)::int from personal_tasks t
      where t.created_by = v_uid and t.created_by <> t.profile_id
        and t.state = 'submitted'),
    -- Finished on my list this season's month. A number that only ever goes
    -- up is not an achievement, it is a total.
    (select count(*)::int from personal_tasks t
      where t.profile_id = v_uid and t.state = 'done'
        and t.completed_at > now() - interval '30 days');
end;
$$;

revoke execute on function my_task_stats() from public, anon;
grant  execute on function my_task_stats() to authenticated;
