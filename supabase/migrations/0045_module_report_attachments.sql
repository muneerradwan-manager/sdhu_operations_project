-- A report is what you send up, not what you type.
--
-- 0044 gave a file a cadence and its members a text box, and the text box was
-- the wrong shape for the thing being asked for. What a sector supervisor
-- actually files at the end of a day is the sheet he signed, the photo of the
-- tower, the voice note he recorded in the bus — and, if he has anything to add
-- about them, a sentence or two. So the attachments are the report, and the
-- body becomes notes: optional, and named as such.

alter table module_reports alter column body drop not null;

-- Same columns as `notification_attachments` (0031), same enum, deliberately:
-- an attachment is an attachment, and the app reads both with one widget. A
-- separate table rather than a shared one because what makes a row visible is
-- completely different — a recipient there, an author or a manager here — and
-- that is a policy, not a column.
create table if not exists module_report_attachments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null
    references module_reports (id) on delete cascade,
  kind attachment_kind not null,
  -- Path inside the private `modules` bucket:
  -- {module_id}/reports/{report_id}/{file}. Under the module rather than in a
  -- bucket of its own so one read policy still governs everything a file owns.
  path text not null,
  -- The name the filer's device gave it. Shown, and used for the download.
  name text not null,
  mime_type text,
  size_bytes bigint,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_module_report_attachments_report
  on module_report_attachments (report_id);

alter table module_report_attachments enable row level security;

-- Visible exactly when the report it hangs off is — its own policy is the
-- single source of truth (author, admin, or `modules.manage`), so this one
-- defers to it rather than restating who may read what.
drop policy if exists module_report_attachments_select on module_report_attachments;
create policy module_report_attachments_select on module_report_attachments
  for select using (
    exists (
      select 1 from module_reports r
      where r.id = module_report_attachments.report_id
    )
  );

-- Attaching is part of filing: only the author of the report, and only while
-- they are still in the file.
drop policy if exists module_report_attachments_write on module_report_attachments;
create policy module_report_attachments_write on module_report_attachments
  for all
  using (
    exists (
      select 1 from module_reports r
      where r.id = module_report_attachments.report_id
        and r.author_id = auth.uid()
        and is_module_member(r.module_id)
    )
  )
  with check (
    exists (
      select 1 from module_reports r
      where r.id = module_report_attachments.report_id
        and r.author_id = auth.uid()
        and is_module_member(r.module_id)
    )
  );

-- -------------------------------------------------------------------- storage
--
-- The `modules` bucket has been readable by any member of the module the path
-- names, and writable only by whoever manages modules (0017). Neither is right
-- for a report: the person filing one is an ordinary member, and what he files
-- is not for the rest of the file to read.

-- True for {module_id}/reports/{report_id}/..., which is the one shape of path
-- inside this bucket that does not belong to the module at large.
create or replace function is_module_report_file(p_path text) returns boolean
  language sql stable set search_path = public, storage as $$
  select array_length(storage.foldername(p_path), 1) >= 3
     and (storage.foldername(p_path))[2] = 'reports';
$$;

-- The report id a path names, or null when it names something else or is not a
-- uuid at all. Kept apart so the policies below can stay readable.
create or replace function module_report_file_id(p_path text) returns uuid
  language plpgsql stable set search_path = public, storage as $$
begin
  if not is_module_report_file(p_path) then
    return null;
  end if;
  return (storage.foldername(p_path))[3]::uuid;
exception when others then
  return null;
end;
$$;

-- Read: a report's files follow the report. Everything else in the bucket keeps
-- the rule it had — the module's members.
create or replace function can_read_module_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_module_id uuid;
  v_report_id uuid;
begin
  if is_admin() or has_permission('modules.manage') then
    return true;
  end if;

  v_report_id := module_report_file_id(p_path);
  if v_report_id is not null then
    return exists (
      select 1 from module_reports
      where id = v_report_id and author_id = auth.uid()
    );
  end if;

  begin
    v_module_id := (storage.foldername(p_path))[1]::uuid;
  exception when others then
    return false;
  end;
  return exists (
    select 1 from module_members
    where module_id = v_module_id and profile_id = auth.uid()
  );
end;
$$;

-- Write: the author of the report the path names, filing under a report row
-- that already exists. `submit_module_report` creates it first and hands back
-- its id, so there is no window in which anything may be uploaded loose.
create or replace function can_write_module_report_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_report_id uuid;
begin
  v_report_id := module_report_file_id(p_path);
  if v_report_id is null then
    return false;
  end if;
  return exists (
    select 1 from module_reports r
    where r.id = v_report_id
      and r.author_id = auth.uid()
      and (storage.foldername(p_path))[1] = r.module_id::text
      and is_module_member(r.module_id)
  );
end;
$$;

drop policy if exists module_files_write on storage.objects;
create policy module_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'modules'
    and (
      public.is_admin()
      or public.has_permission('modules.manage')
      or public.can_write_module_report_file(name)
    )
  );

drop policy if exists module_files_update on storage.objects;
create policy module_files_update on storage.objects for update
  to authenticated using (
    bucket_id = 'modules'
    and (
      public.is_admin()
      or public.has_permission('modules.manage')
      or public.can_write_module_report_file(name)
    )
  );

-- Deleting one's own attachment is part of editing the report — a photo of the
-- wrong tower has to be removable before it is filed against you.
drop policy if exists module_files_delete on storage.objects;
create policy module_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'modules'
    and (
      public.is_admin()
      or public.has_permission('modules.manage')
      or public.can_write_module_report_file(name)
    )
  );

-- --------------------------------------------------------------------- filing
--
-- Returns the report's id now: the files are stored under it, so the caller
-- cannot upload anything until it knows what it is.
--
-- The upsert is also written out longhand. The version in 0044 named one
-- partial index as its conflict target, which the `once` case — the row whose
-- period is null — is not covered by; filing a second time against a file that
-- asks once raised a unique violation instead of editing the first.

create or replace function submit_module_report(
  p_module_id uuid,
  p_body text default null
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_cadence report_cadence;
  v_period date;
  v_id uuid;
begin
  if not is_module_member(p_module_id) then
    raise exception 'not a member of this file';
  end if;

  select report_cadence into v_cadence from modules where id = p_module_id;
  if v_cadence is null or v_cadence = 'none' then
    raise exception 'this file does not ask for reports';
  end if;

  v_period := case v_cadence
    when 'daily'  then current_date
    when 'weekly' then (date_trunc('week', current_date))::date
    else null
  end;

  select id into v_id from module_reports
  where module_id = p_module_id
    and author_id = auth.uid()
    and period_start is not distinct from v_period;

  if v_id is null then
    insert into module_reports (module_id, author_id, period_start, body)
    values (p_module_id, auth.uid(), v_period, p_body)
    returning id into v_id;
  else
    update module_reports
      set body = p_body, updated_at = now()
      where id = v_id;
  end if;

  return v_id;
end;
$$;

revoke execute on function submit_module_report(uuid, text) from public, anon;
grant execute on function submit_module_report(uuid, text) to authenticated;
