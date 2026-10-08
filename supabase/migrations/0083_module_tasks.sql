-- A duty belongs to the work, not to the man doing it.
--
-- Until now every task in this app was reached THROUGH a person. The catalog
-- had duties on roles (0017) and duties on the type (0028), but the only way
-- either appeared on a screen was: open a file, find a member, read what he
-- carries. `module_assigned_tasks` (0027) went further still and handed named
-- duties to a named membership — so when that man was replaced, his duties
-- were deleted with his row and the new man arrived to an empty list. The work
-- had not changed. The record of it had.
--
-- This migration inverts that. A duty now hangs off one of three things, and a
-- person is only ever the third and rarest of them:
--
--   file      duties of the whole operational file. Every member sees the same
--             list — الملف المتابعة والتقييم is nothing BUT this list.
--   role      duties of a post. Whoever holds مشرف البرج sees them because he
--             holds it; replace him and the list, and its progress, stand.
--   personal  one duty handed to one man, by exception. The escape hatch, and
--             deliberately the smallest of the three.
--
-- Two things are added to make that real:
--
--   `module_tasks`        a duty written on ONE file of ONE season, in any of
--                         the three scopes. The type catalog stays what it was
--                         — the standing duties the Administration writes once
--                         — and this is what a supervisor adds on top of it in
--                         the season he is actually running.
--
--   `module_task_status`  how a duty is GOING, which no table has ever held.
--                         Always per file, never per type: a type is reused
--                         every season and its rows would carry last year's
--                         progress into this one.
--
-- The scope of a duty decides what one status row is keyed on, and this is the
-- part worth reading twice:
--
--   a file duty      one status for the file            (node null, profile null)
--   a role duty      one status PER PLACE the role is held
--                                                       (node set, profile null)
--   a personal duty  one status for the man it names    (node null, profile set)
--
-- The middle line is the one that matters. مشرف البرج is a post held once per
-- برج: "جولة يومية على الغرف" is finished in برج الصفوة and not started in برج
-- النور, and a single shared row would have to lie about one of them. A role
-- held on the file itself — a team, a roster — has no place under it, so its
-- node is null and the file is the place.
--
-- `module_assigned_tasks` is left standing and untouched. It answers a
-- different question — which of a MENU of duties a particular member was handed
-- — and الطوافة والنقل is built on it. What changes is that it is no longer the
-- only way a duty reaches a screen.

-- ================================================================== 1. enums

do $$
begin
  if not exists (select 1 from pg_type where typname = 'module_task_scope') then
    create type module_task_scope as enum ('file', 'role', 'personal');
  end if;
  if not exists (select 1 from pg_type where typname = 'module_task_state') then
    -- Three, not two. "قيد التنفيذ" is the state most duties in a season spend
    -- most of their life in, and a checkbox that cannot say it forces the man
    -- holding it to choose between claiming he has finished and claiming he has
    -- not started.
    create type module_task_state as enum ('not_started', 'in_progress', 'done');
  end if;
end
$$;

-- ====================================================== 2. duties of one file

-- A duty written on one file of one season.
--
-- The type catalog answers "what does this kind of file always require"; this
-- answers "what did this file turn out to require". Both are read together and
-- neither replaces the other — which is why this table does not copy the
-- catalog's rows, it sits beside them.
create table if not exists module_tasks (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules (id) on delete cascade,
  scope module_task_scope not null,

  -- Set for a role duty: the post it belongs to. Any role of the file's type,
  -- held on the file or at a level — the status rows below are what tell the
  -- two apart, not this column.
  role_id uuid references module_type_roles (id) on delete cascade,

  -- Set for a personal duty: the one man it was written for.
  profile_id uuid references profiles (id) on delete cascade,

  -- The stage of the work, borrowed from the type's own stages (0028) so an
  -- added duty files under التخطيط والإعداد beside the standing ones rather
  -- than in a heap at the end. Null is fine and common.
  group_id uuid references module_type_task_groups (id) on delete set null,

  title_ar text not null,
  -- Nullable, unlike the catalog's: the Administration writes the catalog in
  -- both languages once, and a supervisor adding a duty at 2am in Mina writes
  -- it in the one he is thinking in. [LocalizedName] falls back to Arabic.
  title_en text,
  description_ar text,
  description_en text,

  -- When it is wanted by. Null for a duty with no date on it, which is most.
  due_on date,

  sort_order int not null default 0,
  created_by uuid references profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- A duty belongs to exactly what its scope says it belongs to. Never a role
  -- duty with a man's name on it, never a personal duty with no man.
  constraint module_task_scope_shape check (
    case scope
      when 'file'     then role_id is null     and profile_id is null
      when 'role'     then role_id is not null and profile_id is null
      when 'personal' then profile_id is not null and role_id is null
    end
  )
);

create index if not exists idx_module_tasks_module on module_tasks (module_id);
create index if not exists idx_module_tasks_role on module_tasks (role_id)
  where role_id is not null;
create index if not exists idx_module_tasks_profile on module_tasks (profile_id)
  where profile_id is not null;

-- ============================================================ 3. how it goes

-- The state of one duty, in one file, at one place.
--
-- A duty with no row here is `not_started` — the absence IS the state, so a
-- file of two hundred duties costs two hundred rows only once somebody has
-- actually touched them.
create table if not exists module_task_status (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules (id) on delete cascade,

  -- WHICH duty: one from the type's catalog, or one written on this file.
  -- Exactly one, the same way `module_assigned_tasks` names exactly one kind
  -- of membership.
  type_task_id uuid references module_type_tasks (id) on delete cascade,
  module_task_id uuid references module_tasks (id) on delete cascade,

  -- WHERE, for a role duty: the برج or القطاع the post is held at. Null for a
  -- role held on the file itself, and for the other two scopes.
  node_id uuid references module_nodes (id) on delete cascade,

  -- WHO, for a personal duty. Null for the other two.
  profile_id uuid references profiles (id) on delete cascade,

  state module_task_state not null default 'not_started',

  -- What the man wanted to say about it — "الغرف ٤٠١ و٤٠٢ مغلقة". Optional and
  -- usually empty; the state is the answer and this is the exception to it.
  note text,

  updated_by uuid references profiles (id),
  updated_at timestamptz not null default now(),

  constraint task_status_names_one_task
    check (num_nonnulls(type_task_id, module_task_id) = 1),
  -- A place and a person are never both the key: the first is a role duty and
  -- the second is a personal one, and nothing is both.
  constraint task_status_scope_shape
    check (num_nonnulls(node_id, profile_id) <= 1)
);

-- One state per duty per place. Written out with coalesce rather than as a
-- plain unique because four of the five columns are nullable, and in Postgres
-- a null never collides with a null — a plain unique here would let the same
-- file duty be given a state twice and mean it.
create unique index if not exists uq_module_task_status on module_task_status (
  module_id,
  coalesce(type_task_id,   '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(module_task_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(node_id,        '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(profile_id,     '00000000-0000-0000-0000-000000000000'::uuid)
);

create index if not exists idx_module_task_status_module
  on module_task_status (module_id);
create index if not exists idx_module_task_status_profile
  on module_task_status (profile_id) where profile_id is not null;

-- Evidence. Same columns as `module_report_attachments` (0045) and for the
-- same reason: an attachment is an attachment, the app draws both with one
-- widget, and what differs between them is who may see it — a policy, not a
-- column.
create table if not exists module_task_attachments (
  id uuid primary key default gen_random_uuid(),
  status_id uuid not null
    references module_task_status (id) on delete cascade,
  kind attachment_kind not null,
  -- Path inside the private `modules` bucket:
  -- {module_id}/tasks/{status_id}/{file}. Under the module, beside the
  -- reports, so one bucket policy still governs everything a file owns.
  path text not null,
  name text not null,
  mime_type text,
  size_bytes bigint,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_module_task_attachments_status
  on module_task_attachments (status_id);

-- ============================================================ 4. permission

-- Writing duties onto a file, and setting the state of any of them anywhere in
-- it. NOT the permission an ordinary member needs to tick off his own work —
-- that is not a grant at all, it is membership, and it is decided in
-- `can_set_module_task_state` below.
--
-- Its own code rather than folded into `modules.edit`: editing a file is its
-- dates, its decision number and its tree, and handing a man a duty by name is
-- a different act by a different person at a different time.
insert into permissions (code, description, parent_id, sort_order)
select 'modules.tasks', 'Write file duties and set any state', p.id, 8
from permissions p where p.code = 'modules'
on conflict (code) do nothing;

-- Duties are written against a roster, and a roster is people: whoever may
-- hand a duty to a named man has to be able to see who the men are.
insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from (values
  ('modules.tasks', 'modules.view_all'),
  ('modules.tasks', 'employees.view')
) as v(code, requires_code)
join permissions c on c.code = v.code
join permissions r on r.code = v.requires_code
on conflict do nothing;

-- Handed to whoever already holds `modules.members` — the people who assign
-- postings and hand out duties, which is exactly the population this code
-- describes. So nobody who could do this yesterday finds they cannot today.
--
-- That code, and not `modules.edit`: the prerequisite trigger above refuses a
-- grant whose ground is missing, and `modules.members` is the one that already
-- requires BOTH `modules.view_all` and `employees.view` (0073).
insert into user_permissions (user_id, permission_id, granted_by)
select up.user_id, t.id, up.granted_by
from user_permissions up
join permissions p on p.id = up.permission_id and p.code = 'modules.members'
cross join permissions t
where t.code = 'modules.tasks'
on conflict do nothing;

-- ================================================================= 5. who may

-- Whether the caller holds [p_role_id] in this file, at [p_node_id] when one
-- is named and on the file itself when it is not.
--
-- This one function is the whole of "a duty belongs to the post": nothing
-- anywhere asks whose name is on a task, only whether the man asking is
-- standing in the post the task was written for.
create or replace function holds_module_role(
  p_module_id uuid,
  p_role_id uuid,
  p_node_id uuid default null
) returns boolean
  language sql stable security definer set search_path = public as $$
  select case
    when p_node_id is not null then exists (
      select 1
        from module_node_members m
        join module_nodes n on n.id = m.node_id
       where m.node_id = p_node_id
         and m.role_id = p_role_id
         and m.profile_id = auth.uid()
         and n.module_id = p_module_id
    )
    else exists (
      select 1 from module_members m
       where m.module_id = p_module_id
         and m.role_id = p_role_id
         and m.profile_id = auth.uid()
    )
  end;
$$;

-- What a duty is, whichever table it came from: its scope, the post it belongs
-- to, and the man it names. One place so the policies, the state RPC and the
-- board query below cannot drift apart on it.
create or replace function module_task_shape(
  p_type_task_id uuid,
  p_module_task_id uuid
) returns table (scope module_task_scope, role_id uuid, profile_id uuid)
  language sql stable security definer set search_path = public as $$
  select
    -- A catalog duty carries its scope in which column is filled: a role, or
    -- the type itself, and never both (constraint `task_belongs_to_role_or_type`).
    case when t.role_id is not null then 'role' else 'file' end::module_task_scope,
    t.role_id,
    null::uuid
  from module_type_tasks t
  where p_type_task_id is not null and t.id = p_type_task_id
  union all
  select m.scope, m.role_id, m.profile_id
  from module_tasks m
  where p_module_task_id is not null and m.id = p_module_task_id;
$$;

-- Whether the caller may set the state of this duty, at this place, for this
-- man. The three scopes, in the order they are common:
--
--   file      any member of the file. That is the point of a file duty — the
--             list is the team's, and whoever gets to it first ticks it.
--   role      whoever holds the post, at the place named. A tower supervisor
--             may finish his own tower and nobody else's.
--   personal  the man it was written for, and nobody else.
--
-- Over all three: an administrator, and whoever holds `modules.tasks`.
create or replace function can_set_module_task_state(
  p_module_id uuid,
  p_type_task_id uuid,
  p_module_task_id uuid,
  p_node_id uuid default null,
  p_profile_id uuid default null
) returns boolean
  language plpgsql stable security definer set search_path = public as $$
declare
  v record;
begin
  if is_admin() or has_permission('modules.tasks') then
    return true;
  end if;
  if not is_module_member(p_module_id) then
    return false;
  end if;

  select * into v from module_task_shape(p_type_task_id, p_module_task_id);
  if not found then
    return false;
  end if;

  -- Coalesced, and this is not defensive tidiness: `p_profile_id = auth.uid()`
  -- is NULL when either side is, and a NULL returned from here would sail
  -- straight through the `if not …` that guards the write below.
  return coalesce(case v.scope
    when 'file'     then p_node_id is null and p_profile_id is null
    when 'role'     then p_profile_id is null
                         and holds_module_role(p_module_id, v.role_id, p_node_id)
    when 'personal' then p_node_id is null
                         and p_profile_id = auth.uid()
                         and v.profile_id = auth.uid()
  end, false);
end;
$$;

-- The same question asked of a state row that already exists — what the
-- attachment policy and the storage policy need, since both are handed a
-- status id rather than the five parts it was keyed on.
create or replace function can_write_module_task_status(p_status_id uuid)
  returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from module_task_status s
     where s.id = p_status_id
       and can_set_module_task_state(
             s.module_id, s.type_task_id, s.module_task_id,
             s.node_id, s.profile_id)
  );
$$;

-- ==================================================================== 6. RLS

alter table module_tasks            enable row level security;
alter table module_task_status      enable row level security;
alter table module_task_attachments enable row level security;

-- A file duty and a role duty are the file's business and every member reads
-- them. A personal duty is between the man and whoever wrote it — which is the
-- one line that makes "لا تظهر إلا لذلك المستخدم" true rather than merely
-- unimplemented in the app.
drop policy if exists module_tasks_select on module_tasks;
create policy module_tasks_select on module_tasks for select
  using (
    is_admin()
    or has_permission('modules.view_all')
    or (
      is_module_member(module_id)
      and (scope <> 'personal' or profile_id = auth.uid())
    )
  );

-- Writing a duty onto a file is administration, not membership: a tower
-- supervisor may finish duties, never invent them.
drop policy if exists module_tasks_write on module_tasks;
create policy module_tasks_write on module_tasks for all
  using (is_admin() or has_permission('modules.tasks'))
  with check (is_admin() or has_permission('modules.tasks'));

-- A state follows the duty it belongs to: readable by the file, except the
-- personal ones, which are readable by the man they name.
drop policy if exists module_task_status_select on module_task_status;
create policy module_task_status_select on module_task_status for select
  using (
    is_admin()
    or has_permission('modules.view_all')
    or (
      is_module_member(module_id)
      and (profile_id is null or profile_id = auth.uid())
    )
  );

-- Direct writes are for managers only. An ordinary member goes through
-- `set_module_task_state`, which decides scope by scope who he is — a rule too
-- long to restate in a policy without the two falling out of step.
drop policy if exists module_task_status_write on module_task_status;
create policy module_task_status_write on module_task_status for all
  using (is_admin() or has_permission('modules.tasks'))
  with check (is_admin() or has_permission('modules.tasks'));

-- Evidence is visible exactly when the state it hangs off is — that row's own
-- policy is the single source of truth, so this one defers to it.
drop policy if exists module_task_attachments_select on module_task_attachments;
create policy module_task_attachments_select on module_task_attachments
  for select using (
    exists (select 1 from module_task_status s
             where s.id = module_task_attachments.status_id)
  );

-- Attaching is part of setting the state, and goes with it.
drop policy if exists module_task_attachments_write on module_task_attachments;
create policy module_task_attachments_write on module_task_attachments
  for all
  using (can_write_module_task_status(status_id))
  with check (can_write_module_task_status(status_id));

-- ================================================================ 7. storage

-- True for {module_id}/tasks/{status_id}/..., the second shape of path in this
-- bucket that is not the module's own paperwork.
create or replace function is_module_task_file(p_path text) returns boolean
  language sql stable set search_path = public, storage as $$
  select array_length(storage.foldername(p_path), 1) >= 3
     and (storage.foldername(p_path))[2] = 'tasks';
$$;

create or replace function module_task_file_id(p_path text) returns uuid
  language plpgsql stable set search_path = public, storage as $$
begin
  if not is_module_task_file(p_path) then
    return null;
  end if;
  return (storage.foldername(p_path))[3]::uuid;
exception when others then
  return null;
end;
$$;

create or replace function can_write_module_task_file(p_path text)
  returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_status_id uuid;
begin
  v_status_id := module_task_file_id(p_path);
  if v_status_id is null then
    return false;
  end if;
  return exists (
    select 1 from module_task_status s
     where s.id = v_status_id
       and (storage.foldername(p_path))[1] = s.module_id::text
       and can_write_module_task_status(s.id)
  );
end;
$$;

-- Reading. Two changes to the function 0073 left standing:
--
--   * a task's evidence follows the state row — which for a personal duty is
--     the man it names, and for the other two is the file;
--   * the fallback stops asking `module_members` directly and asks
--     `is_module_member`, which has known about the tree since 0024. As it
--     stood, a tower supervisor — who has no `module_members` row at all,
--     only a `module_node_members` one — could not open his own file's PDF.
create or replace function can_read_module_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_module_id uuid;
  v_report_id uuid;
  v_status_id uuid;
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

  v_status_id := module_task_file_id(p_path);
  if v_status_id is not null then
    return exists (
      select 1 from module_task_status s
       where s.id = v_status_id
         and is_module_member(s.module_id)
         and (s.profile_id is null or s.profile_id = auth.uid())
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

-- Writing. The three policies gain the task path, alongside the report path
-- they already carried.
drop policy if exists module_files_write on storage.objects;
create policy module_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'modules'
    and (
      public.is_admin()
      or public.has_permission('modules.edit')
      or public.can_write_module_report_file(name)
      or public.can_write_module_task_file(name)
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
      or public.can_write_module_task_file(name)
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
      or public.can_write_module_task_file(name)
    )
  );

-- ========================================================= 8. setting a state

-- Sets — or clears — the state of one duty, and returns the id of the row that
-- holds it, so the caller can store its evidence underneath.
--
-- SECURITY DEFINER for the reason `submit_module_report` is: the rule for who
-- may do this is three rules, one per scope, and an ordinary member satisfies
-- it by membership rather than by grant. The check is the first statement in
-- the body and there is no path around it.
-- [p_state] is text rather than the enum: the app sends it over PostgREST as a
-- string either way, and taking it as text lets a value that is not one of the
-- three fail with a sentence rather than as a cast error from inside the body.
create or replace function set_module_task_state(
  p_module_id uuid,
  p_state text,
  p_type_task_id uuid default null,
  p_module_task_id uuid default null,
  p_node_id uuid default null,
  p_profile_id uuid default null,
  p_note text default null
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_state module_task_state;
begin
  if p_state not in ('not_started', 'in_progress', 'done') then
    raise exception 'unknown state: %', p_state;
  end if;
  v_state := p_state::module_task_state;

  if not can_set_module_task_state(
       p_module_id, p_type_task_id, p_module_task_id, p_node_id, p_profile_id)
  then
    raise exception 'not allowed to set the state of this duty';
  end if;

  -- The duty has to belong to the file it is being marked in. Without this a
  -- caller could name a duty from another type's catalog and open a row that
  -- no board would ever read but the log would carry forever.
  if p_type_task_id is not null and not exists (
    select 1
      from module_type_tasks t
      left join module_type_roles r on r.id = t.role_id
      join modules m on m.id = p_module_id
     where t.id = p_type_task_id
       and coalesce(t.module_type_id, r.module_type_id) = m.module_type_id
  ) then
    raise exception 'this duty does not belong to this file';
  end if;

  if p_module_task_id is not null and not exists (
    select 1 from module_tasks
     where id = p_module_task_id and module_id = p_module_id
  ) then
    raise exception 'this duty does not belong to this file';
  end if;

  -- Update-then-insert rather than ON CONFLICT, for the reason the unique
  -- index above is written in coalesce: the conflict target would have to
  -- restate that whole expression list, and `is not distinct from` says the
  -- same thing in a form a reader can check.
  update module_task_status
     set state = v_state,
         note = nullif(btrim(coalesce(p_note, '')), ''),
         updated_by = auth.uid(),
         updated_at = now()
   where module_id = p_module_id
     and type_task_id is not distinct from p_type_task_id
     and module_task_id is not distinct from p_module_task_id
     and node_id is not distinct from p_node_id
     and profile_id is not distinct from p_profile_id
  returning id into v_id;

  if v_id is null then
    insert into module_task_status (
      module_id, type_task_id, module_task_id, node_id, profile_id,
      state, note, updated_by, updated_at)
    values (
      p_module_id, p_type_task_id, p_module_task_id, p_node_id, p_profile_id,
      v_state, nullif(btrim(coalesce(p_note, '')), ''), auth.uid(), now())
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

revoke execute on function set_module_task_state(
  uuid, text, uuid, uuid, uuid, uuid, text) from public, anon;
grant execute on function set_module_task_state(
  uuid, text, uuid, uuid, uuid, uuid, text) to authenticated;

-- ============================================================== 9. the board

-- Everything one man should see when he opens a file, in the order he should
-- see it: the file's duties, then his post's, then his own.
--
-- Assembled here rather than in the app because the middle line cannot be
-- assembled anywhere else. "The duties of my role" means: for each post I hold,
-- at each برج I hold it in, the standing duties of that post — and a client
-- would have to fetch the roster, the tree, the catalog and the states and join
-- four ways to work it out, in a file with three hundred postings.
--
-- [p_all] widens it to the whole file: every role duty at every place somebody
-- holds it, and everyone's personal duties. For whoever runs the file — the
-- oversight the three-level split exists to make possible. RLS still applies:
-- asking for everything gets a member exactly what he could see anyway.
create or replace function module_task_board(
  p_module_id uuid,
  p_profile_id uuid default null,
  p_all boolean default false
) returns table (
  status_id uuid,
  type_task_id uuid,
  module_task_id uuid,
  scope module_task_scope,
  role_id uuid,
  node_id uuid,
  profile_id uuid,
  group_id uuid,
  title_ar text,
  title_en text,
  description_ar text,
  description_en text,
  due_on date,
  sort_order int,
  state module_task_state,
  note text,
  updated_by uuid,
  updated_by_name text,
  updated_at timestamptz,
  can_update boolean
)
  language plpgsql stable security definer set search_path = public as $$
-- Every column this function selects — `scope`, `state`, `note`, `role_id`,
-- `sort_order` and the rest — is also one of its OUT parameters, and plpgsql
-- would rather refuse an unqualified reference than guess which was meant. Each
-- of them IS the column here; the locals are all `v_`/`p_` and collide with
-- nothing.
#variable_conflict use_column
declare
  v_who uuid := coalesce(p_profile_id, auth.uid());
  v_type uuid;
  v_all boolean;
  v_manage boolean := is_admin() or has_permission('modules.tasks');
  v_member boolean := is_module_member(p_module_id);
begin
  -- The caller must be able to see the file at all. Everything below reads
  -- through SECURITY DEFINER, so this stands in for the RLS it bypasses.
  if not (is_admin() or has_permission('modules.view_all') or v_member) then
    return;
  end if;

  select module_type_id into v_type from modules where id = p_module_id;
  if v_type is null then
    return;
  end if;

  -- Reading somebody else's board is itself an oversight act, and goes with
  -- the same grant that widens it.
  v_all := coalesce(p_all, false)
           and (is_admin() or has_permission('modules.view_all'));
  if v_who <> auth.uid()
     and not (is_admin() or has_permission('modules.view_all')) then
    return;
  end if;

  return query
  with
  -- Every place a role duty could be answered for: each post, and each برج or
  -- قطاع it is held at. A post held on the file itself contributes one row with
  -- no place — the file IS the place.
  holdings as (
    select m.role_id, null::uuid as node_id
      from module_members m
     where m.module_id = p_module_id
       and (v_all or m.profile_id = v_who)
    union
    select nm.role_id, nm.node_id
      from module_node_members nm
      join module_nodes n on n.id = nm.node_id
     where n.module_id = p_module_id
       and (v_all or nm.profile_id = v_who)
  ),
  -- The same, always for the CALLER — which is a different man from [v_who]
  -- whenever somebody is reading a colleague's board. What appears on the
  -- screen is v_who's; what may be TOUCHED on it is the reader's.
  mine as (
    select m.role_id, null::uuid as node_id
      from module_members m
     where m.module_id = p_module_id and m.profile_id = auth.uid()
    union
    select nm.role_id, nm.node_id
      from module_node_members nm
      join module_nodes n on n.id = nm.node_id
     where n.module_id = p_module_id and nm.profile_id = auth.uid()
  ),
  -- The two sources of a duty, flattened into one shape. The first six columns
  -- are what a state row is keyed on; the rest is what the card draws.
  defs as (
    -- Catalog: duties of the file itself.
    select t.id as type_task_id, null::uuid as module_task_id,
           'file'::module_task_scope as scope, null::uuid as role_id,
           null::uuid as node_id, null::uuid as profile_id,
           t.group_id, t.title_ar, t.title_en,
           t.description_ar, t.description_en, null::date as due_on,
           t.sort_order
      from module_type_tasks t
     where t.module_type_id = v_type
    union all
    -- Catalog: duties of a post, once per place it is held at.
    --
    -- A post whose list is a MENU (`tasks_are_assigned`, 0027) is left out:
    -- there the list is not the post's duties, it is what may be handed to a
    -- holder of it one by one, and `module_assigned_tasks` already answers who
    -- got what. Showing the whole menu as "my role's duties" would tell every
    -- man on the الطوافة team that all thirteen are his.
    select t.id, null::uuid,
           'role'::module_task_scope, r.id,
           h.node_id, null::uuid,
           t.group_id, t.title_ar, t.title_en,
           t.description_ar, t.description_en, null::date,
           t.sort_order
      from module_type_tasks t
      join module_type_roles r on r.id = t.role_id
      join holdings h on h.role_id = r.id
     where r.module_type_id = v_type
       and not r.tasks_are_assigned
    union all
    -- Written on this file: a file duty.
    select null::uuid, mt.id,
           'file'::module_task_scope, null::uuid,
           null::uuid, null::uuid,
           mt.group_id, mt.title_ar, mt.title_en,
           mt.description_ar, mt.description_en, mt.due_on,
           mt.sort_order
      from module_tasks mt
     where mt.module_id = p_module_id and mt.scope = 'file'
    union all
    -- Written on this file: a role duty, once per place, exactly like the
    -- catalog's.
    select null::uuid, mt.id,
           'role'::module_task_scope, mt.role_id,
           h.node_id, null::uuid,
           mt.group_id, mt.title_ar, mt.title_en,
           mt.description_ar, mt.description_en, mt.due_on,
           mt.sort_order
      from module_tasks mt
      join holdings h on h.role_id = mt.role_id
     where mt.module_id = p_module_id and mt.scope = 'role'
    union all
    -- Written on this file: a personal duty.
    select null::uuid, mt.id,
           'personal'::module_task_scope, null::uuid,
           null::uuid, mt.profile_id,
           mt.group_id, mt.title_ar, mt.title_en,
           mt.description_ar, mt.description_en, mt.due_on,
           mt.sort_order
      from module_tasks mt
     where mt.module_id = p_module_id
       and mt.scope = 'personal'
       and (v_all or mt.profile_id = v_who)
  )
  select
    s.id,
    d.type_task_id,
    d.module_task_id,
    d.scope,
    d.role_id,
    d.node_id,
    d.profile_id,
    d.group_id,
    d.title_ar,
    d.title_en,
    d.description_ar,
    d.description_en,
    d.due_on,
    d.sort_order,
    coalesce(s.state, 'not_started'::module_task_state),
    s.note,
    s.updated_by,
    audit_actor_name(s.updated_by),
    s.updated_at,
    -- The same three rules `can_set_module_task_state` states, in SQL because
    -- this runs once per line on a board that can hold hundreds and each call
    -- of that function is four `exists` of its own.
    coalesce(case
      when v_manage then true
      when d.scope = 'file' then v_member
      when d.scope = 'role' then exists (
        select 1 from mine mh
         where mh.role_id = d.role_id
           and mh.node_id is not distinct from d.node_id)
      when d.scope = 'personal' then d.profile_id = auth.uid()
    end, false)
  from defs d
  left join module_task_status s
    on s.module_id = p_module_id
   and s.type_task_id is not distinct from d.type_task_id
   and s.module_task_id is not distinct from d.module_task_id
   and s.node_id is not distinct from d.node_id
   and s.profile_id is not distinct from d.profile_id
  -- File duties first, then the post's, then the man's own — the order the
  -- screen reads in, decided here so every caller gets the same one.
  order by
    case d.scope when 'file' then 0 when 'role' then 1 else 2 end,
    d.sort_order,
    d.title_ar;
end;
$$;

revoke execute on function module_task_board(uuid, uuid, boolean) from public, anon;
grant execute on function module_task_board(uuid, uuid, boolean) to authenticated;

-- ====================================================== 10. a duty by name

-- A personal duty is an exception, and an exception nobody was told about is
-- an exception that does not get done. Only the personal scope notifies: a file
-- duty and a role duty arrive with the posting, and telling three hundred
-- people that a nineteenth duty was added to their file is how an inbox stops
-- being read.
create or replace function on_module_task_created() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_type_name text;
begin
  if new.scope <> 'personal' or new.profile_id is null then
    return new;
  end if;
  -- Only for a file its members can actually open.
  if not exists (select 1 from modules where id = new.module_id and is_active) then
    return new;
  end if;

  select mt.name_ar into v_type_name
    from modules m join module_types mt on mt.id = m.module_type_id
   where m.id = new.module_id;

  insert into notifications (recipient_id, sender_id, title, body, data)
  values (
    new.profile_id,
    auth.uid(),
    'أُسندت إليك مهمة',
    concat_ws(' — ', v_type_name, new.title_ar),
    jsonb_build_object(
      'type', 'module_task_assigned',
      'module_id', new.module_id,
      'task_id', new.id
    )
  );
  return new;
end;
$$;

drop trigger if exists module_tasks_notify on module_tasks;
create trigger module_tasks_notify after insert on module_tasks
  for each row execute function on_module_task_created();

-- =============================================================== 11. the log

-- 0077 attaches its trigger to every table that existed when it ran, and says
-- in as many words that a table created afterwards starts unaudited. These
-- three are created afterwards.
do $$
declare t text;
begin
  foreach t in array array[
    'module_tasks', 'module_task_status', 'module_task_attachments'
  ] loop
    execute format('drop trigger if exists audit_row on %I', t);
    execute format(
      'create trigger audit_row after insert or update or delete on %I '
      'for each row execute function audit_row_change()', t);
  end loop;
end
$$;

-- And a line in the log should say WHICH duty, not a uuid.
--
-- Restated whole, on top of 0079's version: the body is one CASE and Postgres
-- has no way to add an arm to it. The three new arms are at the bottom.
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
    when 'complaints' then
      nullif(p_row ->> 'target_label', '')
    when 'complaint_replies' then
      (select nullif(c.target_label, '') from complaints c
        where c.id = (p_row ->> 'complaint_id')::uuid)
    when 'complaint_attachments' then
      (select nullif(c.target_label, '') from complaints c
        where c.id = (p_row ->> 'complaint_id')::uuid)
    -- A duty added to a file reads as its title, and a personal one names the
    -- man it was written for — which is the fact somebody auditing it is after.
    when 'module_tasks' then
      concat_ws(' — ',
        p_row ->> 'title_ar',
        audit_actor_name(nullif(p_row ->> 'profile_id', '')::uuid))
    when 'module_task_status' then
      concat_ws(' — ',
        coalesce(
          (select t.title_ar from module_type_tasks t
            where t.id = nullif(p_row ->> 'type_task_id', '')::uuid),
          (select t.title_ar from module_tasks t
            where t.id = nullif(p_row ->> 'module_task_id', '')::uuid)),
        p_row ->> 'state')
    when 'module_task_attachments' then
      (p_row ->> 'name')
    else null
  end;

  return coalesce(v,
    p_row ->> 'name_ar', p_row ->> 'title', p_row ->> 'name',
    p_row ->> 'label', p_row ->> 'code', p_row ->> 'email');
exception when others then
  return null;
end;
$$;
