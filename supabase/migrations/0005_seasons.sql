-- Hajj seasons; exactly one may be "current" at a time
create table seasons (
  id uuid primary key default gen_random_uuid(),
  hijri_year int unique not null,
  gregorian_label text,
  is_current boolean not null default false,
  start_date date,
  end_date date,
  created_at timestamptz not null default now()
);

-- Enforce single current season at the storage level
create unique index one_current_season on seasons (is_current) where is_current;

create table season_participants (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references seasons (id) on delete cascade,
  profile_id uuid not null references profiles (id) on delete cascade,
  status participation_status_enum not null default 'active',
  joined_at timestamptz not null default now(),
  unique (season_id, profile_id)
);

create index idx_season_participants_profile on season_participants (profile_id);
