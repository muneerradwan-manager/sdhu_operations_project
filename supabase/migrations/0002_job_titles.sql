-- Predefined, admin-managed list of job titles (الوصف الوظيفي)
create table job_titles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index job_titles_name_active_key on job_titles (name) where is_active;
