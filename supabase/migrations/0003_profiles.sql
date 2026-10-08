-- Employee profile, one row per auth.users, created automatically on signup
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text,
  surname text,                 -- الكنية
  father_name text,
  photo_url text,
  job_title_id uuid references job_titles (id) on delete restrict,
  gender gender_enum,
  date_of_birth date,
  mission_type mission_type_enum,
  phone_sy text,                -- Syrian phone, required at profile completion
  phone_sa text,                -- Saudi phone, optional
  passport_image_url text,
  visa_image_url text,
  nusuk_card_image_url text,
  account_status account_status_enum not null default 'incomplete',
  rejection_reason text,
  is_admin boolean not null default false,
  is_external boolean not null default false,
  external_organization text,
  external_title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Keep updated_at fresh
create function set_updated_at() returns trigger
  language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on profiles
  for each row execute function set_updated_at();

-- Auto-create an empty profile row when a new auth user signs up
create function handle_new_user() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, account_status)
  values (new.id, 'incomplete')
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Guardrail: non-admins may not touch privileged columns.
-- RLS is row-level and cannot protect individual columns, so this is the real boundary.
create function profiles_guard_privileged_columns() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  caller_is_admin boolean;
begin
  select p.is_admin and p.account_status = 'approved'
    into caller_is_admin
  from public.profiles p
  where p.id = auth.uid();

  caller_is_admin := coalesce(caller_is_admin, false);

  if caller_is_admin then
    return new;
  end if;

  -- Privileged columns can never be changed by a non-admin...
  new.is_admin := old.is_admin;
  new.is_external := old.is_external;
  new.external_organization := old.external_organization;
  new.external_title := old.external_title;
  new.rejection_reason := old.rejection_reason;

  -- ...except a user may submit their own profile for review:
  -- incomplete/rejected -> pending only. Any other status transition is reverted.
  if new.account_status is distinct from old.account_status then
    if old.account_status in ('incomplete', 'rejected')
       and new.account_status = 'pending' then
      -- allowed
    else
      new.account_status := old.account_status;
    end if;
  end if;

  return new;
end;
$$;

create trigger profiles_guard_before_update
  before update on profiles
  for each row execute function profiles_guard_privileged_columns();
