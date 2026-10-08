-- القرار الواحد شيءٌ واحد، وللمهمة رقمٌ يُنطق ووزنٌ يُقرأ.
--
-- 0105 wrote assignment to several people as several rows, deliberately, and
-- gave the reason: "from there each carries it separately". That is true of the
-- CARRYING and false of the deciding. Handing استلام كشوف الحجاج to six
-- supervisors is one decision, and the screen that follows it up groups by
-- person — so the one question the assigner actually has, «كم أنجزها من
-- الستة؟», is the one question nothing on it can answer.
--
-- Three things land together here because each is useless alone:
--
--   batch      the decision, with the six rows hanging off it. A row still
--              belongs to one man and is still carried alone; what is new is
--              that it remembers what it was part of.
--
--   seq        م-١٤٢. Half the coordination in a mission happens on a radio and
--              in WhatsApp, where «المهمة الثانية اللي أرسلتها لك» is how people
--              are forced to refer to work that has a uuid and no name.
--
--   priority   three levels. Five would make ninety per cent of them «متوسطة»,
--              which is a field nobody sets and every screen has to draw.
--
-- And with them the reading these make necessary: a list that filters, sorts by
-- what is urgent rather than by what is newest, and pages. `fetchMine` reads
-- every task a person has ever had, on every open, and then reads all their
-- attachments in a second round trip — which was survivable when a list was
-- eleven rows and stops being so the first season anybody uses this properly.

-- =============================================================== 1. the words

do $$
begin
  if not exists (select 1 from pg_type where typname = 'task_priority') then
    create type task_priority as enum ('high', 'normal', 'low');
  end if;
  if not exists (select 1 from pg_type where typname = 'task_kind') then
    -- Three, and no catalog. 0105's whole lesson was that a table of types
    -- nobody fills is a promise the screen keeps making; these are the three
    -- shapes work in a mission actually takes, spelled once, here.
    create type task_kind as enum (
      'task',       -- مهمة   — افعل شيئاً
      'follow_up',  -- متابعة — تأكّد من شيء يجري
      'request'     -- طلب    — احصل على شيء من جهة
    );
  end if;
end
$$;

-- ============================================================ 2. the decision

create table if not exists personal_task_batches (
  id         uuid primary key default gen_random_uuid(),
  title      text not null,
  created_by uuid not null references profiles (id) on delete cascade,
  due_on     date,
  created_at timestamptz not null default now()
);

create index if not exists idx_personal_task_batches_author
  on personal_task_batches (created_by, created_at desc);

alter table personal_tasks
  add column if not exists batch_id uuid
    references personal_task_batches (id) on delete set null,
  add column if not exists priority task_priority not null default 'normal',
  add column if not exists kind     task_kind     not null default 'task';

create index if not exists idx_personal_tasks_batch
  on personal_tasks (batch_id) where batch_id is not null;

-- ========================================================== 3. the said number

create sequence if not exists personal_task_seq;

alter table personal_tasks add column if not exists seq bigint;

-- Numbered in the order they were written, not in the order the heap happens to
-- hold them: an identity column added to a populated table would hand م-١ to
-- whichever row the page cache saw first, and these numbers are read aloud.
do $$
begin
  if exists (select 1 from personal_tasks where seq is null) then
    with ordered as (
      select id, row_number() over (order by created_at, id) as rn
        from personal_tasks where seq is null
    )
    update personal_tasks t
       set seq = o.rn
      from ordered o
     where o.id = t.id;

    perform setval(
      'personal_task_seq',
      coalesce((select max(seq) from personal_tasks), 0) + 1,
      false);
  end if;
end
$$;

alter table personal_tasks alter column seq set default nextval('personal_task_seq');
alter table personal_tasks alter column seq set not null;
alter sequence personal_task_seq owned by personal_tasks.seq;

create unique index if not exists idx_personal_tasks_seq on personal_tasks (seq);

-- ============================================================== 4. the steps

-- A checklist, not sub-tasks. Sub-tasks would need a state, an owner, a
-- deadline and a thread of their own, and «تجهيز مخيّم منى» does not want five
-- more rows in a list — it wants four boxes inside itself that a man ticks
-- standing in the camp with one thumb.
create table if not exists personal_task_steps (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid not null references personal_tasks (id) on delete cascade,
  label      text not null check (btrim(label) <> ''),
  is_done    boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_personal_task_steps_task
  on personal_task_steps (task_id, sort_order);

alter table personal_task_steps enable row level security;

drop policy if exists personal_task_steps_select on personal_task_steps;
create policy personal_task_steps_select on personal_task_steps for select
  using (
    exists (select 1 from personal_tasks t
             where t.id = personal_task_steps.task_id)
  );

-- Ticking a box is part of saying how it is going, and goes with it. Writing
-- the boxes themselves is the full pen — a man may not add duties to a duty he
-- was given — which the two functions below enforce separately.
drop policy if exists personal_task_steps_update on personal_task_steps;
create policy personal_task_steps_update on personal_task_steps for update
  using (can_set_personal_task_state(task_id))
  with check (can_set_personal_task_state(task_id));

drop policy if exists personal_task_steps_write on personal_task_steps;
create policy personal_task_steps_write on personal_task_steps for all
  using (can_edit_personal_task(task_id))
  with check (can_edit_personal_task(task_id));

alter table personal_task_batches enable row level security;

-- The author of the decision, and everybody carrying a piece of it. Plus
-- oversight, through the task rows it already reads.
drop policy if exists personal_task_batches_select on personal_task_batches;
create policy personal_task_batches_select on personal_task_batches for select
  using (
    created_by = auth.uid()
    or exists (select 1 from personal_tasks t
                where t.batch_id = personal_task_batches.id)
  );

-- Written by `create_personal_tasks` and nothing else: a batch with no rows is
-- a decision nobody carries.
drop policy if exists personal_task_batches_write on personal_task_batches;
create policy personal_task_batches_write on personal_task_batches for all
  using (false) with check (false);

-- ========================================================== 5. writing tasks

-- One call, one transaction: the batch and its rows, or neither.
--
-- 0105 made the multi-person insert a single statement for exactly this reason
-- — «ستّ رحلات كانت ستُنجح أربعة وتُخفق اثنين بلا ما يقول أيّهما» — and adding a
-- parent row above them would have reopened the hole if it were written from
-- the client in a second call.
create or replace function create_personal_tasks(
  p_title       text,
  p_description text default null,
  p_due_on      date default null,
  p_profile_ids uuid[] default null,
  p_priority    text default 'normal',
  p_kind        text default 'task',
  p_steps       text[] default null
) returns table (id uuid, seq bigint)
  language plpgsql security definer set search_path = public as $$
declare
  v_uid      uuid := auth.uid();
  v_title    text := nullif(btrim(coalesce(p_title, '')), '');
  v_owners   uuid[];
  v_assign   boolean;
  v_batch    uuid;
  v_priority task_priority;
  v_kind     task_kind;
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;
  if v_title is null then
    raise exception 'task_title_required';
  end if;

  begin
    v_priority := coalesce(p_priority, 'normal')::task_priority;
    v_kind     := coalesce(p_kind, 'task')::task_kind;
  exception when others then
    raise exception 'unknown priority or kind';
  end;

  -- No list, or a list naming only the caller, is a note to oneself.
  v_owners := coalesce(
    nullif(
      array(select distinct unnest(coalesce(p_profile_ids, '{}'::uuid[]))),
      '{}'::uuid[]),
    array[v_uid]);
  v_assign := exists (select 1 from unnest(v_owners) o where o <> v_uid);

  if v_assign and not (is_admin() or has_permission('tasks.assign')) then
    raise exception 'not allowed to assign tasks';
  end if;

  -- A batch only where there is something to hold together. One man carrying
  -- one duty is not a decision that needs a parent, and a parent per task would
  -- make the follow-up screen a list of ones.
  if array_length(v_owners, 1) > 1 then
    insert into personal_task_batches (title, created_by, due_on)
    values (v_title, v_uid, p_due_on)
    returning personal_task_batches.id into v_batch;
  end if;

  return query
  with written as (
    insert into personal_tasks
      (profile_id, created_by, title, description, due_on,
       priority, kind, batch_id)
    select o, v_uid, v_title,
           nullif(btrim(coalesce(p_description, '')), ''),
           p_due_on, v_priority, v_kind, v_batch
      from unnest(v_owners) o
    returning personal_tasks.id, personal_tasks.seq
  ),
  stepped as (
    insert into personal_task_steps (task_id, label, sort_order)
    select w.id, s.label, s.ord
      from written w
      cross join lateral (
        select btrim(l) as label, i - 1 as ord
          from unnest(coalesce(p_steps, '{}'::text[])) with ordinality as u(l, i)
         where btrim(l) <> ''
      ) s
    returning 1
  )
  select w.id, w.seq from written w order by w.seq;
end;
$$;

revoke execute on function create_personal_tasks(text, text, date, uuid[], text, text, text[])
  from public, anon;
grant execute on function create_personal_tasks(text, text, date, uuid[], text, text, text[])
  to authenticated;

-- Replacing the checklist wholesale. Simple on purpose: a list of five labels
-- sent whole survives being sent twice, which a stream of add/remove/reorder
-- calls out of an outbox would not.
create or replace function set_personal_task_steps(
  p_task_id uuid,
  p_labels  text[]
) returns void
  language plpgsql security definer set search_path = public as $$
begin
  if not can_edit_personal_task(p_task_id) then
    raise exception 'not allowed to edit this task';
  end if;

  -- Ticks are preserved by LABEL, because that is the only identity a replaced
  -- list has: a man who reordered his four boxes has not un-done the two he had
  -- already ticked.
  --
  -- One statement, so every branch of it reads the same snapshot: `kept` sees
  -- the rows `gone` is removing, which is the only reason this works.
  with kept as (
    select s.label, bool_or(s.is_done) as is_done
      from personal_task_steps s
     where s.task_id = p_task_id
     group by s.label
  ),
  gone as (
    delete from personal_task_steps where task_id = p_task_id returning 1
  ),
  given as (
    select btrim(l) as label, i - 1 as ord
      from unnest(coalesce(p_labels, '{}'::text[])) with ordinality as u(l, i)
     where btrim(l) <> ''
  )
  insert into personal_task_steps (task_id, label, is_done, sort_order)
  select p_task_id, g.label, coalesce(k.is_done, false), g.ord
    from given g
    left join kept k on k.label = g.label;
end;
$$;

revoke execute on function set_personal_task_steps(uuid, text[]) from public, anon;
grant  execute on function set_personal_task_steps(uuid, text[]) to authenticated;

-- ================================================= 6. what the row logs itself

-- Moving a deadline or raising an urgency is a thing done TO somebody carrying
-- work, and it goes in the record beside the state changes. The state itself is
-- excluded — `set_personal_task_state` writes that event with the comment
-- attached to it, and a trigger would write a second, poorer copy.
create or replace function log_personal_task_change() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if new.due_on is distinct from old.due_on then
    insert into personal_task_events (task_id, actor_id, kind, payload)
    values (new.id, auth.uid(), 'due',
            jsonb_build_object('from', old.due_on, 'to', new.due_on));
  end if;

  if new.priority is distinct from old.priority then
    insert into personal_task_events (task_id, actor_id, kind, payload)
    values (new.id, auth.uid(), 'priority',
            jsonb_build_object('from', old.priority, 'to', new.priority));
  end if;

  return new;
end;
$$;

drop trigger if exists personal_tasks_log_change on personal_tasks;
create trigger personal_tasks_log_change after update on personal_tasks
  for each row execute function log_personal_task_change();

-- =========================================================== 7. reading a list

-- Everything a row of the list draws, computed once on the server: the two
-- names, the counts, and the one thing the client cannot work out at all —
-- which moves the reader may make (0117 §7).
create or replace function personal_task_row_json(t personal_tasks)
  returns jsonb
  language sql stable security definer set search_path = public as $$
  select to_jsonb(t)
       - 'updated_by'
       || jsonb_build_object(
            'owner_name',  audit_actor_name(t.profile_id),
            'author_name', audit_actor_name(t.created_by),
            'is_assigned', t.created_by <> t.profile_id,
            'batch_title', (select b.title from personal_task_batches b
                             where b.id = t.batch_id),
            'comment_count', (select count(*)::int from personal_task_comments c
                               where c.task_id = t.id and not c.is_transition),
            'attachment_count', (select count(*)::int
                                   from personal_task_attachments a
                                  where a.task_id = t.id),
            'steps_total', (select count(*)::int from personal_task_steps s
                             where s.task_id = t.id),
            'steps_done', (select count(*)::int from personal_task_steps s
                            where s.task_id = t.id and s.is_done),
            'actions', personal_task_actions(t.id)
          );
$$;

-- How urgent a state is to the person holding it. This, and not `created_at`,
-- is what a list of thirty must be sorted by — 0105's own comment promised as
-- much and the query never did it.
create or replace function personal_task_bucket(p_state task_state)
  returns int
  language sql immutable set search_path = public as $$
  select case p_state
    when 'returned'    then 0   -- somebody is waiting on a correction
    when 'blocked'     then 0   -- somebody is waiting on an answer
    when 'in_progress' then 1
    when 'not_started' then 1
    when 'submitted'   then 2   -- waiting on somebody else, not on me
    when 'done'        then 3
    else 4                      -- cancelled
  end;
$$;

-- One reader's list, filtered and ordered and paged.
--
-- `p_view` is the six things anybody actually asks a task list, named rather
-- than expressed: a query language on a telephone is a feature for the person
-- who wrote it.
create or replace function my_personal_tasks(
  p_view     text default 'open',
  p_state    text default null,
  p_priority text default null,
  p_kind     text default null,
  p_query    text default null,
  p_limit    int  default 50,
  p_offset   int  default 0
) returns table (task jsonb)
  language plpgsql stable security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Riyadh')::date;
  v_q     text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;

  return query
  select personal_task_row_json(t)
    from personal_tasks t
   where t.profile_id = v_uid
     and case coalesce(p_view, 'open')
           when 'all'     then true
           when 'done'    then t.state = 'done'
           when 'overdue' then t.due_on < v_today
                            and t.state not in ('done','cancelled')
           -- Dated work only. An undated reminder is not "today's" merely
           -- because nobody said when — it belongs in «الكل», where it can be
           -- read without crowding out what has an hour on it.
           when 'today'   then t.due_on <= v_today
                            and t.state not in ('done','cancelled')
           when 'week'    then t.due_on <= v_today + 7
                            and t.state not in ('done','cancelled')
           else                t.state not in ('done','cancelled')
         end
     and (p_state    is null or t.state    = p_state::task_state)
     and (p_priority is null or t.priority = p_priority::task_priority)
     and (p_kind     is null or t.kind     = p_kind::task_kind)
     and (v_q is null
          or t.title ilike '%' || v_q || '%'
          or t.description ilike '%' || v_q || '%'
          or t.seq::text = v_q)
   order by personal_task_bucket(t.state),
            t.due_on asc nulls last,
            t.priority asc,          -- the enum is declared high → low
            t.created_at desc
   limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

revoke execute on function my_personal_tasks(text, text, text, text, text, int, int)
  from public, anon;
grant execute on function my_personal_tasks(text, text, text, text, text, int, int)
  to authenticated;

-- What the caller wrote onto other people's lists — or, for `tasks.view_all`,
-- every assigned task in the mission. Same filters, same order, one more axis.
create or replace function assigned_personal_tasks(
  p_scope    text default 'mine',
  p_view     text default 'open',
  p_state    text default null,
  p_priority text default null,
  p_query    text default null,
  p_limit    int  default 100,
  p_offset   int  default 0
) returns table (task jsonb)
  language plpgsql stable security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Riyadh')::date;
  v_q     text := nullif(btrim(coalesce(p_query, '')), '');
  v_all   boolean := coalesce(p_scope, 'mine') = 'all';
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;
  if not (is_admin() or has_permission('tasks.assign')) then
    raise exception 'not allowed to see assigned tasks';
  end if;
  if v_all and not (is_admin() or has_permission('tasks.view_all')) then
    raise exception 'not allowed to see every assigned task';
  end if;

  return query
  select personal_task_row_json(t)
    from personal_tasks t
   where t.created_by <> t.profile_id
     and (v_all or t.created_by = v_uid)
     and case coalesce(p_view, 'open')
           when 'all'     then true
           when 'done'    then t.state = 'done'
           when 'review'  then t.state = 'submitted'
           when 'overdue' then t.due_on < v_today
                            and t.state not in ('done','cancelled')
           else                t.state not in ('done','cancelled')
         end
     and (p_state    is null or t.state    = p_state::task_state)
     and (p_priority is null or t.priority = p_priority::task_priority)
     and (v_q is null
          or t.title ilike '%' || v_q || '%'
          or t.seq::text = v_q)
   order by personal_task_bucket(t.state),
            t.due_on asc nulls last,
            t.priority asc,
            t.created_at desc
   limit greatest(1, least(coalesce(p_limit, 100), 300))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

revoke execute on function assigned_personal_tasks(text, text, text, text, text, int, int)
  from public, anon;
grant execute on function assigned_personal_tasks(text, text, text, text, text, int, int)
  to authenticated;

-- ========================================================= 8. reading a batch

-- The decisions the caller made, each with what it adds up to. This is the
-- screen 0105 could not draw.
create or replace function my_task_batches(
  p_limit int default 50,
  p_offset int default 0
) returns table (
  id         uuid,
  title      text,
  due_on     date,
  created_at timestamptz,
  total      int,
  done       int,
  submitted  int,
  blocked    int,
  overdue    int
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_today date := (now() at time zone 'Asia/Riyadh')::date;
begin
  if auth.uid() is null then
    raise exception 'not authorized';
  end if;

  return query
  select b.id, b.title, b.due_on, b.created_at,
         count(t.id)::int,
         count(*) filter (where t.state = 'done')::int,
         count(*) filter (where t.state = 'submitted')::int,
         count(*) filter (where t.state = 'blocked')::int,
         count(*) filter (where t.due_on < v_today
                            and t.state not in ('done','cancelled'))::int
    from personal_task_batches b
    left join personal_tasks t on t.batch_id = b.id
   where b.created_by = auth.uid()
   group by b.id
   order by b.created_at desc
   limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

revoke execute on function my_task_batches(int, int) from public, anon;
grant  execute on function my_task_batches(int, int) to authenticated;

create or replace function task_batch_tasks(p_batch_id uuid)
  returns table (task jsonb)
  language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not authorized';
  end if;
  if not exists (
    select 1 from personal_task_batches b
     where b.id = p_batch_id
       and (b.created_by = auth.uid()
            or is_admin() or has_permission('tasks.view_all'))
  ) then
    raise exception 'not allowed to read this batch';
  end if;

  return query
  select personal_task_row_json(t)
    from personal_tasks t
   where t.batch_id = p_batch_id
   order by personal_task_bucket(t.state), audit_actor_name(t.profile_id);
end;
$$;

revoke execute on function task_batch_tasks(uuid) from public, anon;
grant  execute on function task_batch_tasks(uuid) to authenticated;

-- ============================================================= 9. one task

-- Everything the detail page needs but the thread: the row, its steps and its
-- unattached evidence.
create or replace function personal_task_detail(p_task_id uuid)
  returns jsonb
  language plpgsql stable security definer set search_path = public as $$
declare
  t personal_tasks;
begin
  if not can_read_personal_task(p_task_id) then
    raise exception 'not allowed to read this task';
  end if;
  select * into t from personal_tasks where id = p_task_id;

  return personal_task_row_json(t) || jsonb_build_object(
    'steps', coalesce((
       select jsonb_agg(to_jsonb(s) order by s.sort_order, s.created_at)
         from personal_task_steps s where s.task_id = p_task_id), '[]'::jsonb),
    'attachments', personal_task_attachment_json(p_task_id, null)
  );
end;
$$;

revoke execute on function personal_task_detail(uuid) from public, anon;
grant  execute on function personal_task_detail(uuid) to authenticated;

-- ================================================================ 10. the log

do $$
declare t text;
begin
  foreach t in array array['personal_task_batches', 'personal_task_steps'] loop
    execute format('drop trigger if exists audit_row on %I', t);
    execute format(
      'create trigger audit_row after insert or update or delete on %I '
      'for each row execute function audit_row_change()', t);
  end loop;
end
$$;
