-- A complaint is a thing a person may file about anything the mission has:
-- another employee, an operational file, a report, a hotel, a cluster, a group
-- — or none of them, when what is wrong does not have a row.
--
-- Three rules shape everything below, and each one costs something:
--
--   1. ANYONE APPROVED MAY FILE. There is no `complaints.file` code. A record
--      of what went wrong that only some people may write is not a record of
--      what went wrong.
--
--   2. THE ACCUSED NEVER LEARNS WHO ACCUSED HIM. RLS hides rows, not columns,
--      so he is given no read on `complaints` at all: he reaches his own case
--      through security-definer functions that return the body and the
--      attachments and no name. This is the same shape 0059 chose for ratings
--      ("the anonymity is structural, not a decision the app makes"), and it is
--      why this file has more functions than tables.
--
--   3. THREE DIFFERENT PEOPLE COMPLAINING SUSPENDS THE ACCOUNT, BY ITSELF.
--      Not three complaints — three complainants. One man filing four times is
--      a dispute; three men filing once each is a pattern, and the mission
--      cannot wait for a meeting to act on it. Dismissing a complaint takes it
--      back out of the count, and the suspension lifts on its own.
--
-- Rule 3 walks straight into the guard trigger 0073 put on `profiles`, which
-- reverts any write to `is_suspended` by a caller without `employees.suspend`
-- — and the caller here is the complainant. Section 6 is the whole of that
-- problem and its escape; it is the most delicate thing in this file.

-- =============================================================== 1. the enum

do $$
begin
  if not exists (select 1 from pg_type where typname = 'complaint_target_type') then
    create type complaint_target_type as enum
      ('employee', 'module', 'report', 'hotel', 'cluster', 'group', 'other');
  end if;
end
$$;

-- =============================================================== 2. the tables
--
-- The target is four nullable foreign keys under one enum, not a bare
-- `target_id uuid`. Filing is an ordinary insert under RLS, and with no key
-- behind it a client could name a row that never existed: the label would be
-- unfalsifiable and — worse — the distinct-complainant count that suspends an
-- account would quietly never reach three, because the complaints would be
-- filed against a uuid that is nobody. It also lets every policy and helper
-- below compare `target_profile_id = auth.uid()` plainly, instead of carrying
-- the enum around as a discriminator that one of them will one day forget.

create table if not exists complaints (
  id uuid primary key default gen_random_uuid(),

  -- CASCADE, and deliberately not SET NULL: the count is
  -- `count(distinct complainant_id)`, which ignores nulls. Under SET NULL,
  -- deleting one employee would collapse several accusers into none and lift
  -- somebody else's suspension as a side effect of an unrelated deletion.
  complainant_id uuid not null references profiles (id) on delete cascade,

  target_type complaint_target_type not null,
  target_profile_id uuid references profiles        (id) on delete set null,
  target_module_id  uuid references modules         (id) on delete set null,
  target_report_id  uuid references reports         (id) on delete set null,
  target_item_id    uuid references reference_items (id) on delete set null,

  -- Written once, at filing, for the reason audit_log carries actor_name: the
  -- target's row may go, and a complaint that then reads "about (nothing)" has
  -- stopped being a record of anything.
  target_label text,

  body text not null constraint complaint_body_not_blank check (btrim(body) <> ''),

  -- Two different acts, kept apart. Locking ends the conversation and leaves
  -- the complaint standing. Dismissing says it should not have been filed, and
  -- takes it out of the suspension count.
  locked_at    timestamptz,
  locked_by    uuid references profiles (id) on delete set null,
  dismissed_at timestamptz,
  dismissed_by uuid references profiles (id) on delete set null,
  dismiss_reason text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- One-way implication, on purpose: it says "if a key is set it matches the
  -- type", never "a key must be set". The strict form would turn every
  -- `on delete set null` above into a constraint violation raised while
  -- deleting an unrelated hotel. Presence at birth is enforced by
  -- complaints_resolve_target() below, which can tell an insert from a cascade.
  constraint complaint_target_shape check (
    num_nonnulls(target_profile_id, target_module_id,
                 target_report_id, target_item_id) <= 1
    and (target_profile_id is null or target_type = 'employee')
    and (target_module_id  is null or target_type = 'module')
    and (target_report_id  is null or target_type = 'report')
    and (target_item_id    is null or target_type in ('hotel', 'cluster', 'group'))
    and (target_type <> 'other'
         or num_nonnulls(target_profile_id, target_module_id,
                         target_report_id, target_item_id) = 0)
  ),

  constraint complaint_not_against_self check (
    target_type <> 'employee'
    or target_profile_id is distinct from complainant_id
  ),
  constraint complaint_lock_is_whole
    check ((locked_at is null) = (locked_by is null)),
  constraint complaint_dismiss_is_whole
    check ((dismissed_at is null) = (dismissed_by is null))
);

-- Flat, not a tree. "Unlimited replies" is about how many, not about nesting;
-- a thread three people are arguing in reads as a conversation, and a
-- conversation is a list.
create table if not exists complaint_replies (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references complaints (id) on delete cascade,
  author_id uuid not null references profiles (id) on delete cascade,
  body text not null constraint complaint_reply_not_blank check (btrim(body) <> ''),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- The composite key the attachments table points at below.
  constraint complaint_replies_id_complaint unique (id, complaint_id)
);

-- One table for both, because an attachment is an attachment: the same reader
-- widget draws it and the same storage rule guards it whether it came in with
-- the complaint or with a reply four days later. Same columns as
-- notification_attachments (0031) and module_report_attachments (0045).
create table if not exists complaint_attachments (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references complaints (id) on delete cascade,
  -- null = it came with the complaint itself.
  reply_id uuid,
  kind attachment_kind not null,
  -- {complaint_id}/{i}_{file}, or {complaint_id}/replies/{reply_id}/{i}_{file}.
  path text not null,
  name text not null,
  mime_type text,
  size_bytes bigint,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  -- Declarative proof that a reply's file belongs to that reply's OWN
  -- complaint. A key on reply_id alone cannot say it, and a check constraint
  -- may not run a subquery.
  constraint complaint_attachment_reply_matches
    foreign key (reply_id, complaint_id)
    references complaint_replies (id, complaint_id) on delete cascade
);

-- The index the suspension rests on. Partial, so it holds only the rows the
-- count actually reads and stays small however long the table lives.
create index if not exists idx_complaints_autosuspend
  on complaints (target_profile_id, complainant_id)
  where target_type = 'employee' and dismissed_at is null;

create index if not exists idx_complaints_complainant
  on complaints (complainant_id, created_at desc);
create index if not exists idx_complaints_created
  on complaints (created_at desc);
-- The accused's own list, which unlike the count includes dismissed rows.
create index if not exists idx_complaints_target_profile
  on complaints (target_profile_id, created_at desc)
  where target_type = 'employee';
create index if not exists idx_complaints_target_module
  on complaints (target_module_id) where target_module_id is not null;
create index if not exists idx_complaints_target_report
  on complaints (target_report_id) where target_report_id is not null;
create index if not exists idx_complaints_target_item
  on complaints (target_item_id) where target_item_id is not null;
create index if not exists idx_complaint_replies_complaint
  on complaint_replies (complaint_id, created_at);
create index if not exists idx_complaint_attachments_complaint
  on complaint_attachments (complaint_id, sort_order);
create index if not exists idx_complaint_attachments_reply
  on complaint_attachments (reply_id) where reply_id is not null;

-- ===================================== 3. naming the target, and pinning it down

-- Fills target_label and refuses a complaint whose target does not add up.
--
-- The label is computed by audit_record_label (0077), which already knows how
-- to name all four of these tables. A second naming function would be a second
-- place for "what is this row called" to be answered, and the two would drift.
create or replace function complaints_resolve_target() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_row jsonb;
  v_set text;
  v_table text;
begin
  if tg_op = 'UPDATE'
     and (new.target_type    is distinct from old.target_type
       or new.complainant_id is distinct from old.complainant_id) then
    -- A complaint is about what it was filed about, by whom it was filed.
    raise exception 'complaint_is_immutable';
  end if;

  if tg_op = 'INSERT' then
    if new.target_type <> 'other'
       and num_nonnulls(new.target_profile_id, new.target_module_id,
                        new.target_report_id, new.target_item_id) <> 1 then
      raise exception 'complaint_target_missing';
    end if;

    -- Which set an item belongs to is the difference between a hotel and a
    -- cluster, and a check constraint cannot ask.
    if new.target_item_id is not null then
      select rs.code into v_set
        from reference_items ri
        join reference_sets rs on rs.id = ri.set_id
       where ri.id = new.target_item_id;
      if v_set is distinct from new.target_type::text then
        raise exception 'complaint_target_wrong_set';
      end if;
    end if;

    v_table := case new.target_type
      when 'employee' then 'profiles'
      when 'module'   then 'modules'
      when 'report'   then 'reports'
      when 'other'    then null
      else 'reference_items'
    end;

    if v_table is not null then
      case new.target_type
        when 'employee' then
          select to_jsonb(p) into v_row from profiles p
           where p.id = new.target_profile_id;
        when 'module' then
          select to_jsonb(m) into v_row from modules m
           where m.id = new.target_module_id;
        when 'report' then
          select to_jsonb(r) into v_row from reports r
           where r.id = new.target_report_id;
        else
          select to_jsonb(i) into v_row from reference_items i
           where i.id = new.target_item_id;
      end case;
      new.target_label := audit_record_label(v_table, v_row);
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists complaints_resolve_target on complaints;
create trigger complaints_resolve_target
  before insert or update on complaints
  for each row execute function complaints_resolve_target();

drop trigger if exists complaints_set_updated_at on complaints;
create trigger complaints_set_updated_at
  before update on complaints
  for each row execute function set_updated_at();

drop trigger if exists complaint_replies_set_updated_at on complaint_replies;
create trigger complaint_replies_set_updated_at
  before update on complaint_replies
  for each row execute function set_updated_at();

-- ================================================== 4. the permission catalog
--
-- Section 10; 9 is the audit log. Five actions rather than one
-- `complaints.manage`, for the reason 0073 exists: reading a register of
-- people's grievances, taking part in one, ending a conversation, calling a
-- complaint unfounded and deleting it are five different trusts.

insert into permissions (code, description, sort_order)
values ('complaints', 'Complaints section', 10)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('complaints.view',    'View every complaint filed',                  1),
  ('complaints.reply',   'Take part in any complaint thread',           2),
  ('complaints.lock',    'Close a complaint to further replies',        3),
  ('complaints.dismiss', 'Dismiss a complaint as unfounded',            4),
  ('complaints.delete',  'Delete a complaint',                          5)
) as v(code, description, sort_order)
join permissions p on p.code = 'complaints'
on conflict (code) do nothing;

-- The door first, on its own statement: the prerequisite trigger fires before
-- insert, and a single multi-row insert gives no order for it to be satisfied in.
insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from (values ('complaints.view', 'employees.view')) as v(code, requires_code)
join permissions c on c.code = v.code
join permissions r on r.code = v.requires_code
on conflict do nothing;

insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from (values
  ('complaints.reply',   'complaints.view'),
  ('complaints.lock',    'complaints.view'),
  ('complaints.dismiss', 'complaints.view'),
  ('complaints.delete',  'complaints.view'),
  -- The one this migration exists to make honest: dismissing a complaint can
  -- LIFT an automatic suspension. Whoever may dismiss is holding the suspension
  -- switch whether the grant sheet admits it or not. Now it admits it.
  ('complaints.dismiss', 'employees.suspend')
) as v(code, requires_code)
join permissions c on c.code = v.code
join permissions r on r.code = v.requires_code
on conflict do nothing;

-- ============================================================ 5. the predicates
--
-- All of them before anything that uses them: a POLICY resolves the functions
-- named in it when the policy is created, so one defined further down the file
-- would fail this migration outright.
--
-- And every one of them is SECURITY DEFINER, which is not decoration. The
-- accused cannot select `complaints` at all (§7 explains why), so the same test
-- written plainly would run under his own row security, find nothing, and
-- refuse him with no explanation given.

create or replace function can_read_all_complaints() returns boolean
  language sql stable security definer set search_path = public as $$
  select is_admin() or has_permission('complaints.view');
$$;

-- The count, in one place, so the guard and the panel cannot come to disagree
-- about what "three different people" means.
create or replace function complaints_distinct_complainants(p_profile_id uuid)
  returns int
  language sql stable security definer set search_path = public as $$
  select coalesce(count(distinct c.complainant_id), 0)::int
    from complaints c
   where c.target_type = 'employee'
     and c.target_profile_id = p_profile_id
     and c.dismissed_at is null;
$$;

-- is_approved() is deliberately not asked. The suspension this feature imposes
-- makes is_approved() false, and a man who may not answer the complaints that
-- suspended him has been convicted without a hearing.
create or replace function can_reply_to_complaint(p_complaint_id uuid)
  returns boolean
  language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (
    select 1 from complaints c
     where c.id = p_complaint_id
       and c.locked_at is null
       and (c.complainant_id = auth.uid()
            or (c.target_type = 'employee' and c.target_profile_id = auth.uid())
            or is_admin()
            or has_permission('complaints.reply'))
  );
$$;

create or replace function can_write_complaint_attachment(
  p_complaint_id uuid, p_reply_id uuid
) returns boolean
  language sql stable security definer set search_path = public as $$
  select case
    when p_reply_id is null then exists (
      select 1 from complaints c
       where c.id = p_complaint_id and c.complainant_id = auth.uid())
    else exists (
      select 1 from complaint_replies r
       where r.id = p_reply_id
         and r.complaint_id = p_complaint_id
         and r.author_id = auth.uid())
  end;
$$;

-- Who the reader is to this complaint. 'accused' is tested first on purpose: a
-- manager who is himself the target of a complaint is not that complaint's
-- manager.
create or replace function complaint_role(p_complaint_id uuid) returns text
  language sql stable security definer set search_path = public as $$
  select case
    when c.target_type = 'employee' and c.target_profile_id = auth.uid()
      then 'accused'
    when c.complainant_id = auth.uid() then 'complainant'
    when can_read_all_complaints() then 'manager'
  end
  from complaints c where c.id = p_complaint_id;
$$;

-- ================================================== 6. the automatic suspension
--
-- The columns that tell an automatic suspension from a decided one, and record
-- what a manager has already forgiven.

alter table profiles
  add column if not exists auto_suspended_at timestamptz,
  add column if not exists auto_suspend_forgiven_count int not null default 0;

comment on column profiles.auto_suspended_at is
  'Set when complaints suspended this account. Only an automatic suspension is '
  'lifted automatically; one a person decided on stays until a person lifts it.';
comment on column profiles.auto_suspend_forgiven_count is
  'Distinct complainants at the moment somebody lifted an automatic suspension '
  'by hand. The rule fires again only past this number — the complaints that '
  'were forgiven stay forgiven, and a new accuser is new information.';

-- True only inside the recount's own nested UPDATE.
--
-- Both halves are needed. The flag alone would be forgeable the day anything
-- exposes set_config over the API, and the payload would be the worst in this
-- schema: suspending the administrator locks the whole mission out, because
-- is_admin(), has_permission() and is_approved() all require `not is_suspended`.
-- The trigger depth alone would hand suspension powers to any future trigger
-- that happens to touch profiles. Together, nothing a client can send matches:
-- a statement sent over PostgREST fires its BEFORE triggers at depth 1.
create or replace function autosuspend_in_progress() returns boolean
  language sql stable set search_path = public as $$
  select coalesce(current_setting('app.autosuspend', true), 'off') = 'on'
     and pg_trigger_depth() > 1;
$$;

-- Counts, then suspends or lifts. Never both, and never anything else.
create or replace function complaints_autosuspend_recount(p_profile_id uuid)
  returns void
  language plpgsql security definer set search_path = public as $$
declare
  -- Three different people. Change this and the rule changes; there is nowhere
  -- else the number appears.
  c_threshold constant int := 3;
  v_count int;
  v_suspended boolean;
  v_auto_at timestamptz;
  v_forgiven int;
begin
  if p_profile_id is null then
    return;
  end if;

  -- Two complaints landing together would both read "two so far" and both
  -- decline to act. Same device, same reason, as 0078.
  perform pg_advisory_xact_lock(
    hashtextextended('complaint_autosuspend:' || p_profile_id::text, 0));

  select count(distinct c.complainant_id) into v_count
    from complaints c
   where c.target_type = 'employee'
     and c.target_profile_id = p_profile_id
     and c.dismissed_at is null;

  select p.is_suspended, p.auto_suspended_at, p.auto_suspend_forgiven_count
    into v_suspended, v_auto_at, v_forgiven
    from profiles p
   where p.id = p_profile_id;

  if v_suspended is null then
    return;                                    -- the profile is already gone
  end if;

  if v_count >= c_threshold and not v_suspended and v_count > v_forgiven then
    perform set_config('app.autosuspend', 'on', true);
    update profiles
       set is_suspended = true, auto_suspended_at = now()
     where id = p_profile_id;
    perform set_config('app.autosuspend', 'off', true);

  elsif v_count < c_threshold and v_suspended and v_auto_at is not null then
    -- `auto_suspended_at is not null` is the entirety of "and never lift one a
    -- person decided on".
    perform set_config('app.autosuspend', 'on', true);
    update profiles
       set is_suspended = false, auto_suspended_at = null
     where id = p_profile_id;
    perform set_config('app.autosuspend', 'off', true);
  end if;
end;
$$;

revoke execute on function complaints_autosuspend_recount(uuid)
  from public, anon, authenticated;

create or replace function complaints_touch_autosuspend() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('UPDATE', 'DELETE') and old.target_profile_id is not null then
    perform complaints_autosuspend_recount(old.target_profile_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.target_profile_id is not null
     and (tg_op = 'INSERT'
          or new.target_profile_id is distinct from old.target_profile_id) then
    perform complaints_autosuspend_recount(new.target_profile_id);
  end if;
  return null;
end;
$$;

-- AFTER, because a BEFORE INSERT trigger cannot see its own row: the third
-- complainant would not be counted and it would take a fourth to fire.
--
-- And on the delete too: complainant_id cascades, so removing an employee
-- removes what they filed. Without a recount somebody else stays suspended by
-- complaints that no longer exist.
drop trigger if exists complaints_autosuspend on complaints;
create trigger complaints_autosuspend
  after insert or delete
     or update of dismissed_at, target_profile_id
  on complaints
  for each row execute function complaints_touch_autosuspend();

-- ============================================ 7. the guard on profiles, amended
--
-- Copied verbatim from 0073 and added to. Three changes, marked below:
--   * an escape at the top for the recount, narrowed to two columns;
--   * the two new columns join is_suspended in the reversion and in the
--     base-record merge, so no ordinary caller can forge them;
--   * lifting a suspension by hand ends the automatic one and forgives what
--     caused it — without which the next complaint re-imposes the suspension
--     the manager just lifted, within seconds, over their decision.

create or replace function profiles_guard_privileged_columns() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  caller_is_admin boolean;
  v_status_ok boolean;
begin
  if auth.uid() is null then
    return new;
  end if;

  -- CHANGED IN 0079. complaints_autosuspend_recount is the only writer that
  -- arrives here with the flag set AND from inside another trigger. It is let
  -- through for exactly two columns; everything else on the row snaps back, so
  -- even a caller who somehow forged the flag gains nothing but the suspension
  -- state the complaints rule grants anyway.
  if autosuspend_in_progress() then
    new := jsonb_populate_record(new, to_jsonb(old) || jsonb_build_object(
      'is_suspended',      to_jsonb(new) -> 'is_suspended',
      'auto_suspended_at', to_jsonb(new) -> 'auto_suspended_at'
    ));
    return new;
  end if;

  select p.is_admin and p.account_status = 'approved' and not p.is_suspended
    into caller_is_admin
  from public.profiles p
  where p.id = auth.uid();

  if coalesce(caller_is_admin, false) then
    -- CHANGED IN 0079. An admin decides freely, but the stamps below still
    -- have to be right, so the two of them run for an admin too.
    if old.is_suspended and not new.is_suspended then
      new.auto_suspended_at := null;
      new.auto_suspend_forgiven_count := complaints_distinct_complainants(old.id);
    elsif not old.is_suspended and new.is_suspended then
      new.auto_suspended_at := null;
    end if;
    return new;
  end if;

  -- Adminship is never handed out here.
  new.is_admin := old.is_admin;

  -- account_status: its owner may resubmit; a decider may decide.
  v_status_ok :=
    new.account_status is not distinct from old.account_status
    or (old.id = auth.uid()
        and old.account_status in ('incomplete', 'rejected')
        and new.account_status = 'pending')
    or (not old.is_admin
        and has_permission('approvals.decide')
        and old.account_status in ('pending', 'incomplete', 'rejected')
        and new.account_status in ('approved', 'rejected'));
  if not v_status_ok then
    new.account_status := old.account_status;
  end if;

  if not (not old.is_admin and has_permission('approvals.decide')) then
    new.rejection_reason := old.rejection_reason;
  end if;

  -- CHANGED IN 0079: the two markers move with the flag they describe, or a
  -- caller without employees.suspend could clear the "this was automatic" mark
  -- and make a suspension permanent that the rule would have lifted.
  if not (not old.is_admin and has_permission('employees.suspend')) then
    new.is_suspended := old.is_suspended;
    new.auto_suspended_at := old.auto_suspended_at;
    new.auto_suspend_forgiven_count := old.auto_suspend_forgiven_count;
  end if;

  if not (not old.is_admin and has_permission('employees.external')) then
    new.is_external := old.is_external;
    new.external_organization := old.external_organization;
    new.external_title := old.external_title;
  end if;

  -- The base record (names, phones, titles…) belongs to its owner and to an
  -- employees.edit holder. Anyone else who reached this UPDATE came for one of
  -- the privileged columns above; everything else returns to what it was.
  if not (old.id = auth.uid() or has_permission('employees.edit')) then
    declare
      v_merged jsonb;
    begin
      v_merged := to_jsonb(old) || jsonb_build_object(
        'is_admin',              to_jsonb(new) -> 'is_admin',
        'account_status',        to_jsonb(new) -> 'account_status',
        'rejection_reason',      to_jsonb(new) -> 'rejection_reason',
        'is_suspended',          to_jsonb(new) -> 'is_suspended',
        -- CHANGED IN 0079: without these two the write above would land and
        -- their markers would snap back, leaving a state that cannot happen —
        -- not suspended, but carrying the timestamp of an automatic suspension.
        'auto_suspended_at',           to_jsonb(new) -> 'auto_suspended_at',
        'auto_suspend_forgiven_count', to_jsonb(new) -> 'auto_suspend_forgiven_count',
        'is_external',           to_jsonb(new) -> 'is_external',
        'external_organization', to_jsonb(new) -> 'external_organization',
        'external_title',        to_jsonb(new) -> 'external_title'
      );
      new := jsonb_populate_record(new, v_merged);
    end;
  end if;

  -- CHANGED IN 0079, and last on purpose: it stamps only writes that survived
  -- everything above. A hand lifting a suspension ends the automatic one and
  -- forgives the complainants it knew about; a hand imposing one puts it beyond
  -- the rule's reach.
  if old.is_suspended and not new.is_suspended then
    new.auto_suspended_at := null;
    new.auto_suspend_forgiven_count := complaints_distinct_complainants(old.id);
  elsif not old.is_suspended and new.is_suspended then
    new.auto_suspended_at := null;
  end if;

  return new;
end;
$$;

-- =========================================================== 8. row security

alter table complaints            enable row level security;
alter table complaint_replies     enable row level security;
alter table complaint_attachments enable row level security;

-- Note what is absent: `target_profile_id = auth.uid()`. The accused has no
-- direct read at all, because a row he can select is a row whose complainant_id
-- he can select. He reaches his case through §8.
--
-- And a manager is fenced off his own case, or `complaints.view` would be the
-- way to find out who accused you, and the first person to notice would be the
-- one it was hidden from.
drop policy if exists complaints_select on complaints;
create policy complaints_select on complaints for select
  using (
    complainant_id = auth.uid()
    or (can_read_all_complaints()
        and (target_type <> 'employee'
             or target_profile_id is distinct from auth.uid()))
  );

drop policy if exists complaints_insert on complaints;
create policy complaints_insert on complaints for insert
  with check (complainant_id = auth.uid() and is_approved());

drop policy if exists complaints_update on complaints;
create policy complaints_update on complaints for update
  using (is_admin()
         or has_permission('complaints.lock')
         or has_permission('complaints.dismiss'))
  with check (is_admin()
              or has_permission('complaints.lock')
              or has_permission('complaints.dismiss'));

-- Withdrawing your own, and only while nobody has answered it. Once someone has
-- replied the thread is not yours alone to end.
drop policy if exists complaints_delete on complaints;
create policy complaints_delete on complaints for delete
  using (
    is_admin()
    or has_permission('complaints.delete')
    or (complainant_id = auth.uid()
        and not exists (select 1 from complaint_replies r
                         where r.complaint_id = complaints.id))
  );

-- "Your own" names nobody, so it is safe to grant and it is what lets the
-- accused read back the reply he just wrote.
drop policy if exists complaint_replies_select on complaint_replies;
create policy complaint_replies_select on complaint_replies for select
  using (
    author_id = auth.uid()
    or exists (select 1 from complaints c
                where c.id = complaint_replies.complaint_id)
  );

drop policy if exists complaint_replies_insert on complaint_replies;
create policy complaint_replies_insert on complaint_replies for insert
  with check (author_id = auth.uid() and can_reply_to_complaint(complaint_id));

drop policy if exists complaint_replies_update on complaint_replies;
create policy complaint_replies_update on complaint_replies for update
  using (is_admin() or has_permission('complaints.delete'))
  with check (is_admin() or has_permission('complaints.delete'));

drop policy if exists complaint_replies_delete on complaint_replies;
create policy complaint_replies_delete on complaint_replies for delete
  using (is_admin() or has_permission('complaints.delete'));

drop policy if exists complaint_attachments_select on complaint_attachments;
create policy complaint_attachments_select on complaint_attachments for select
  using (
    exists (select 1 from complaints c
             where c.id = complaint_attachments.complaint_id)
    or exists (select 1 from complaint_replies r
                where r.id = complaint_attachments.reply_id
                  and r.author_id = auth.uid())
  );

drop policy if exists complaint_attachments_insert on complaint_attachments;
create policy complaint_attachments_insert on complaint_attachments for insert
  with check (can_write_complaint_attachment(complaint_id, reply_id));

drop policy if exists complaint_attachments_delete on complaint_attachments;
create policy complaint_attachments_delete on complaint_attachments for delete
  using (is_admin() or has_permission('complaints.delete'));

-- ========================================================= 9. what is readable
--
-- The attachments of one complaint or one reply, as json, so a thread comes
-- back in a single call instead of one round trip per bubble.
create or replace function complaint_attachment_json(
  p_complaint_id uuid, p_reply_id uuid
) returns jsonb
  language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(a) order by a.sort_order, a.created_at), '[]'::jsonb)
    from complaint_attachments a
   where a.complaint_id = p_complaint_id
     and a.reply_id is not distinct from p_reply_id;
$$;

-- The accused's own list. Takes no argument, on 0059's rule: there is nobody
-- else it could be asked about, which is a stronger guarantee than a check that
-- it is being asked about the right person.
--
-- complainant_id, dismissed_by and locked_by are not columns of the result. You
-- do not null a field you never selected, and that is the whole advantage of
-- answering through a function instead of through a view.
create or replace function complaints_against_me(
  p_limit int default 50,
  p_before timestamptz default null
) returns table (
  id uuid,
  created_at timestamptz,
  body text,
  is_locked boolean,
  is_dismissed boolean,
  reply_count int,
  attachments jsonb
)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not authorized';
  end if;

  return query
  select c.id, c.created_at, c.body,
         c.locked_at is not null,
         c.dismissed_at is not null,
         (select count(*)::int from complaint_replies r where r.complaint_id = c.id),
         complaint_attachment_json(c.id, null)
    from complaints c
   where c.target_type = 'employee'
     and c.target_profile_id = auth.uid()
     and (p_before is null or c.created_at < p_before)
   order by c.created_at desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

-- The register. 'mine' is what I filed; 'all' is everything, and asks for the
-- permission.
create or replace function complaints_list(
  p_scope text default 'mine',
  p_target_type text default null,
  p_include_dismissed boolean default true,
  p_query text default null,
  p_limit int default 50,
  p_before timestamptz default null
) returns table (
  id uuid,
  created_at timestamptz,
  target_type text,
  target_id uuid,
  target_label text,
  complainant_id uuid,
  complainant_name text,
  complainant_photo_url text,
  body text,
  is_locked boolean,
  is_dismissed boolean,
  reply_count int,
  attachment_count int,
  my_role text
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_all boolean := p_scope = 'all';
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;
  if v_all and not can_read_all_complaints() then
    raise exception 'not authorized';
  end if;

  return query
  select c.id, c.created_at, c.target_type::text,
         coalesce(c.target_profile_id, c.target_module_id,
                  c.target_report_id, c.target_item_id),
         c.target_label,
         c.complainant_id,
         nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
         p.photo_url,
         c.body,
         c.locked_at is not null,
         c.dismissed_at is not null,
         (select count(*)::int from complaint_replies r where r.complaint_id = c.id),
         (select count(*)::int from complaint_attachments a where a.complaint_id = c.id),
         case when c.complainant_id = v_uid then 'complainant' else 'manager' end
    from complaints c
    left join profiles p on p.id = c.complainant_id
   -- Never a row where the caller is the accused: that is what
   -- complaints_against_me is for, and it is the only door that redacts.
   where (c.target_type <> 'employee' or c.target_profile_id is distinct from v_uid)
     and (case when v_all then true else c.complainant_id = v_uid end)
     and (p_target_type is null or c.target_type::text = p_target_type)
     and (p_include_dismissed or c.dismissed_at is null)
     and (p_query is null or btrim(p_query) = ''
          or ar_fold(coalesce(c.target_label, '')) like '%' || ar_fold(p_query) || '%'
          or ar_fold(c.body) like '%' || ar_fold(p_query) || '%')
     and (p_before is null or c.created_at < p_before)
   order by c.created_at desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

-- The head of the thread and every reply, in order, with each bubble's author
-- named only to a reader who may know it.
--
-- The one rule, applied to the head AND to every reply the complainant wrote:
-- the accused never learns which words are his accuser's. author_role always
-- comes back, so the app can label an anonymous bubble "the complainant"
-- without naming anybody. The photo is nulled with the name — a face identifies
-- a man in a mission of five hundred more surely than a name does.
create or replace function complaint_thread(p_complaint_id uuid)
returns table (
  reply_id uuid,
  created_at timestamptz,
  body text,
  author_id uuid,
  author_name text,
  author_photo_url text,
  author_role text,
  is_mine boolean,
  attachments jsonb
)
language plpgsql stable security definer set search_path = public as $$
declare
  c complaints;
  v_role text;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authorized';
  end if;

  select * into c from complaints where id = p_complaint_id;
  if c.id is null then
    raise exception 'complaint_not_found';
  end if;

  v_role := complaint_role(p_complaint_id);
  if v_role is null then
    raise exception 'not authorized';
  end if;

  return query
  with msg as (
    select null::uuid as rid, c.created_at as at, c.body as text_body,
           c.complainant_id as aid, 'complainant'::text as arole
    union all
    select r.id, r.created_at, r.body, r.author_id,
           case
             when r.author_id = c.complainant_id then 'complainant'
             when c.target_type = 'employee'
              and r.author_id = c.target_profile_id then 'accused'
             else 'manager'
           end
      from complaint_replies r
     where r.complaint_id = c.id
  ),
  vis as (
    select m.*, (v_role <> 'accused' or m.arole <> 'complainant') as may_name
      from msg m
  )
  select v.rid, v.at, v.text_body,
         case when v.may_name then v.aid end,
         case when v.may_name then
           nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), '') end,
         case when v.may_name then p.photo_url end,
         v.arole,
         v.aid = v_uid,
         complaint_attachment_json(c.id, v.rid)
    from vis v
    left join profiles p on p.id = v.aid
   order by v.at, v.rid nulls first;
end;
$$;

-- Numbers about one man, for the panel at the foot of his page. Here is where a
-- profile argument belongs: it is asked about somebody, and it answers with
-- counts and never with a name.
create or replace function complaints_against(p_profile_id uuid)
returns table (
  distinct_complainants int,
  open_complaints int,
  dismissed_complaints int,
  is_auto_suspended boolean,
  forgiven_count int
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not (p_profile_id = auth.uid() or can_read_all_complaints()) then
    raise exception 'not authorized';
  end if;

  return query
  select complaints_distinct_complainants(p_profile_id),
         (select count(*)::int from complaints c
           where c.target_type = 'employee' and c.target_profile_id = p_profile_id
             and c.dismissed_at is null),
         (select count(*)::int from complaints c
           where c.target_type = 'employee' and c.target_profile_id = p_profile_id
             and c.dismissed_at is not null),
         (select p.auto_suspended_at is not null from profiles p where p.id = p_profile_id),
         (select p.auto_suspend_forgiven_count from profiles p where p.id = p_profile_id);
end;
$$;

-- ========================================================= 10. what is writable
--
-- Filing runs with the caller's own rights, like save_report: every policy and
-- the recount trigger apply to it exactly as they would to a plain insert. It
-- returns the id because the files are filed under it and cannot be uploaded
-- until it exists.
create or replace function file_complaint(
  p_target_type text,
  p_target_id uuid,
  p_body text
) returns uuid
  language plpgsql security invoker set search_path = public as $$
declare
  v_type complaint_target_type := p_target_type::complaint_target_type;
  v_id uuid;
begin
  insert into complaints (
    complainant_id, target_type, body,
    target_profile_id, target_module_id, target_report_id, target_item_id
  ) values (
    auth.uid(), v_type, p_body,
    case when v_type = 'employee' then p_target_id end,
    case when v_type = 'module'   then p_target_id end,
    case when v_type = 'report'   then p_target_id end,
    case when v_type in ('hotel', 'cluster', 'group') then p_target_id end
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- Replying is DEFINER: the accused cannot select the parent complaint, so a
-- plain insert could not check the thread is open, nor read its own row back.
create or replace function reply_to_complaint(
  p_complaint_id uuid,
  p_body text
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if not can_reply_to_complaint(p_complaint_id) then
    raise exception 'complaint_locked';
  end if;
  if btrim(coalesce(p_body, '')) = '' then
    raise exception 'complaint_body_required';
  end if;

  insert into complaint_replies (complaint_id, author_id, body)
  values (p_complaint_id, auth.uid(), p_body)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function set_complaint_lock(
  p_complaint_id uuid,
  p_locked boolean
) returns void
  language plpgsql security definer set search_path = public as $$
begin
  if not (is_admin() or has_permission('complaints.lock')) then
    raise exception 'not authorized';
  end if;
  update complaints
     set locked_at = case when p_locked then now() end,
         locked_by = case when p_locked then auth.uid() end
   where id = p_complaint_id;
end;
$$;

-- Un-dismissing recounts as surely as dismissing does: putting a complaint back
-- can push the count over three again.
create or replace function set_complaint_dismissed(
  p_complaint_id uuid,
  p_dismissed boolean,
  p_reason text default null
) returns void
  language plpgsql security definer set search_path = public as $$
begin
  if not (is_admin() or has_permission('complaints.dismiss')) then
    raise exception 'not authorized';
  end if;
  update complaints
     set dismissed_at   = case when p_dismissed then now() end,
         dismissed_by   = case when p_dismissed then auth.uid() end,
         dismiss_reason = case when p_dismissed then p_reason end
   where id = p_complaint_id;
end;
$$;

-- Telling the accused, without telling him who.
--
-- A trigger and not a call inside file_complaint, for two reasons. The row is
-- written with `sender_id` null — the sender IS the complainant, and the
-- recipient reads his own inbox row, so a notification would be the last place
-- the anonymity is given away and it would be given away whole. Writing null
-- there needs the definer's rights, and file_complaint deliberately runs with
-- the caller's. And a trigger fires for a plain insert too, so the notice does
-- not depend on which door the complaint came through.
create or replace function complaints_notify_target() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if new.target_type = 'employee' and new.target_profile_id is not null then
    insert into notifications (recipient_id, sender_id, title, body)
    values (new.target_profile_id, null, 'تم تقديم شكوى بحقك',
            'اطّلع عليها من صفحتك الشخصية وردّ عليها.');
  end if;
  return null;
exception when others then
  -- Best effort, always: the complaint is the record, and a notice that failed
  -- to send must never take it down with it.
  return null;
end;
$$;

drop trigger if exists complaints_notify_target on complaints;
create trigger complaints_notify_target
  after insert on complaints
  for each row execute function complaints_notify_target();

revoke execute on function complaints_against_me(int, timestamptz) from public, anon;
grant  execute on function complaints_against_me(int, timestamptz) to authenticated;
revoke execute on function complaints_list(text, text, boolean, text, int, timestamptz) from public, anon;
grant  execute on function complaints_list(text, text, boolean, text, int, timestamptz) to authenticated;
revoke execute on function complaint_thread(uuid) from public, anon;
grant  execute on function complaint_thread(uuid) to authenticated;
revoke execute on function complaints_against(uuid) from public, anon;
grant  execute on function complaints_against(uuid) to authenticated;
revoke execute on function file_complaint(text, uuid, text) from public, anon;
grant  execute on function file_complaint(text, uuid, text) to authenticated;
revoke execute on function reply_to_complaint(uuid, text) from public, anon;
grant  execute on function reply_to_complaint(uuid, text) to authenticated;
revoke execute on function set_complaint_lock(uuid, boolean) from public, anon;
grant  execute on function set_complaint_lock(uuid, boolean) to authenticated;
revoke execute on function set_complaint_dismissed(uuid, boolean, text) from public, anon;
grant  execute on function set_complaint_dismissed(uuid, boolean, text) to authenticated;
revoke execute on function complaint_attachment_json(uuid, uuid) from public, anon;
grant  execute on function complaint_attachment_json(uuid, uuid) to authenticated;
revoke execute on function complaints_distinct_complainants(uuid) from public, anon;
grant  execute on function complaints_distinct_complainants(uuid) to authenticated;

-- ============================================================== 11. the files

insert into storage.buckets (id, name, public)
values ('complaints', 'complaints', false)
on conflict (id) do nothing;

-- Path convention:
--   {complaint_id}/{i}_{file}
--   {complaint_id}/replies/{reply_id}/{i}_{file}
--
-- The reply nests UNDER the complaint so that folder [1] is always the
-- complaint and one read rule covers everything it owns. The complainant's id
-- appears nowhere in it, and must not: a path is readable by the accused.
create or replace function can_read_complaint_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    return false;
  end if;
  begin
    v_id := (storage.foldername(p_path))[1]::uuid;
  exception when others then
    return false;
  end;
  return exists (
    select 1 from complaints c
     where c.id = v_id
       and (c.complainant_id = auth.uid()
            or (c.target_type = 'employee' and c.target_profile_id = auth.uid())
            or is_admin()
            or has_permission('complaints.view'))
  );
end;
$$;

-- The root belongs to the complainant; a reply's folder to that reply's author.
create or replace function can_write_complaint_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_id uuid;
  v_reply uuid;
  v_parts text[];
begin
  if auth.uid() is null then
    return false;
  end if;
  v_parts := storage.foldername(p_path);
  begin
    v_id := v_parts[1]::uuid;
  exception when others then
    return false;
  end;

  if v_parts[2] = 'replies' then
    begin
      v_reply := v_parts[3]::uuid;
    exception when others then
      return false;
    end;
    return exists (
      select 1 from complaint_replies r
       where r.id = v_reply and r.complaint_id = v_id
         and r.author_id = auth.uid());
  end if;

  return exists (
    select 1 from complaints c
     where c.id = v_id and c.complainant_id = auth.uid());
end;
$$;

-- Four policies rather than one `for all`: a `for all` policy's USING clause is
-- not consulted on an insert, and being explicit is what 0031 does.
drop policy if exists complaint_files_read on storage.objects;
create policy complaint_files_read on storage.objects for select
  to authenticated using (
    bucket_id = 'complaints' and public.can_read_complaint_file(name));

drop policy if exists complaint_files_write on storage.objects;
create policy complaint_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'complaints' and public.can_write_complaint_file(name));

drop policy if exists complaint_files_update on storage.objects;
create policy complaint_files_update on storage.objects for update
  to authenticated
  using      (bucket_id = 'complaints' and public.can_write_complaint_file(name))
  with check (bucket_id = 'complaints' and public.can_write_complaint_file(name));

drop policy if exists complaint_files_delete on storage.objects;
create policy complaint_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'complaints'
    and (public.can_write_complaint_file(name)
         or public.is_admin()
         or public.has_permission('complaints.delete')));

-- storage.objects records who uploaded each file in owner/owner_id. The accused
-- must be able to READ the complainant's attachments to see the evidence, and
-- reading the object row hands him that uid — the whole of the anonymity, given
-- away in a column no screen in this app ever draws.
create or replace function complaint_files_strip_owner() returns trigger
  language plpgsql security definer set search_path = public, storage as $$
begin
  if new.bucket_id = 'complaints' then
    update storage.objects set owner = null, owner_id = null where id = new.id;
  end if;
  return null;
end;
$$;

do $$
begin
  execute 'drop trigger if exists complaint_files_anonymise on storage.objects';
  execute 'create trigger complaint_files_anonymise after insert on storage.objects '
          'for each row execute function public.complaint_files_strip_owner()';
exception when insufficient_privilege or undefined_table then
  raise notice
    'complaints: cannot scrub storage.objects.owner — uploads name their uploader';
end
$$;

-- ================================================================ 12. the log
--
-- The generic trigger from 0077 must NOT be attached to these tables. It writes
-- the whole row into new_data and auth.uid() into actor_id, and audit_events
-- hands both to anyone with audit.view — so an insert on `complaints` would be
-- the disclosure twice over, once in the actor and once in the row.
--
-- Filing and replying are the acts whose actor is the secret. Dismissing,
-- locking and deleting are a manager's acts, and naming the manager is exactly
-- what the log is for.
create or replace function audit_complaint_change() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_changed text[];
  v_secret boolean;
begin
  v_secret := (tg_op = 'INSERT');

  if tg_op = 'UPDATE' then
    v_old := to_jsonb(old) - 'complainant_id' - 'author_id' - 'body';
    v_new := to_jsonb(new) - 'complainant_id' - 'author_id' - 'body';
    select array_agg(d.k) into v_changed
    from (
      select coalesce(o.key, n.key) as k
      from jsonb_each(v_old) o
      full outer join jsonb_each(v_new) n on n.key = o.key
      where o.value is distinct from n.value
    ) d
    where d.k <> 'updated_at';
    if v_changed is null then
      return null;
    end if;
  elsif tg_op = 'INSERT' then
    v_new := to_jsonb(new) - 'complainant_id' - 'author_id' - 'body';
  else
    v_old := to_jsonb(old) - 'complainant_id' - 'author_id' - 'body';
  end if;

  insert into audit_log
    (actor_id, actor_name, action, table_name,
     record_id, record_label, old_data, new_data, changed_fields)
  values
    (case when v_secret then null else auth.uid() end,
     case when v_secret then null else audit_actor_name(auth.uid()) end,
     lower(tg_op), tg_table_name,
     coalesce(v_new ->> 'id', v_old ->> 'id'),
     audit_record_label(tg_table_name, coalesce(v_new, v_old)),
     v_old, v_new, v_changed);

  return null;
end;
$$;

drop trigger if exists audit_row on complaints;
create trigger audit_row after insert or update or delete on complaints
  for each row execute function audit_complaint_change();

drop trigger if exists audit_row on complaint_replies;
create trigger audit_row after insert or update or delete on complaint_replies
  for each row execute function audit_complaint_change();

drop trigger if exists audit_row on complaint_attachments;
create trigger audit_row after insert or update or delete on complaint_attachments
  for each row execute function audit_complaint_change();

-- The three tables learn their names — the TARGET's name, never the
-- complainant's. This string is read by everyone with audit.view, and a
-- complaint labelled with the man who filed it is not anonymous.
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
    else null
  end;

  return coalesce(v,
    p_row ->> 'name_ar', p_row ->> 'title', p_row ->> 'name',
    p_row ->> 'label', p_row ->> 'code', p_row ->> 'email');
exception when others then
  return null;
end;
$$;

-- The suspension's own audit row would otherwise read "this person suspended
-- that one at 14:32", naming the complainant who happened to file third.
create or replace function audit_row_change() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_changed text[];
  v_anonymous boolean;
begin
  -- CHANGED IN 0079.
  v_anonymous := tg_table_name = 'profiles' and autosuspend_in_progress();

  if tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);

    select array_agg(d.k) into v_changed
    from (
      select coalesce(o.key, n.key) as k
      from jsonb_each(v_old) o
      full outer join jsonb_each(v_new) n on n.key = o.key
      where o.value is distinct from n.value
    ) d
    where d.k <> 'updated_at';

    if v_changed is null then
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
    (case when v_anonymous then null else auth.uid() end,
     case when v_anonymous then null else audit_actor_name(auth.uid()) end,
     lower(tg_op), tg_table_name,
     coalesce(v_new ->> 'id', v_old ->> 'id'),
     audit_record_label(tg_table_name, coalesce(v_new, v_old)),
     v_old, v_new, v_changed);

  return null;
end;
$$;

-- And the storage log, which records auth.uid() for every upload — including
-- the complainant's evidence.
create or replace function audit_storage_change() returns trigger
  language plpgsql security definer set search_path = public, storage as $$
declare
  v_bucket text;
  v_name text;
begin
  v_bucket := coalesce(new.bucket_id, old.bucket_id);
  v_name := coalesce(new.name, old.name);

  -- CHANGED IN 0079: the complaints bucket is logged without its uploader.
  insert into audit_log
    (actor_id, actor_name, action, table_name,
     record_id, record_label, old_data, new_data, changed_fields)
  values
    (case when v_bucket = 'complaints' then null else auth.uid() end,
     case when v_bucket = 'complaints' then null
          else audit_actor_name(auth.uid()) end,
     lower(tg_op), 'storage',
     coalesce(new.id, old.id)::text,
     v_name,
     case when tg_op = 'DELETE'
          then jsonb_build_object('bucket', v_bucket, 'path', v_name) end,
     case when tg_op <> 'DELETE'
          then jsonb_build_object('bucket', v_bucket, 'path', v_name) end,
     null);

  return null;
exception when others then
  return null;
end;
$$;

-- NOTE for future migrations: 0077's do-block, which attaches the generic
-- audit_row trigger to every table in the schema, must NEVER be re-run after
-- this file. It would replace the redacting trigger above with the generic one
-- and start writing complainant_id into a log that managers read.
