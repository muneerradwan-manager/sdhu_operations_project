-- What a finished file is for.
--
-- Until now a file that ended was a file that stopped mattering: the work was
-- done, and the row sat there. But the people who worked it know something
-- nobody else does — how each of them actually carried it — and that knowledge
-- has never had anywhere to go. So when a file ends, the people who were in it
-- may rate each other. Stars, and nothing else: no comment box, no reasons.
-- The moment there is a text field there is a paper trail, and the honest
-- answer stops being the safe one.
--
-- Four rules, and each is enforced here rather than in the app, because a rule
-- about who may say what about whom is not a matter of which button is drawn.
--
-- 1. Only in a file that has ENDED, by its date. Rating a colleague you are
--    still working beside is not appraisal, it is leverage.
-- 2. Only between two people who were in that file. The file is what they
--    share and the only thing either is answering for.
-- 3. Never about oneself.
-- 4. And it is ANONYMOUS. A man sees his own average and how many people gave
--    it; he never learns who said what. In a team of five, a name attached to
--    three stars is a conversation at breakfast, and after one of those nobody
--    gives three stars again — the number survives and stops meaning anything.
--
-- The anonymity is structural, not a decision the app makes: the only rows a
-- person may READ are the ones he wrote himself, and his own result reaches him
-- through a function that returns two numbers and no names.
--
-- The season is not a column here. A rating hangs off a file, a file belongs to
-- exactly one season, and a second copy of one fact is a copy that drifts. Ask
-- for a season's ratings by joining the files of that season, which is how
-- `module_node_members` finds its file too.

-- ------------------------------------------------------- an ended file is still yours
--
-- 0058 read "the file becomes inactive" as "the file goes away", and hid an
-- ended one from its own members. That was too much: a finished file is exactly
-- what this migration gives a use to, and nobody can rate inside a file he
-- cannot see. A member keeps his files, finished or not; what "ended" changes
-- is that it is no longer WORK — the app says so, and no assignment to it
-- announces itself, which 0058 got right and this leaves alone.

drop policy if exists modules_select on modules;
create policy modules_select on modules for select
  using (
    is_admin()
    or has_permission('modules.manage')
    or has_permission('modules.members')
    or (is_active and is_module_member(id))
  );

-- ------------------------------------------------------------------- the table

create table if not exists module_ratings (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references modules (id) on delete cascade,
  rater_id uuid not null references profiles (id) on delete cascade,
  ratee_id uuid not null references profiles (id) on delete cascade,
  -- Five stars, whole ones. A scale nobody has to be taught.
  stars smallint not null check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rating_is_not_of_oneself check (rater_id <> ratee_id),
  -- One verdict per person per colleague per file. Changing your mind rewrites
  -- it rather than adding a second.
  unique (module_id, rater_id, ratee_id)
);

create index if not exists idx_module_ratings_ratee
  on module_ratings (module_id, ratee_id);

alter table module_ratings enable row level security;

-- --------------------------------------------------------------- the two rules

-- Whether a file is open for rating: ended, by a date somebody set. A file with
-- no end date is never open — even switched off, it has not been declared over.
create or replace function module_rating_open(p_module_id uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from modules
     where id = p_module_id
       and ends_on is not null
       and ends_on < current_date
  );
$$;

-- Whether a PARTICULAR person holds a role in a file, on the file itself or
-- anywhere in its tree. `is_module_member(uuid)` has asked this of the caller
-- since 0024; rating asks it of somebody else.
create or replace function is_module_member(p_module_id uuid, p_profile_id uuid)
  returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from module_members
     where module_id = p_module_id and profile_id = p_profile_id
  ) or exists (
    select 1 from module_node_members nm
      join module_nodes n on n.id = nm.node_id
     where n.module_id = p_module_id and nm.profile_id = p_profile_id
  );
$$;

-- ---------------------------------------------------------------------- policies

-- A person reads what HE wrote, and nothing else. This one line is the whole of
-- the anonymity: there is no query any member can run that names who rated him.
drop policy if exists module_ratings_select on module_ratings;
create policy module_ratings_select on module_ratings for select
  using (rater_id = auth.uid());

-- And writes only his own, only in a file that has ended, and only about
-- somebody who was in it with him.
drop policy if exists module_ratings_write on module_ratings;
create policy module_ratings_write on module_ratings for all
  using (rater_id = auth.uid())
  with check (
    rater_id = auth.uid()
    and module_rating_open(module_id)
    and is_module_member(module_id, auth.uid())
    and is_module_member(module_id, ratee_id)
  );

create or replace function module_ratings_touch() returns trigger
  language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists module_ratings_set_updated_at on module_ratings;
create trigger module_ratings_set_updated_at
  before update on module_ratings
  for each row execute function module_ratings_touch();

-- ------------------------------------------------------------- what a man sees
--
-- His own result, in one file: the average and how many people gave it. Takes
-- no profile argument on purpose — there is nobody else it could be asked
-- about, which is a stronger guarantee than a check that it is being asked
-- about the right person.
--
-- Returns zero ratings rather than nothing at all, so the screen can say "not
-- rated yet" without having to tell a missing row from a failed call.

create or replace function my_module_rating(p_module_id uuid)
  returns table (average numeric, ratings integer)
  language sql stable security definer set search_path = public as $$
  select
    coalesce(round(avg(r.stars)::numeric, 2), 0)::numeric as average,
    count(*)::integer as ratings
  from module_ratings r
  where r.module_id = p_module_id
    and r.ratee_id = auth.uid();
$$;

revoke execute on function my_module_rating(uuid) from public, anon;
grant execute on function my_module_rating(uuid) to authenticated;

revoke execute on function module_rating_open(uuid) from public, anon;
grant execute on function module_rating_open(uuid) to authenticated;
