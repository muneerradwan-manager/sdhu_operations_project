-- The job description already says what he does there.
--
-- An external employee had two posts recorded on him and only ever held one:
--
--   الوصف الوظيفي            profiles.job_title_id  → reference_items
--   المسمى الوظيفي لدى الجهة  profiles.external_title (free text)
--
-- The second was written in 0003, at a time when الوصف الوظيفي was the mission's
-- own list — رئيس البعثة, مرشد ديني, عامل خدمات (0010). Under that list the two
-- columns did mean different things: the first said what a man does ON the Hajj,
-- so a delegate from another ministry needed somewhere else to say what he is
-- the rest of the year, and external_title was that somewhere.
--
-- 0124 (`the job list becomes the office's, not the pilgrimage's`) took the
-- list away from the mission and gave it to إدارة الحج والعمرة — accountant,
-- data-entry clerk, informatics engineer, driver, physician, translator — and
-- retired the titles that only ever described a role held on a mission. From
-- that moment الوصف الوظيفي is a man's permanent post at the body that employs
-- him, for internal and external staff alike. What he does on the mission is
-- said by his role in an operational file and by نوع البعثة; it is not said by
-- either of these columns.
--
-- So the second column stopped being a second fact and became the same fact
-- typed twice — once from a governed list, once by hand into a free-text box.
-- Two answers to one question, of which only the free-text one can disagree
-- with the record. What an external employee needs recorded that a permanent
-- one does not is the الجهة / الوزارة he comes from: external_organization,
-- which stays. Nothing else.
--
-- ------------------------------------------------------------------ the order
--
-- `permanent_employees` is `select *` over profiles, which Postgres expanded
-- into a fixed column list at creation, so the view holds a dependency on the
-- column and the drop fails without taking it down first. `assignable_employees`
-- names the column in its RETURNS TABLE, and a returns-type change cannot be
-- made by `create or replace`. Both come down, the column goes, both go back.
--
-- The guard is restated for a different reason: `new.external_title := …` is
-- resolved when the trigger RUNS, not when it is created, so leaving it would
-- have broken every UPDATE on profiles rather than failing here.

-- ------------------------------------------------------- 1. take down the two
drop view if exists permanent_employees;

drop function if exists assignable_employees(
  uuid, text, boolean, int, int, uuid, boolean, uuid
);

-- -------------------------------------------------------------- 2. the column
alter table profiles drop column if exists external_title;

-- ---------------------------------------------------- 3. the directory's view
--
-- Verbatim from 0085. It is `select *`, so it re-expands over the narrower row.
create view permanent_employees
  with (security_invoker = true) as
  select *
  from profiles
  where is_external = false
    and account_status = 'approved';

-- --------------------------------------------------- 4. the guard on profiles
--
-- Copied verbatim from 0079. One line removed, in the `employees.external`
-- block, and one key removed from the base-record merge. The merge would in
-- fact have tolerated the stale key — jsonb_populate_record ignores what the
-- record type has no column for — but a rule that reads as though it still
-- protects something it cannot is worse than no line at all.
create or replace function profiles_guard_privileged_columns() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  caller_is_admin boolean;
  v_status_ok boolean;
begin
  if auth.uid() is null then
    return new;
  end if;

  -- FROM 0079. complaints_autosuspend_recount is the only writer that arrives
  -- here with the flag set AND from inside another trigger. It is let through
  -- for exactly two columns; everything else on the row snaps back, so even a
  -- caller who somehow forged the flag gains nothing but the suspension state
  -- the complaints rule grants anyway.
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
    -- FROM 0079. An admin decides freely, but the stamps below still have to be
    -- right, so the two of them run for an admin too.
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

  -- FROM 0079: the two markers move with the flag they describe, or a caller
  -- without employees.suspend could clear the "this was automatic" mark and
  -- make a suspension permanent that the rule would have lifted.
  if not (not old.is_admin and has_permission('employees.suspend')) then
    new.is_suspended := old.is_suspended;
    new.auto_suspended_at := old.auto_suspended_at;
    new.auto_suspend_forgiven_count := old.auto_suspend_forgiven_count;
  end if;

  -- CHANGED IN 0138: two columns, not three.
  if not (not old.is_admin and has_permission('employees.external')) then
    new.is_external := old.is_external;
    new.external_organization := old.external_organization;
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
        -- FROM 0079: without these two the write above would land and their
        -- markers would snap back, leaving a state that cannot happen — not
        -- suspended, but carrying the timestamp of an automatic suspension.
        'auto_suspended_at',           to_jsonb(new) -> 'auto_suspended_at',
        'auto_suspend_forgiven_count', to_jsonb(new) -> 'auto_suspend_forgiven_count',
        'is_external',           to_jsonb(new) -> 'is_external',
        'external_organization', to_jsonb(new) -> 'external_organization'
      );
      new := jsonb_populate_record(new, v_merged);
    end;
  end if;

  -- FROM 0079, and last on purpose: it stamps only writes that survived
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

-- ----------------------------------------------------- 5. the season's roster
--
-- Verbatim from 0106 (0029, filtered in 0065, renamed in 0085, its door widened
-- in 0106). One column out of the RETURNS TABLE and out of the two select
-- lists; the search still folds Arabic across the three name columns and the
-- job title, which is now the only post any of these people has.
create function assignable_employees(
  p_season_id uuid,
  p_query text default null,
  p_is_external boolean default null,
  p_limit int default 40,
  p_offset int default 0,
  p_job_title_id uuid default null,
  p_only_free boolean default false,
  p_city_id uuid default null
)
returns table (
  id uuid,
  first_name text,
  father_name text,
  surname text,
  photo_url text,
  is_external boolean,
  external_organization text,
  job_title_name text,
  job_title_name_en text,
  phone_sy text,
  phone_sa text,
  account_status text,
  assignments jsonb
)
language sql stable security definer set search_path = public as $$
  with permitted as (
    select is_admin()
        or has_permission('modules.members')
        or has_permission('tasks.assign') as ok
  ),
  busy as (
    select mm.profile_id
      from module_members mm
      join modules m on m.id = mm.module_id
     where m.season_id = p_season_id
    union
    select nm.profile_id
      from module_node_members nm
      join module_nodes n on n.id = nm.node_id
      join modules m on m.id = n.module_id
     where m.season_id = p_season_id
  ),
  candidates as (
    select
      p.id, p.first_name, p.father_name, p.surname, p.photo_url,
      p.is_external, p.external_organization,
      jt.name_ar as job_title_name,
      jt.name_en as job_title_name_en,
      p.phone_sy, p.phone_sa, p.account_status::text as account_status
    from season_participants sp
    join profiles p on p.id = sp.profile_id
    left join reference_items jt on jt.id = p.job_title_id
    where (select ok from permitted)
      and sp.season_id = p_season_id
      and sp.status = 'active'
      and not p.is_suspended
      and (p_is_external is null or p.is_external = p_is_external)
      and (p_job_title_id is null or p.job_title_id = p_job_title_id)
      and (p_city_id is null or p.city_id = p_city_id)
      and (not coalesce(p_only_free, false)
           or p.id not in (select profile_id from busy))
      and (
        nullif(btrim(coalesce(p_query, '')), '') is null
        or ar_fold(concat_ws(' ', p.first_name, p.father_name, p.surname))
             like '%' || ar_fold(btrim(p_query)) || '%'
        or ar_fold(coalesce(jt.name_ar, '')) like '%' || ar_fold(btrim(p_query)) || '%'
        or ar_fold(coalesce(jt.name_en, '')) like '%' || ar_fold(btrim(p_query)) || '%'
      )
  )
  select
    c.id, c.first_name, c.father_name, c.surname, c.photo_url,
    c.is_external, c.external_organization,
    c.job_title_name, c.job_title_name_en,
    c.phone_sy, c.phone_sa, c.account_status,
    coalesce(f.files, '[]'::jsonb) as assignments
  from candidates c
  left join lateral (
    select jsonb_agg(
             jsonb_build_object(
               'module_id',  a.module_id,
               'name_ar',    a.name_ar,
               'name_en',    a.name_en,
               'hijri_year', a.hijri_year
             )
             order by a.name_ar
           ) as files
    from (
      select m.id as module_id, mt.name_ar, mt.name_en, s.hijri_year
        from module_members mm
        join modules m       on m.id = mm.module_id
        join module_types mt on mt.id = m.module_type_id
        join seasons s       on s.id = m.season_id
       where mm.profile_id = c.id
         and m.season_id = p_season_id
      union
      select m.id, mt.name_ar, mt.name_en, s.hijri_year
        from module_node_members nm
        join module_nodes n  on n.id = nm.node_id
        join modules m       on m.id = n.module_id
        join module_types mt on mt.id = m.module_type_id
        join seasons s       on s.id = m.season_id
       where nm.profile_id = c.id
         and m.season_id = p_season_id
    ) a
  ) f on true
  order by concat_ws(' ', c.first_name, c.father_name, c.surname)
  limit greatest(coalesce(p_limit, 40), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke execute on function
  assignable_employees(uuid, text, boolean, int, int, uuid, boolean, uuid)
  from public, anon;
grant execute on function
  assignable_employees(uuid, text, boolean, int, int, uuid, boolean, uuid)
  to authenticated;
