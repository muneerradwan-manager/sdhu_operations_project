-- المهمة المُسنَدة تُقبل ولا تُعلن، ولها ذاكرة لا تُمحى.
--
-- 0105 moved tracking to where the person is, and that was right. What it left
-- behind is a system in which the man who ASSIGNS work has exactly one verb —
-- assign — and never a second one. The assignee presses منجزة and the matter is
-- closed by the only party with an interest in closing it. There is no
-- acceptance, no return, no way to say "not like that", and no way for a
-- supervisor to see the difference between work that was done and work that was
-- declared done.
--
-- The second thing 0105 left behind is a single `note` column that
-- `set_personal_task_state` overwrites on every call. What a man wrote last
-- night about why the office was shut is gone the moment he writes "تم" this
-- morning. The one place in this system where a conversation actually happens
-- was built as a field that forgets.
--
-- Both are the same defect: a task was modelled as a VALUE when it is an
-- EXCHANGE between two people. So —
--
--   states           three become seven. The four new ones exist only because a
--                    real exchange needs them: متعثّرة (I am stuck, and here is
--                    why), بانتظار القبول (I say it is done), مُعادة (I say it is
--                    not), ملغاة (it is withdrawn, and the record stands).
--
--   transitions      a matrix, enforced in one function, keyed on the same
--                    comparison the whole system rests on: created_by =
--                    profile_id. On his own list a man closes his own work. On
--                    ASSIGNED work, منجزة is the assigner's word and nobody
--                    else's.
--
--   comments         a table. The note column survives as a DERIVED cache of the
--                    last thing said — useful to a list that must not join —
--                    but it is no longer where the memory lives.
--
--   events           every transition writes one. Not the audit log: that is for
--                    whoever audits, and this is shown to the two people in the
--                    exchange, in their own screen, in order.
--
-- What does NOT change: a man's own notebook. `created_by = profile_id` still
-- means his entirely, still unreadable to the administrator, still closed by
-- pressing one button. Everything below applies its weight only where somebody
-- else's pen wrote the row.

-- ================================================ 1. seven states, not three

-- First, what 0105 meant to remove and did not.
--
-- Its section 10 says `drop function if exists set_module_task_state(uuid,
-- text, uuid, uuid, uuid, uuid, text)`. The function's second argument was
-- never `text` — it was the enum — so `if exists` found nothing, said nothing,
-- and the whole board-era function is still there holding a reference to the
-- type. It has been dead since 0105: its tables were dropped in the same file,
-- so every call it could receive would fail on a missing relation.
--
-- Swept by dependency rather than by name, because a signature written out by
-- hand is exactly what went wrong the first time. Everything in `public` that
-- mentions this type in its ARGUMENTS or RETURN goes, except the three
-- functions further down this file that are about to be written with it.
do $$
declare fn record;
begin
  for fn in
    select distinct p.oid::regprocedure as sig
      from pg_depend d
      join pg_proc p on p.oid = d.objid
      join pg_type t on t.oid = d.refobjid
     where d.classid    = 'pg_proc'::regclass
       and d.refclassid = 'pg_type'::regclass
       and t.typname = 'task_state'
       and p.pronamespace = 'public'::regnamespace
       and p.proname not in (
         'personal_task_transition_allowed',
         'personal_task_thread',
         'personal_task_bucket'
       )
  loop
    raise notice 'dropping % — it outlived its tables', fn.sig;
    execute format('drop function if exists %s', fn.sig);
  end loop;
end
$$;

-- Replaced rather than extended. `alter type … add value` cannot be used in the
-- same transaction that adds it, and this migration uses every new value below
-- — in an index predicate, in a check, in the seed of the transition table. A
-- fresh type has no such rule, and the swap is exact: the four old rows' values
-- have the same spelling in the new type.
do $$
begin
  if exists (
    select 1 from pg_type t
     where t.typname = 'task_state'
       and not exists (
         select 1 from pg_enum e
          where e.enumtypid = t.oid and e.enumlabel = 'submitted')
  ) then
    create type task_state_next as enum (
      'not_started',   -- لم تبدأ
      'in_progress',   -- قيد التنفيذ
      'blocked',       -- متعثّرة — عليها سبب مكتوب، دائماً
      'submitted',     -- بانتظار القبول — المُسنَد إليه قال إنه أنجز
      'done',          -- منجزة — وعلى المُسنَد: مقبولة
      'returned',      -- مُعادة — المُسنِد قال ما الناقص
      'cancelled'      -- ملغاة — سُحبت، وأثرها باقٍ
    );

    alter table personal_tasks
      alter column state drop default,
      alter column state type task_state_next using state::text::task_state_next,
      alter column state set default 'not_started';

    drop type task_state;
    alter type task_state_next rename to task_state;
  end if;
end
$$;

-- ==================================================== 2. what the row records

alter table personal_tasks
  -- Stamped once, by the first move to قيد التنفيذ and never again. A man who
  -- steps back to متعثّرة and forward again did not start twice.
  add column if not exists started_at   timestamptz,

  -- When the assignee said he was finished. Kept through a return, because
  -- "he submitted it on the 9th and it came back" is the fact worth having.
  add column if not exists submitted_at timestamptz,

  -- When it was ACCEPTED — which on assigned work is a different moment from
  -- when it was submitted, and on a man's own list is the same one.
  add column if not exists completed_at timestamptz,
  add column if not exists accepted_by  uuid references profiles (id),

  -- Last time the lateness of this task was reported to somebody. 0119 uses it;
  -- the column lands here so the escalation migration adds no columns to a hot
  -- table.
  add column if not exists escalated_at timestamptz;

comment on column personal_tasks.note is
  'آخر ما قيل — مشتقٌّ من آخر تعليق، لا مصدر. الذاكرة في personal_task_comments.';

-- ========================================================== 3. the exchange

-- The conversation. One row per thing a person said; nothing here is ever
-- overwritten by a state change, which is the whole point of the table.
create table if not exists personal_task_comments (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid not null references personal_tasks (id) on delete cascade,
  author_id  uuid not null references profiles (id) on delete cascade,
  body       text not null check (btrim(body) <> ''),

  -- True when the comment was written by a state change rather than typed on
  -- its own. Read together with the event beside it, this is what lets the
  -- screen draw «أعادها وقال: الكشف ناقص» as ONE line instead of two.
  is_transition boolean not null default false,

  created_at timestamptz not null default now(),
  edited_at  timestamptz
);

create index if not exists idx_personal_task_comments_task
  on personal_task_comments (task_id, created_at);

-- The record of what HAPPENED, as against what was said. Deliberately not the
-- audit log: `audit_log` answers "who changed this row" for whoever audits, and
-- is dropped a season and a half later (0109). This is shown to the two people
-- in the exchange, on their own screen, and it must outlive nothing but the
-- task itself.
create table if not exists personal_task_events (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid not null references personal_tasks (id) on delete cascade,
  actor_id   uuid references profiles (id) on delete set null,

  -- created | state | reassigned | due | priority | escalated
  kind       text not null,

  from_state task_state,
  to_state   task_state,

  -- Whatever the kind needs and no column would be worth carrying for: the two
  -- profile ids of a reassignment, the two dates of a moved deadline.
  payload    jsonb,

  created_at timestamptz not null default now()
);

create index if not exists idx_personal_task_events_task
  on personal_task_events (task_id, created_at);

-- Evidence may now hang off one thing said rather than off the task as a whole.
-- Null keeps the 0105 meaning — filed against the task itself — so nothing
-- already stored moves.
alter table personal_task_attachments
  add column if not exists comment_id uuid
    references personal_task_comments (id) on delete cascade;

create index if not exists idx_personal_task_attachments_comment
  on personal_task_attachments (comment_id) where comment_id is not null;

-- ============================================== 4. the indexes the list needs

-- «مهامي» with its filter: one person, open work, by deadline.
create index if not exists idx_personal_tasks_list
  on personal_tasks (profile_id, state, due_on)
  where state <> 'cancelled';

-- The two queues somebody with oversight opens: what awaits a decision, and
-- what is stuck. Both are small slices of a large table.
create index if not exists idx_personal_tasks_pending
  on personal_tasks (state, due_on)
  where state in ('submitted', 'blocked');

-- ========================================================= 5. seeing it all

-- `tasks.assign` already lets its holder read every assigned task (0105's
-- select policy). What it did NOT do was let him read them through a query he
-- could actually write: `fetchAssignedByMe` narrows to created_by = me, so the
-- oversight the policy allows was never reachable. Rather than widen the client
-- query silently against a grant that says «إسناد», the wider read gets a name.
insert into permissions (code, description, parent_id, sort_order)
select 'tasks.view_all',
       'See every assigned task in the mission, not only one''s own',
       p.id, 2
from permissions p where p.code = 'tasks'
on conflict (code) do nothing;

insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from (values ('tasks.view_all', 'tasks.assign')) as v(code, requires_code)
join permissions c on c.code = v.code
join permissions r on r.code = v.requires_code
on conflict do nothing;

-- Nobody is granted it in the migration. Oversight over other people's
-- workload is a decision somebody makes, not a default anyone inherits — and
-- unlike 0105's carry-over there is no yesterday in which anybody held this.

-- =============================================== 6. who may do what, restated

-- Unchanged from 0105 and repeated here only because the functions below read
-- it constantly: full control is the author's, and the assigner's over
-- ASSIGNED tasks. A man's own notebook has exactly one full pen — his.
--
-- What IS new: `tasks.view_all` joins `tasks.assign` in the assigned-task
-- branch, so the two grants agree about what an assigned task is.
create or replace function can_edit_personal_task(p_task_id uuid)
  returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from personal_tasks t
     where t.id = p_task_id
       and (t.created_by = auth.uid()
            or (t.created_by <> t.profile_id
                and (is_admin() or has_permission('tasks.assign'))))
  );
$$;

create or replace function can_read_personal_task(p_task_id uuid)
  returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from personal_tasks t
     where t.id = p_task_id
       and (t.profile_id = auth.uid()
            or t.created_by = auth.uid()
            or (t.created_by <> t.profile_id
                and (is_admin()
                     or has_permission('tasks.assign')
                     or has_permission('tasks.view_all'))))
  );
$$;

create or replace function can_set_personal_task_state(p_task_id uuid)
  returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from personal_tasks t
     where t.id = p_task_id and t.profile_id = auth.uid()
  ) or can_edit_personal_task(p_task_id);
$$;

-- ==================================================== 7. the transition table
--
-- One function, no side effects, and every rule in the system is a row of its
-- CASE. Pure so that it can be asked without changing anything — the screen
-- asks it through `personal_task_actions` below to decide which buttons exist
-- at all, and a button that is offered and then refused is a worse lie than no
-- button.
--
-- The three flags are the whole vocabulary:
--   p_assigned  the row was written by somebody else (created_by <> profile_id)
--   p_owner     the caller is whose list it sits on
--   p_full      the caller holds the full pen (author, or oversight on assigned)
create or replace function personal_task_transition_allowed(
  p_from     task_state,
  p_to       task_state,
  p_assigned boolean,
  p_owner    boolean,
  p_full     boolean
) returns boolean
  language sql immutable set search_path = public as $$
  select case
    -- Nothing moves to where it already is.
    when p_from = p_to then false

    -- Withdrawal, and the way back from it. The full pen only: a man cannot
    -- make an assignment disappear from his own list by cancelling it.
    when p_to = 'cancelled'   then p_full
    when p_from = 'cancelled' then p_full and p_to = 'not_started'

    -- Picking it up, or picking it up again after being stuck or sent back.
    when p_to = 'in_progress' and p_from in ('not_started','blocked','returned')
      then p_owner

    -- Reopening something already accepted. The full pen, because the
    -- acceptance being undone is the full pen's own.
    when p_to = 'in_progress' and p_from = 'done'
      then p_full

    -- Stuck. Available before starting as well as during it: an office that is
    -- shut stops a man who has not begun exactly as it stops one who has.
    when p_to = 'blocked' and p_from in ('not_started','in_progress')
      then p_owner

    -- «أنجزتُ» on work somebody else asked for. It is a CLAIM, and it is as far
    -- as the assignee's power reaches.
    when p_to = 'submitted'
      then p_assigned and p_owner
       and p_from in ('not_started','in_progress','blocked','returned')

    -- «منجزة». On a man's own list he says it himself; on assigned work it is
    -- the assigner's word, and only ever about something claimed.
    when p_to = 'done' and not p_assigned
      then p_owner and p_from in ('not_started','in_progress','blocked')
    when p_to = 'done' and p_assigned
      then p_full and p_from = 'submitted'

    -- «مُعادة». Only against a claim, and never on a man's own notebook —
    -- there is nobody there to return it to.
    when p_to = 'returned'
      then p_assigned and p_full and p_from = 'submitted'

    else false
  end;
$$;

-- What the caller may do to this task RIGHT NOW, as a json array of state
-- names. One round trip, and the screen draws exactly these buttons.
create or replace function personal_task_actions(p_task_id uuid)
  returns jsonb
  language plpgsql stable security definer set search_path = public as $$
declare
  t          personal_tasks;
  v_uid      uuid := auth.uid();
  v_assigned boolean;
  v_owner    boolean;
  v_full     boolean;
  v_out      jsonb := '[]'::jsonb;
  v_state    task_state;
begin
  select * into t from personal_tasks where id = p_task_id;
  if not found or not can_read_personal_task(p_task_id) then
    return v_out;
  end if;

  v_assigned := t.created_by <> t.profile_id;
  v_owner    := t.profile_id = v_uid;
  v_full     := can_edit_personal_task(p_task_id);

  foreach v_state in array enum_range(null::task_state) loop
    if personal_task_transition_allowed(
         t.state, v_state, v_assigned, v_owner, v_full) then
      v_out := v_out || to_jsonb(v_state::text);
    end if;
  end loop;
  return v_out;
end;
$$;

-- ================================================ 8. moving it, and saying so

-- The assignee's door, widened into everybody's door.
--
-- The third parameter keeps the name `p_note` it was given in 0105, and that is
-- not an oversight. Entries written by an older build are sitting in outboxes
-- on phones in the field right now, and they name their arguments; renaming
-- this would block every one of them the day the migration lands. What it MEANS
-- has changed — it is the body of a comment, appended, not a field overwritten
-- — and the column it used to write is now the cache of the last one.
create or replace function set_personal_task_state(
  p_task_id uuid,
  p_state   text,
  p_note    text default null
) returns void
  language plpgsql security definer set search_path = public as $$
declare
  t          personal_tasks;
  v_uid      uuid := auth.uid();
  v_to       task_state;
  v_assigned boolean;
  v_owner    boolean;
  v_full     boolean;
  v_body     text := nullif(btrim(coalesce(p_note, '')), '');
  v_comment  uuid;
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;

  select * into t from personal_tasks where id = p_task_id for update;
  if not found then
    raise exception 'task_not_found';
  end if;

  begin
    v_to := p_state::task_state;
  exception when others then
    raise exception 'unknown state: %', p_state;
  end;

  v_assigned := t.created_by <> t.profile_id;
  v_owner    := t.profile_id = v_uid;
  v_full     := can_edit_personal_task(p_task_id);

  if not (v_owner or v_full) then
    raise exception 'not allowed to set the state of this task';
  end if;

  -- Idempotent rather than an error: an outbox entry replayed after the network
  -- came back must not fail because it already arrived. Same reasoning as
  -- everything else the queue may send twice.
  if t.state = v_to then
    return;
  end if;

  if not personal_task_transition_allowed(
       t.state, v_to, v_assigned, v_owner, v_full) then
    raise exception 'task_transition_not_allowed: % -> %', t.state, v_to;
  end if;

  -- The two states that are an ASSERTION about somebody else's work, or about
  -- why work is not happening. Both are useless without the sentence, and a
  -- system that accepts them empty collects a column of shrugs.
  if v_to in ('blocked', 'returned') and v_body is null then
    raise exception 'task_comment_required';
  end if;

  if v_body is not null then
    insert into personal_task_comments (task_id, author_id, body, is_transition)
    values (p_task_id, v_uid, v_body, true)
    returning id into v_comment;
  end if;

  update personal_tasks
     set state        = v_to,
         -- Once, and never again: see the column comment.
         started_at   = case when v_to = 'in_progress'
                             then coalesce(started_at, now()) else started_at end,
         submitted_at = case when v_to = 'submitted'
                             then now() else submitted_at end,
         completed_at = case when v_to = 'done' then now()
                             when v_to = 'in_progress' then null
                             else completed_at end,
         accepted_by  = case when v_to = 'done' and v_assigned then v_uid
                             when v_to = 'in_progress' then null
                             else accepted_by end,
         -- The lateness has been answered for; 0119's sweep starts over.
         escalated_at = case when v_to in ('done','cancelled')
                             then null else escalated_at end,
         note         = coalesce(v_body, note),
         updated_at   = now(),
         updated_by   = v_uid
   where id = p_task_id;

  insert into personal_task_events
    (task_id, actor_id, kind, from_state, to_state, payload)
  values
    (p_task_id, v_uid, 'state', t.state, v_to,
     case when v_comment is null then null
          else jsonb_build_object('comment_id', v_comment) end);
end;
$$;

revoke execute on function set_personal_task_state(uuid, text, text)
  from public, anon;
grant execute on function set_personal_task_state(uuid, text, text)
  to authenticated;

-- ================================================== 9. saying something else

-- A comment with no state change behind it — the ordinary case of two people
-- talking about a task. Returns the id so evidence can be filed under it.
create or replace function add_personal_task_comment(
  p_task_id uuid,
  p_body    text
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_body text := nullif(btrim(coalesce(p_body, '')), '');
  v_id   uuid;
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;
  if v_body is null then
    raise exception 'task_comment_required';
  end if;
  -- Whoever may READ the task may talk about it. Narrower than that would mean
  -- an assigner watching a task go late with no way to ask about it.
  if not can_read_personal_task(p_task_id) then
    raise exception 'not allowed to comment on this task';
  end if;

  insert into personal_task_comments (task_id, author_id, body)
  values (p_task_id, v_uid, v_body)
  returning id into v_id;

  update personal_tasks
     set note = v_body, updated_at = now(), updated_by = v_uid
   where id = p_task_id;

  return v_id;
end;
$$;

revoke execute on function add_personal_task_comment(uuid, text) from public, anon;
grant  execute on function add_personal_task_comment(uuid, text) to authenticated;

-- ===================================================== 10. reading the thread

-- Said and happened, in one list, in order. The screen draws them as one
-- column because that is what a person remembers — not "the comments" and
-- separately "the history", but what went on.
create or replace function personal_task_attachment_json(
  p_task_id uuid, p_comment_id uuid
) returns jsonb
  language sql stable security definer set search_path = public as $$
  select coalesce(
           jsonb_agg(to_jsonb(a) order by a.sort_order, a.created_at),
           '[]'::jsonb)
    from personal_task_attachments a
   where a.task_id = p_task_id
     and a.comment_id is not distinct from p_comment_id;
$$;

create or replace function personal_task_thread(p_task_id uuid)
returns table (
  entry_id    uuid,
  kind        text,
  created_at  timestamptz,
  actor_id    uuid,
  actor_name  text,
  body        text,
  from_state  task_state,
  to_state    task_state,
  payload     jsonb,
  attachments jsonb
)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not authorized';
  end if;
  if not can_read_personal_task(p_task_id) then
    raise exception 'not allowed to read this task';
  end if;

  return query
  -- A transition that carried a sentence appears ONCE, as the event, with the
  -- words on it. Two rows for one act would read as the man having said it and
  -- then, separately, done it.
  select c.id,
         'comment'::text,
         c.created_at,
         c.author_id,
         audit_actor_name(c.author_id),
         c.body,
         null::task_state,
         null::task_state,
         null::jsonb,
         personal_task_attachment_json(p_task_id, c.id)
    from personal_task_comments c
   where c.task_id = p_task_id
     and not c.is_transition

  union all

  select e.id,
         e.kind,
         e.created_at,
         e.actor_id,
         audit_actor_name(e.actor_id),
         c.body,
         e.from_state,
         e.to_state,
         e.payload,
         case when c.id is null then '[]'::jsonb
              else personal_task_attachment_json(p_task_id, c.id) end
    from personal_task_events e
    left join personal_task_comments c
           on c.id = (e.payload ->> 'comment_id')::uuid
   where e.task_id = p_task_id

   order by 3, 1;
end;
$$;

revoke execute on function personal_task_thread(uuid) from public, anon;
grant  execute on function personal_task_thread(uuid) to authenticated;

-- ============================================================= 11. row rules

alter table personal_task_comments enable row level security;
alter table personal_task_events   enable row level security;

-- Both defer wholly to the task's own policy, the way the attachments table
-- already does: one answer to "who may see this task", asked in one place.
drop policy if exists personal_task_comments_select on personal_task_comments;
create policy personal_task_comments_select on personal_task_comments for select
  using (
    exists (select 1 from personal_tasks t
             where t.id = personal_task_comments.task_id)
  );

-- Writing goes through the two functions above, which check and stamp. Direct
-- insert is closed so there is one door, not two.
drop policy if exists personal_task_comments_insert on personal_task_comments;
create policy personal_task_comments_insert on personal_task_comments for insert
  with check (false);

-- Correcting one's own words, within reach of a person and nobody else's.
drop policy if exists personal_task_comments_update on personal_task_comments;
create policy personal_task_comments_update on personal_task_comments for update
  using (author_id = auth.uid() and not is_transition)
  with check (author_id = auth.uid() and not is_transition);

drop policy if exists personal_task_comments_delete on personal_task_comments;
create policy personal_task_comments_delete on personal_task_comments for delete
  using (
    (author_id = auth.uid() and not is_transition)
    or can_edit_personal_task(task_id)
  );

drop policy if exists personal_task_events_select on personal_task_events;
create policy personal_task_events_select on personal_task_events for select
  using (
    exists (select 1 from personal_tasks t
             where t.id = personal_task_events.task_id)
  );

-- Nothing writes an event but the functions in this file. A history anybody may
-- append to is not a history.
drop policy if exists personal_task_events_write on personal_task_events;
create policy personal_task_events_write on personal_task_events for all
  using (false) with check (false);

-- The select policy on attachments already defers to the task. The write policy
-- said `can_set_personal_task_state`, which was right when the only reason to
-- attach anything was moving the state; now anybody who may comment may attach
-- to their comment — and the one `for all` policy splits, because filing
-- evidence and removing somebody else's are not the same act.
drop policy if exists personal_task_attachments_write on personal_task_attachments;

drop policy if exists personal_task_attachments_insert on personal_task_attachments;
create policy personal_task_attachments_insert on personal_task_attachments
  for insert with check (can_read_personal_task(task_id));

drop policy if exists personal_task_attachments_delete on personal_task_attachments;
create policy personal_task_attachments_delete on personal_task_attachments
  for delete using (
    can_set_personal_task_state(task_id)
    -- What a person hung on their own words is theirs to take down.
    or exists (
      select 1 from personal_task_comments c
       where c.id = personal_task_attachments.comment_id
         and c.author_id = auth.uid())
  );

-- Same widening in storage: the bucket rule and the row rule must agree, or
-- evidence uploads and then cannot be recorded.
drop policy if exists task_files_write on storage.objects;
create policy task_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'tasks'
    and public.can_read_personal_task(public.personal_task_file_id(name))
  );

drop policy if exists task_files_delete on storage.objects;
create policy task_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'tasks'
    and public.can_set_personal_task_state(public.personal_task_file_id(name))
  );

-- Reading, restated on top of 0105's version so that `tasks.view_all` reaches
-- the evidence it can already reach the row of.
drop policy if exists task_files_read on storage.objects;
create policy task_files_read on storage.objects for select
  to authenticated using (
    bucket_id = 'tasks'
    and public.can_read_personal_task(public.personal_task_file_id(name))
  );

-- Deleting an ASSIGNED task is closed, and `cancelled` is what replaces it.
--
-- Under 0105 an assigner who changed his mind made the row disappear from
-- another man's list with no trace and no notice — the man had read it, perhaps
-- started it, and the next morning it was simply not there. Withdrawal is a
-- decision somebody made and it should read as one. A man's own notebook still
-- deletes: nobody is owed the record of a reminder he wrote to himself.
drop policy if exists personal_tasks_delete on personal_tasks;
create policy personal_tasks_delete on personal_tasks for delete
  using (created_by = profile_id and can_edit_personal_task(id));

-- The task's own select policy widens by the new grant, and by nothing else.
-- The notebook clause is untouched: `created_by <> profile_id` still guards
-- every branch that is not the reader's own.
drop policy if exists personal_tasks_select on personal_tasks;
create policy personal_tasks_select on personal_tasks for select
  using (
    profile_id = auth.uid()
    or created_by = auth.uid()
    or (created_by <> profile_id
        and (is_admin()
             or has_permission('tasks.assign')
             or has_permission('tasks.view_all')))
  );

-- ==================================================== 12. what was said, kept

-- Every note written under 0105 becomes the first comment of its task, dated to
-- the last time the row was touched — which is when it was written, since
-- writing it was the touch. Attributed to whoever made that edit.
--
-- Marked `is_transition` so the thread shows it beside the history rather than
-- as a fresh remark, and so a second run of this file cannot duplicate it: the
-- guard below is the existence of any transition comment on the task.
insert into personal_task_comments
  (task_id, author_id, body, is_transition, created_at)
select t.id,
       coalesce(t.updated_by, t.profile_id),
       btrim(t.note),
       true,
       coalesce(t.updated_at, t.created_at)
  from personal_tasks t
 where nullif(btrim(coalesce(t.note, '')), '') is not null
   and not exists (
     select 1 from personal_task_comments c where c.task_id = t.id);

-- The row that says the task began, so no thread opens with a blank.
insert into personal_task_events (task_id, actor_id, kind, created_at)
select t.id, t.created_by, 'created', t.created_at
  from personal_tasks t
 where not exists (
   select 1 from personal_task_events e
    where e.task_id = t.id and e.kind = 'created');

-- From here on the trigger does it, for every task written by anybody.
create or replace function on_personal_task_created() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  insert into personal_task_events (task_id, actor_id, kind)
  values (new.id, auth.uid(), 'created');

  -- 0105's rule, unchanged: a man does not need a push notification about his
  -- own note to himself.
  if new.created_by = new.profile_id then
    return new;
  end if;

  insert into notifications (recipient_id, sender_id, title, body, data)
  values (
    new.profile_id,
    auth.uid(),
    'أُسندت إليك مهمة',
    new.title,
    jsonb_build_object('type', 'personal_task_assigned', 'task_id', new.id)
  );
  return new;
end;
$$;

-- ================================================================ 13. the log

do $$
declare t text;
begin
  foreach t in array array['personal_task_comments', 'personal_task_events'] loop
    execute format('drop trigger if exists audit_row on %I', t);
    execute format(
      'create trigger audit_row after insert or update or delete on %I '
      'for each row execute function audit_row_change()', t);
  end loop;
end
$$;
