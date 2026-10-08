-- Reports, and how often a file asks for them.
--
-- Several of the ten files say it in their duties — "رفع تقارير يومية شاملة عن
-- سير العمليات", "إعداد ورفع التقرير الختامي" — and the app had nowhere to put
-- one. So a file now states its cadence, and the people in it file against it.
--
-- The cadence belongs to the FILE, not to the type: الطوافة والنقل wants a
-- report every day, الإنشاءات wants one at the end, and next season the
-- Administration may decide otherwise. Whoever creates or edits the file
-- chooses, and `none` is a real answer — most files ask for nothing.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'report_cadence') then
    create type report_cadence as enum ('none', 'daily', 'weekly', 'once');
  end if;
end
$$;

alter table modules
  add column if not exists report_cadence report_cadence not null default 'none';

create table if not exists module_reports (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules (id) on delete cascade,
  author_id uuid not null references profiles (id) on delete cascade,
  -- Which stretch of time this report accounts for, normalised by the database
  -- rather than the phone: the day for a daily file, the Monday of the week for
  -- a weekly one, and null for a file that asks once. It is what makes "one
  -- report per period" a fact instead of a convention.
  period_start date,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_module_reports_module
  on module_reports (module_id, created_at desc);
create index if not exists idx_module_reports_author
  on module_reports (author_id);

-- One report per person per period. Two indexes because a null period — the
-- file that asks once — never collides in a plain unique.
create unique index if not exists uq_module_reports_period
  on module_reports (module_id, author_id, period_start)
  where period_start is not null;

create unique index if not exists uq_module_reports_once
  on module_reports (module_id, author_id)
  where period_start is null;

alter table module_reports enable row level security;

-- A person reads their own. Managers read all of them, which is the point of
-- asking for them: a daily report nobody can read is a diary.
drop policy if exists module_reports_select on module_reports;
create policy module_reports_select on module_reports for select
  using (
    author_id = auth.uid()
    or is_admin()
    or has_permission('modules.manage')
  );

-- Written only by their author, and only by someone actually in the file.
drop policy if exists module_reports_write on module_reports;
create policy module_reports_write on module_reports for all
  using (author_id = auth.uid() and is_module_member(module_id))
  with check (author_id = auth.uid() and is_module_member(module_id));

-- ------------------------------------------------------------------ filing
--
-- Through a function rather than a plain insert, so the period is worked out in
-- one place. A phone with a wrong clock, or in another timezone, would
-- otherwise decide for itself which day it was filing for.

create or replace function submit_module_report(
  p_module_id uuid,
  p_body text
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

  insert into module_reports (module_id, author_id, period_start, body)
  values (p_module_id, auth.uid(), v_period, p_body)
  on conflict (module_id, author_id, period_start)
    where period_start is not null
    do update set body = excluded.body, updated_at = now()
  returning id into v_id;

  -- The `once` case lands on the other index, which the clause above cannot
  -- name at the same time.
  if v_id is null then
    insert into module_reports (module_id, author_id, period_start, body)
    values (p_module_id, auth.uid(), null, p_body)
    on conflict (module_id, author_id)
      where period_start is null
      do update set body = excluded.body, updated_at = now()
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

revoke execute on function submit_module_report(uuid, text) from public, anon;
grant execute on function submit_module_report(uuid, text) to authenticated;
