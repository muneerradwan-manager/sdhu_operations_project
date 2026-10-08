-- The record of what happened.
--
-- Every table in this schema is written by somebody doing something on
-- purpose: approving an account, staffing a sector, switching the season,
-- correcting a phone number. Until now the row simply changed, and the change
-- kept no memory of the hand that made it. This migration gives the database a
-- memory: one `audit_log` table, and one generic trigger attached to every
-- operational table, so that no write — from the app, from an RPC, from a
-- migration seeding rows — can happen without leaving a line behind.
--
-- The trigger, not the app, is the recorder. Code in the app forgets to log
-- exactly the way code in the app forgets to validate; a trigger cannot be
-- forgotten because it is not asked. Whatever path a write takes — direct
-- PostgREST, a security-definer function, a cascade — the row trigger fires,
-- and `auth.uid()` names who was holding the pen.
--
-- What one line carries:
--   * WHO   — actor_id, and actor_name as a snapshot: people leave, their
--             profile rows go with them, and a log whose every old entry says
--             "unknown" the day someone is deleted is not a log.
--   * WHAT  — insert / update / delete (and login / logout, written by an RPC
--             the app calls, because signing in touches no table here).
--   * WHERE — the table, the row's id, and a human label for the row
--             (a person's name, a file's type, a report's title), computed at
--             write time so it survives the row's own deletion.
--   * HOW   — the full old and new images, and for updates the list of
--             columns that actually moved, so "he edited the employee" can be
--             answered down to "he changed the Saudi phone from X to Y".
--
-- Three tables are deliberately treated differently:
--   * notifications  — a broadcast writes one row per recipient; five hundred
--     identical lines say less than one line saying "sent to five hundred".
--     A statement-level trigger writes that one line.
--   * report_rows / report_blocks — save_report (0074) deletes and reinserts
--     the lot on every save; logging that churn row by row would bury the log
--     under its own detail. The save always updates the `reports` header row,
--     and THAT update is logged — as a content edit even when no header column
--     moved.
--   * device_tokens — push plumbing, not an act of anyone's will. Skipped.

-- ================================================================ 1. the table

create table if not exists audit_log (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),

  -- The FK keeps the join to the live profile cheap; SET NULL rather than
  -- CASCADE because the history of what someone did must outlive their
  -- account. The name snapshot is what still answers "who" after that.
  actor_id uuid references profiles (id) on delete set null,
  actor_name text,

  action text not null
    check (action in ('insert', 'update', 'delete', 'login', 'logout')),
  table_name text not null,
  record_id text,
  record_label text,
  old_data jsonb,
  new_data jsonb,
  changed_fields text[]
);

-- The log is read newest-first, filtered by person or by table; id is
-- monotonic so it doubles as the cursor.
create index if not exists audit_log_actor on audit_log (actor_id, id desc);
create index if not exists audit_log_table on audit_log (table_name, id desc);

alter table audit_log enable row level security;

-- Reading is its own permission. There are no write policies at all: rows
-- arrive only through the security-definer functions below (and the service
-- role in the Edge Functions), never from a client.
drop policy if exists audit_log_select on audit_log;
create policy audit_log_select on audit_log for select
  using (is_admin() or has_permission('audit.view'));

-- =========================================================== 2. the permission

-- A new section at the end of the catalog. Seeded BEFORE the triggers are
-- attached, so the seeding itself does not appear in the log it creates.
insert into permissions (code, description, sort_order)
values ('audit', 'Audit log section', 9)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select 'audit.view', 'View the audit log', p.id, 1
from permissions p
where p.code = 'audit'
on conflict (code) do nothing;

-- ============================================================== 3. the helpers

-- The name to write beside an id — the same three-part name the app shows.
create or replace function audit_actor_name(p_id uuid) returns text
  language sql stable security definer set search_path = public as $$
  select nullif(concat_ws(' ', first_name, father_name, surname), '')
  from profiles where id = p_id;
$$;

-- A human label for a row, so the log can say "أضاف موظفاً: أحمد الخطيب"
-- rather than "inserted a row whose id is a3f9…". Computed when the event is
-- written, because for a delete there is nothing left to look up later.
--
-- Relational rows (a grant, a membership, a rating) are labelled by what they
-- connect; everything else falls back to whichever naming column it has.
-- Never fails: a label is a courtesy, and a lookup that breaks must not take
-- the write it describes down with it.
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
    else null
  end;

  return coalesce(v,
    p_row ->> 'name_ar', p_row ->> 'title', p_row ->> 'name',
    p_row ->> 'label', p_row ->> 'code', p_row ->> 'email');
exception when others then
  return null;
end;
$$;

-- ====================================================== 4. the generic trigger

create or replace function audit_row_change() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_changed text[];
begin
  if tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);

    -- The columns that actually moved. `updated_at` is bookkeeping, not a
    -- decision, so it never counts as one of them.
    select array_agg(d.k) into v_changed
    from (
      select coalesce(o.key, n.key) as k
      from jsonb_each(v_old) o
      full outer join jsonb_each(v_new) n on n.key = o.key
      where o.value is distinct from n.value
    ) d
    where d.k <> 'updated_at';

    if v_changed is null then
      -- Nothing moved but the timestamp. For `reports` that IS the event:
      -- save_report rewrites the (unaudited) rows and blocks wholesale, and
      -- the header update is the one line that stands for the whole save.
      if tg_table_name = 'reports' then
        v_changed := array['content'];
      else
        return null;
      end if;
    end if;
  elsif tg_op = 'INSERT' then
    v_new := to_jsonb(new);
  else
    v_old := to_jsonb(old);
  end if;

  insert into audit_log
    (actor_id, actor_name, action, table_name,
     record_id, record_label, old_data, new_data, changed_fields)
  values
    (auth.uid(), audit_actor_name(auth.uid()), lower(tg_op), tg_table_name,
     coalesce(v_new ->> 'id', v_old ->> 'id'),
     audit_record_label(tg_table_name, coalesce(v_new, v_old)),
     v_old, v_new, v_changed);

  return null;
end;
$$;

-- Attached to every base table in the schema, present and named, rather than
-- to a hand-kept list that a future migration would forget to extend for its
-- new table. The exceptions are the four explained at the top of this file.
--
-- NOTE for future migrations: a table created after this one starts unaudited.
-- Re-run this block (or add the one-line CREATE TRIGGER) in the migration that
-- creates it.
do $$
declare
  t text;
begin
  for t in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname not in
        ('audit_log', 'device_tokens', 'notifications',
         'report_rows', 'report_blocks')
  loop
    execute format('drop trigger if exists audit_row on %I', t);
    execute format(
      'create trigger audit_row after insert or update or delete on %I '
      'for each row execute function audit_row_change()', t);
  end loop;
end
$$;

-- ================================================ 5. notifications: one line

-- A broadcast is one act however many inboxes it lands in. The transition
-- table carries every inserted row; the log gets one line saying what was
-- sent and to how many.
--
-- Reads and deletions of notifications are not logged: marking an inbox read
-- is not an administrative act, and nothing in the app deletes them.
create or replace function audit_notifications_insert() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_count bigint;
  v_title text;
  v_group text;
  v_data jsonb;
begin
  select count(*), min(title) into v_count, v_title from new_rows;
  if v_count = 0 then
    return null;
  end if;

  select group_id::text, data into v_group, v_data from new_rows limit 1;

  insert into audit_log
    (actor_id, actor_name, action, table_name, record_id, record_label,
     new_data)
  values
    (auth.uid(), audit_actor_name(auth.uid()), 'insert', 'notifications',
     v_group, v_title,
     jsonb_build_object('title', v_title, 'recipients', v_count,
                        'data', v_data));
  return null;
end;
$$;

drop trigger if exists audit_rows on notifications;
create trigger audit_rows
  after insert on notifications
  referencing new table as new_rows
  for each statement execute function audit_notifications_insert();

-- ======================================================== 6. storage: uploads

-- Files are acts too: a document attached, a photo replaced, an attachment
-- removed. Best-effort — on an instance where `postgres` may not attach
-- triggers to the storage schema, the rest of the log still stands.
create or replace function audit_storage_change() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into audit_log
      (actor_id, actor_name, action, table_name, record_id, record_label,
       new_data)
    values
      (auth.uid(), public.audit_actor_name(auth.uid()), 'insert', 'storage',
       new.id::text, new.bucket_id || '/' || new.name,
       jsonb_build_object('bucket', new.bucket_id, 'path', new.name));
  else
    insert into audit_log
      (actor_id, actor_name, action, table_name, record_id, record_label,
       old_data)
    values
      (auth.uid(), public.audit_actor_name(auth.uid()), 'delete', 'storage',
       old.id::text, old.bucket_id || '/' || old.name,
       jsonb_build_object('bucket', old.bucket_id, 'path', old.name));
  end if;
  return null;
end;
$$;

do $$
begin
  execute 'drop trigger if exists audit_storage on storage.objects';
  execute
    'create trigger audit_storage after insert or delete on storage.objects '
    'for each row execute function public.audit_storage_change()';
exception when insufficient_privilege or undefined_table then
  raise notice 'audit: cannot attach to storage.objects; file events unlogged';
end
$$;

-- ================================================== 7. signing in and out

-- Sessions live in the auth schema, out of a trigger's reach. The app calls
-- this on every successful sign-in, account switch and sign-out. Best-effort
-- by design on the client; here it only refuses to write fiction.
--
-- A brand-new signup signs in before it has a profile row, and actor_id
-- references profiles — so the id is only written once it exists there, and
-- until then the email stands in as the name.
create or replace function log_auth_event(p_event text) returns void
  language plpgsql security definer set search_path = public as $$
declare
  v_has_profile boolean;
begin
  if auth.uid() is null then
    raise exception 'not authorized';
  end if;
  if p_event not in ('login', 'logout') then
    raise exception 'unknown event';
  end if;

  select exists (select 1 from profiles where id = auth.uid())
    into v_has_profile;

  insert into audit_log (actor_id, actor_name, action, table_name)
  values (
    case when v_has_profile then auth.uid() end,
    coalesce(audit_actor_name(auth.uid()), auth.jwt() ->> 'email'),
    p_event, 'auth');
end;
$$;

-- ================================================================ 8. reading

-- The page reads through this rather than the table so every line arrives
-- with the actor's CURRENT face and name beside the snapshot taken when the
-- event happened — and so the filters run next to the data.
create or replace function audit_events(
  p_limit int default 50,
  p_before_id bigint default null,
  p_actor_id uuid default null,
  p_actions text[] default null,
  p_tables text[] default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_query text default null
) returns table (
  id bigint,
  occurred_at timestamptz,
  actor_id uuid,
  actor_name text,
  actor_photo_url text,
  action text,
  table_name text,
  record_id text,
  record_label text,
  old_data jsonb,
  new_data jsonb,
  changed_fields text[]
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (is_admin() or has_permission('audit.view')) then
    raise exception 'not authorized';
  end if;

  return query
  select a.id, a.occurred_at, a.actor_id,
         coalesce(
           nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
           a.actor_name) as actor_name,
         p.photo_url as actor_photo_url,
         a.action, a.table_name, a.record_id, a.record_label,
         a.old_data, a.new_data, a.changed_fields
  from audit_log a
  left join profiles p on p.id = a.actor_id
  where (p_before_id is null or a.id < p_before_id)
    and (p_actor_id is null or a.actor_id = p_actor_id)
    and (p_actions is null or a.action = any (p_actions))
    and (p_tables is null or a.table_name = any (p_tables))
    and (p_from is null or a.occurred_at >= p_from)
    and (p_to is null or a.occurred_at < p_to)
    and (
      nullif(btrim(coalesce(p_query, '')), '') is null
      or ar_fold(coalesce(a.record_label, ''))
           like '%' || ar_fold(btrim(p_query)) || '%'
      or ar_fold(coalesce(a.actor_name, ''))
           like '%' || ar_fold(btrim(p_query)) || '%'
    )
  order by a.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

-- Everyone who has ever done anything — the "by whom" filter's option list.
create or replace function audit_actors() returns table (
  actor_id uuid,
  actor_name text,
  photo_url text
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (is_admin() or has_permission('audit.view')) then
    raise exception 'not authorized';
  end if;

  return query
  select d.actor_id,
         coalesce(
           nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
           d.actor_name) as actor_name,
         p.photo_url
  from (
    select distinct on (a.actor_id) a.actor_id, a.actor_name
    from audit_log a
    where a.actor_id is not null
    order by a.actor_id, a.id desc
  ) d
  left join profiles p on p.id = d.actor_id
  order by 2 nulls last;
end;
$$;
