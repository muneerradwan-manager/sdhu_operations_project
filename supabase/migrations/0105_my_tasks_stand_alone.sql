-- المهام لي، والملف يصف عمله ولا يتعقبه.
--
-- 0083 built a board inside every operational file: duties from a standing
-- catalog plus duties written on the file, each carrying a state, a note and
-- evidence, keyed per scope and per place. Living with it showed two things.
--
-- First: nobody writes a catalog. The Administration does not sit down in
-- الرياض and enumerate the standing duties of every post of every type of file
-- — the duties are written by hand, in season, on the file they belong to. A
-- catalog that is always empty is not a feature, it is a promise the screen
-- keeps making and the data keeps breaking. It goes, wholly: the type's tasks,
-- the stages that grouped them, and the menu lists that were handed out from
-- them one by one (`tasks_are_assigned`, 0027).
--
-- Second: the file does not want a tracker. What a file needs to say is what
-- the work IS — the duties of the whole file, which its members divide among
-- themselves standing in the corridor, and the duties of a post, which whoever
-- holds it carries. Nobody in the field ticks these; the paperwork of ticking
-- them was theatre. So `module_tasks` stays, but as DESCRIPTION: two scopes
-- (file, role), a title, nothing to press. The states, their evidence and the
-- board RPC go.
--
-- What people actually track is their own list. So tracking moves to where the
-- person is, the way check-in moved to where the place is (0098): a standalone
-- table, no season, no file —
--
--   personal_tasks   one row, one man's duty. Written by the man himself, in
--                    which case it is entirely his — edit, delete, state,
--                    evidence; or written FOR him by whoever holds the new
--                    `tasks.assign`, in which case the only thing he may do to
--                    it is say how it is going.
--
-- The distinction is one comparison: `created_by = profile_id` is mine,
-- anything else was assigned. No scope column, no shape constraint — the shape
-- IS the two columns.

-- ================================================= 1. the enum sheds its home

-- Three states, unchanged since 0083 — but they no longer belong to modules.
do $$
begin
  if exists (select 1 from pg_type where typname = 'module_task_state') then
    alter type module_task_state rename to task_state;
  end if;
end
$$;

-- ========================================================== 2. the new table

create table if not exists personal_tasks (
  id uuid primary key default gen_random_uuid(),

  -- Whose list it sits on.
  profile_id uuid not null references profiles (id) on delete cascade,

  -- Who wrote it. Equal to profile_id for a man's own note to himself — the
  -- common case, and the one with full control. Different for an assignment.
  created_by uuid not null references profiles (id) on delete cascade,

  -- One language, whichever the writer was thinking in. This is a private
  -- list, not the Administration's paperwork; nobody translates his own
  -- reminders.
  title text not null,
  description text,

  due_on date,

  -- On the row itself, not in a side table: a personal task IS its state row.
  -- The five-part key of 0083 existed because one definition was answered in
  -- many places; here every task is answered exactly once, by its owner.
  state task_state not null default 'not_started',

  -- What the owner wanted to say about how it is going.
  note text,

  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references profiles (id)
);

create index if not exists idx_personal_tasks_profile
  on personal_tasks (profile_id);
create index if not exists idx_personal_tasks_author
  on personal_tasks (created_by) where created_by <> profile_id;

-- Evidence. Same columns as every attachment table in this schema; what
-- differs is who may see it — a policy, not a column.
create table if not exists personal_task_attachments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references personal_tasks (id) on delete cascade,
  kind attachment_kind not null,
  -- Path inside the private `tasks` bucket: {task_id}/{i}_{file}.
  path text not null,
  name text not null,
  mime_type text,
  size_bytes bigint,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_personal_task_attachments_task
  on personal_task_attachments (task_id);

-- The clock stamps itself, so an edit by the author and a state set by the
-- owner both leave the same trace without either client remembering to.
create or replace function touch_personal_task() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;

drop trigger if exists personal_tasks_touch on personal_tasks;
create trigger personal_tasks_touch before update on personal_tasks
  for each row execute function touch_personal_task();

-- ============================================================ 3. the grant

-- A new section: this system has no relation to the operational files, and a
-- code under `modules.` would say that it does.
insert into permissions (code, description, sort_order)
values ('tasks', 'Personal tasks section', 15)
on conflict (code) do nothing;

-- Writing a task onto ANOTHER man's list. Not what anyone needs for his own —
-- that is not a grant at all, everyone holds it by existing.
insert into permissions (code, description, parent_id, sort_order)
select 'tasks.assign', 'Assign tasks to other people', p.id, 1
from permissions p where p.code = 'tasks'
on conflict (code) do nothing;

-- Tasks are assigned to people, so the assigner must be able to see who the
-- people are.
insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from (values ('tasks.assign', 'employees.view')) as v(code, requires_code)
join permissions c on c.code = v.code
join permissions r on r.code = v.requires_code
on conflict do nothing;

-- Handed to whoever already holds `modules.tasks` — the people who were
-- handing out personal duties under 0083, so nobody who could do this
-- yesterday finds they cannot today. (`modules.tasks` itself survives, but is
-- now only the right to write the descriptive lists on a file.)
insert into user_permissions (user_id, permission_id, granted_by)
select up.user_id, t.id, up.granted_by
from user_permissions up
join permissions p on p.id = up.permission_id and p.code = 'modules.tasks'
cross join permissions t
where t.code = 'tasks.assign'
on conflict do nothing;

-- ================================================================ 4. who may

-- Full control — edit, delete, attach, everything. The author has it; an
-- administrator has it over ASSIGNED tasks only. What a man wrote for himself
-- is his notebook, and even the administrator reads no notebooks.
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

-- Moving the state — the one thing an assignee may always do to what was
-- assigned to him, and the whole of his power over it.
create or replace function can_set_personal_task_state(p_task_id uuid)
  returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from personal_tasks t
     where t.id = p_task_id and t.profile_id = auth.uid()
  ) or can_edit_personal_task(p_task_id);
$$;

-- ==================================================================== 5. RLS

alter table personal_tasks            enable row level security;
alter table personal_task_attachments enable row level security;

-- The owner reads his list; the author follows up what he assigned; oversight
-- (`tasks.assign`, admin) reads assignments — and nobody else's private notes.
drop policy if exists personal_tasks_select on personal_tasks;
create policy personal_tasks_select on personal_tasks for select
  using (
    profile_id = auth.uid()
    or created_by = auth.uid()
    or (created_by <> profile_id
        and (is_admin() or has_permission('tasks.assign')))
  );

-- Writing onto my own list is being a person; writing onto another's is the
-- grant. `created_by` is always the caller — a row claiming another author is
-- a forged signature, whoever sends it.
drop policy if exists personal_tasks_insert on personal_tasks;
create policy personal_tasks_insert on personal_tasks for insert
  with check (
    created_by = auth.uid()
    and (profile_id = auth.uid()
         or is_admin() or has_permission('tasks.assign'))
  );

-- Direct update/delete is full control. The assignee's narrower right — state
-- and note only — goes through `set_personal_task_state`, because a policy
-- cannot see which columns changed.
drop policy if exists personal_tasks_update on personal_tasks;
create policy personal_tasks_update on personal_tasks for update
  using (can_edit_personal_task(id))
  with check (can_edit_personal_task(id));

drop policy if exists personal_tasks_delete on personal_tasks;
create policy personal_tasks_delete on personal_tasks for delete
  using (can_edit_personal_task(id));

-- Evidence is visible exactly when the task is — that row's own policy is the
-- single source of truth, so this one defers to it.
drop policy if exists personal_task_attachments_select on personal_task_attachments;
create policy personal_task_attachments_select on personal_task_attachments
  for select using (
    exists (select 1 from personal_tasks t
             where t.id = personal_task_attachments.task_id)
  );

-- Attaching evidence is part of saying how it is going, and goes with it.
drop policy if exists personal_task_attachments_write on personal_task_attachments;
create policy personal_task_attachments_write on personal_task_attachments
  for all
  using (can_set_personal_task_state(task_id))
  with check (can_set_personal_task_state(task_id));

-- ======================================================= 6. setting a state

-- The assignee's door. SECURITY DEFINER because the row policy above cannot
-- let him through — it would let him through to every column — and the check
-- is the first statement in the body with no path around it.
create or replace function set_personal_task_state(
  p_task_id uuid,
  p_state text,
  p_note text default null
) returns void
  language plpgsql security definer set search_path = public as $$
begin
  if p_state not in ('not_started', 'in_progress', 'done') then
    raise exception 'unknown state: %', p_state;
  end if;
  if not can_set_personal_task_state(p_task_id) then
    raise exception 'not allowed to set the state of this task';
  end if;

  update personal_tasks
     set state = p_state::task_state,
         note = nullif(btrim(coalesce(p_note, '')), ''),
         updated_at = now(),
         updated_by = auth.uid()
   where id = p_task_id;
end;
$$;

revoke execute on function set_personal_task_state(uuid, text, text)
  from public, anon;
grant execute on function set_personal_task_state(uuid, text, text)
  to authenticated;

-- ================================================================ 7. storage

insert into storage.buckets (id, name, public)
values ('tasks', 'tasks', false)
on conflict (id) do nothing;

-- Path convention: {task_id}/{i}_{file}. The task id is the whole address —
-- whose it is, who may see it and who may write under it are the task row's
-- business, asked through the two functions above.
create or replace function personal_task_file_id(p_path text) returns uuid
  language plpgsql stable set search_path = public, storage as $$
begin
  return (storage.foldername(p_path))[1]::uuid;
exception when others then
  return null;
end;
$$;

drop policy if exists task_files_read on storage.objects;
create policy task_files_read on storage.objects for select
  to authenticated using (
    bucket_id = 'tasks'
    and exists (
      select 1 from personal_tasks t
       where t.id = public.personal_task_file_id(name)
         and (t.profile_id = auth.uid()
              or t.created_by = auth.uid()
              or (t.created_by <> t.profile_id
                  and (public.is_admin()
                       or public.has_permission('tasks.assign'))))
    )
  );

drop policy if exists task_files_write on storage.objects;
create policy task_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'tasks'
    and public.can_set_personal_task_state(public.personal_task_file_id(name))
  );

drop policy if exists task_files_delete on storage.objects;
create policy task_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'tasks'
    and public.can_set_personal_task_state(public.personal_task_file_id(name))
  );

-- ========================================================== 8. told about it

-- An assignment nobody was told about is an assignment that does not get done.
-- Only the assigned kind notifies: a man does not need a push notification
-- about his own note to himself.
create or replace function on_personal_task_created() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
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

drop trigger if exists personal_tasks_notify on personal_tasks;
create trigger personal_tasks_notify after insert on personal_tasks
  for each row execute function on_personal_task_created();

-- ============================================= 9. what 0083 wrote, carried in

-- Personal duties written on files move to the man's own list, with whatever
-- state and note they had. Their file evidence does not follow: a storage
-- object cannot be moved between buckets from SQL, and evidence of a duty
-- being retired with its system is a record, not a loss.
--
-- Written to survive a partial earlier run: skipped entirely once
-- `module_tasks.profile_id` is gone (the rows were carried then), and run
-- without the states when the status table has already been dropped.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public'
       and table_name = 'module_tasks'
       and column_name = 'profile_id'
  ) then
    return;
  end if;

  if to_regclass('public.module_task_status') is not null then
    insert into personal_tasks
      (profile_id, created_by, title, description, due_on,
       state, note, created_at)
    select
      mt.profile_id,
      coalesce(mt.created_by, mt.profile_id),
      mt.title_ar,
      mt.description_ar,
      mt.due_on,
      coalesce(s.state, 'not_started'::task_state),
      s.note,
      mt.created_at
    from module_tasks mt
    left join module_task_status s on s.module_task_id = mt.id
    where mt.scope = 'personal';
  else
    insert into personal_tasks
      (profile_id, created_by, title, description, due_on, created_at)
    select
      mt.profile_id,
      coalesce(mt.created_by, mt.profile_id),
      mt.title_ar,
      mt.description_ar,
      mt.due_on,
      mt.created_at
    from module_tasks mt
    where mt.scope = 'personal';
  end if;

  delete from module_tasks where scope = 'personal';
end
$$;

-- ==================================== 10. the machinery of tracking, removed

-- The files first, while the rows that name them still exist. Best-effort:
-- hosted Supabase guards `storage.objects` against SQL deletes
-- (`storage.protect_delete`), and orphaned task evidence in a private bucket
-- is clutter, not a leak — the read rule that used to serve it is dropped
-- below, and what remains answers only to the module fallback. When it
-- refuses, clean the `{module_id}/tasks/…` folders from the dashboard.
do $$
begin
  delete from storage.objects
   where bucket_id = 'modules'
     and (storage.foldername(name))[2] = 'tasks';
exception when others then
  raise notice 'task evidence left in the modules bucket: %', sqlerrm;
end
$$;

-- The three storage policies go back to what 0074 had: the module's own
-- paperwork and its reports, nothing else.
drop policy if exists module_files_write on storage.objects;
create policy module_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'modules'
    and (
      public.is_admin()
      or public.has_permission('modules.edit')
      or public.can_write_module_report_file(name)
    )
  );

drop policy if exists module_files_update on storage.objects;
create policy module_files_update on storage.objects for update
  to authenticated using (
    bucket_id = 'modules'
    and (
      public.is_admin()
      or public.has_permission('modules.edit')
      or public.can_write_module_report_file(name)
    )
  );

drop policy if exists module_files_delete on storage.objects;
create policy module_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'modules'
    and (
      public.is_admin()
      or public.has_permission('modules.edit')
      or public.can_write_module_report_file(name)
    )
  );

-- Reading: 0083's version minus the task branch. The report branch and the
-- membership fallback — including 0083's fix that asks `is_module_member`
-- rather than `module_members` alone — stand.
create or replace function can_read_module_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_module_id uuid;
  v_report_id uuid;
begin
  if is_admin() or has_permission('modules.view_all') then
    return true;
  end if;

  v_report_id := module_report_file_id(p_path);
  if v_report_id is not null then
    return exists (
      select 1 from module_reports
      where id = v_report_id
        and (author_id = auth.uid() or has_permission('modules.reports'))
    );
  end if;

  begin
    v_module_id := (storage.foldername(p_path))[1]::uuid;
  exception when others then
    return false;
  end;
  return is_module_member(v_module_id);
end;
$$;

drop function if exists can_write_module_task_file(text);
drop function if exists module_task_file_id(text);
drop function if exists is_module_task_file(text);

-- The state rows and their evidence rows — before the functions, because the
-- tables' own policies name them and would block the drop.
drop table if exists module_task_attachments;
drop table if exists module_task_status;

-- The board, the state writer, and every helper only they asked.
drop function if exists module_task_board(uuid, uuid, boolean);
drop function if exists set_module_task_state(uuid, text, uuid, uuid, uuid, uuid, text);
drop function if exists can_write_module_task_status(uuid);
drop function if exists can_set_module_task_state(uuid, uuid, uuid, uuid, uuid);
drop function if exists module_task_shape(uuid, uuid);
drop function if exists holds_module_role(uuid, uuid, uuid);

-- The trigger that notified personal duties on files — the scope is gone.
drop trigger if exists module_tasks_notify on module_tasks;
drop function if exists on_module_task_created();

-- ============================================ 11. the catalog, removed whole

-- The menu lists first — they reference the catalog.
drop table if exists module_assigned_tasks;

-- The stage column on file tasks referenced the groups; both go.
alter table module_tasks drop column if exists group_id;
drop table if exists module_type_tasks;
drop table if exists module_type_task_groups;

alter table module_type_roles drop column if exists tasks_are_assigned;

-- ======================================= 12. what remains on a file: a list

-- The 0083 select policy carved out the personal scope by naming the man; it
-- is restated without either — a file's descriptive lists are the file's
-- business and every member reads them all — because a policy that names a
-- column blocks that column's drop.
drop policy if exists module_tasks_select on module_tasks;
create policy module_tasks_select on module_tasks for select
  using (
    is_admin()
    or has_permission('modules.view_all')
    or is_module_member(module_id)
  );

-- Two scopes. The old constraint named three; the personal rows are gone and
-- the column that carried them goes with the constraint that shaped it.
alter table module_tasks drop constraint if exists module_task_scope_shape;
alter table module_tasks drop column if exists profile_id;
alter table module_tasks add constraint module_task_scope_shape check (
  case scope
    when 'file' then role_id is null
    when 'role' then role_id is not null
    else false
  end
);

-- ============================================================== 13. the log

do $$
declare t text;
begin
  foreach t in array array['personal_tasks', 'personal_task_attachments'] loop
    execute format('drop trigger if exists audit_row on %I', t);
    execute format(
      'create trigger audit_row after insert or update or delete on %I '
      'for each row execute function audit_row_change()', t);
  end loop;
end
$$;

-- Restated whole, on top of 0098's version: the body is one CASE and Postgres
-- has no way to add an arm to it. One new arm — a personal task reads as its
-- title and the man it belongs to, which is the fact somebody auditing an
-- assignment is after. (The attachments need no arm: the generic `name`
-- fallback already reads them.)
create or replace function audit_record_label(p_table text, p_row jsonb)
  returns text
  language plpgsql stable security definer set search_path = public as $$
declare
  v text;
begin
  v := case p_table
    when 'profiles' then
      nullif(concat_ws(' ', p_row ->> 'first_name', p_row ->> 'father_name',
                            p_row ->> 'surname'), '')
    when 'user_permissions' then
      concat_ws(' — ',
        audit_actor_name((p_row ->> 'user_id')::uuid),
        (select code from permissions where id = (p_row ->> 'permission_id')::uuid))
    when 'season_participants' then
      audit_actor_name((p_row ->> 'profile_id')::uuid)
    when 'seasons' then
      (p_row ->> 'hijri_year')
    when 'modules' then
      (select mt.name_ar from module_types mt
        where mt.id = (p_row ->> 'module_type_id')::uuid)
    when 'module_members' then
      audit_actor_name((p_row ->> 'profile_id')::uuid)
    when 'module_node_members' then
      concat_ws(' — ',
        audit_actor_name((p_row ->> 'profile_id')::uuid),
        (select label from module_nodes where id = (p_row ->> 'node_id')::uuid))
    when 'module_nodes' then
      (p_row ->> 'label')
    when 'module_ratings' then
      audit_actor_name((p_row ->> 'ratee_id')::uuid)
    when 'module_reports' then
      (select mt.name_ar
         from modules m
         join module_types mt on mt.id = m.module_type_id
        where m.id = (p_row ->> 'module_id')::uuid)
    when 'place_codes' then
      (select ri.name_ar from reference_items ri
        where ri.id = (p_row ->> 'item_id')::uuid)
    when 'personal_tasks' then
      concat_ws(' — ',
        p_row ->> 'title',
        audit_actor_name((p_row ->> 'profile_id')::uuid))
    else null
  end;

  return coalesce(v,
    p_row ->> 'name_ar', p_row ->> 'title', p_row ->> 'name',
    p_row ->> 'label', p_row ->> 'code', p_row ->> 'email');
exception when others then
  return null;
end;
$$;
