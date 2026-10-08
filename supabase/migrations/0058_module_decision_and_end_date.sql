-- Every file has a number, and an end it can be given in advance.
--
-- Two facts every operational file carries, whatever its type, so neither is a
-- field of any type: they sit on `modules` beside `starts_on`, the way that one
-- has since 0017. A type describes what a KIND of file holds; these describe
-- the file.
--
-- رقم القرار is optional, and has to be: a file is often opened before the
-- decision that authorises it is issued, and the number arrives afterwards.
--
-- The end date is optional too, and it is not the same thing as the type's
-- `end_condition` (0024). That says what event closes a file of this kind —
-- "ترحيل آخر حاج إلى المدينة المنورة" — the same sentence every season, and it
-- is prose. This is a date, on one file, after which the file is no longer
-- live. Both are worth having: the condition says what will end it, the date
-- says when it did.
--
-- What "no longer live" MEANS is the same thing deactivating it by hand means,
-- and is written in the same three places that phrase already lives — so a file
-- that has run out ceases to be a working file for its members, exactly as one
-- an administrator switched off does. It does not vanish: managers still see it
-- whole, which is the point of recording an end rather than deleting anything.

alter table modules
  add column if not exists decision_number text,
  add column if not exists ends_on date;

comment on column modules.decision_number is
  'رقم القرار/الملف. Optional: the file is often opened before the decision '
  'that authorises it is issued.';

comment on column modules.ends_on is
  'The day this file stops being live, inclusive — it is still running ON that '
  'date. Null for a file with no end set. Distinct from the type''s '
  'end_condition, which is prose about the event that closes such files.';

-- A file cannot end before it starts. Both nullable, so the check only bites
-- when both are present.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'modules_ends_after_starts'
  ) then
    alter table modules
      add constraint modules_ends_after_starts
        check (ends_on is null or starts_on is null or ends_on >= starts_on);
  end if;
end
$$;

-- --------------------------------------------------------------- what live means

-- A member sees the files he is in that are RUNNING. The date is read off the
-- row itself rather than through a function: a policy on `modules` that queried
-- `modules` would have to be told not to consult itself.
drop policy if exists modules_select on modules;
create policy modules_select on modules for select
  using (
    is_admin()
    or has_permission('modules.manage')
    or has_permission('modules.members')
    or (
      is_active
      and (ends_on is null or ends_on >= current_date)
      and is_module_member(id)
    )
  );

-- And nobody is told they have been put into a file that has already finished.
-- Same rule, same words, in the two places that announce an assignment.

create or replace function on_module_member_added() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  if exists (
    select 1 from modules
     where id = new.module_id
       and is_active
       and (ends_on is null or ends_on >= current_date)
  ) then
    perform notify_module_assignment(new.module_id, new.profile_id, new.role_id);
  end if;
  return new;
end;
$$;

create or replace function on_module_node_member_added() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_module_id uuid;
begin
  select module_id into v_module_id from module_nodes where id = new.node_id;
  if exists (
    select 1 from modules
     where id = v_module_id
       and is_active
       and (ends_on is null or ends_on >= current_date)
  ) then
    perform notify_module_assignment(
      v_module_id, new.profile_id, new.role_id, new.node_id
    );
  end if;
  return new;
end;
$$;

-- Activating a file whose end has already passed announces nothing either: the
-- switch says "let them in" and the date has already said "we are done".
create or replace function on_module_activated() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  r record;
begin
  if new.is_active and not old.is_active
     and (new.ends_on is null or new.ends_on >= current_date) then
    for r in
      select profile_id, role_id, null::uuid as node_id
        from module_members where module_id = new.id
      union all
      select nm.profile_id, nm.role_id, nm.node_id
        from module_node_members nm
        join module_nodes n on n.id = nm.node_id
       where n.module_id = new.id
    loop
      perform notify_module_assignment(
        new.id, r.profile_id, r.role_id, r.node_id
      );
    end loop;
  end if;
  return new;
end;
$$;
