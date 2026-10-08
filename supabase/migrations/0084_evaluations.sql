-- A judgement is worth what its questions are worth.
--
-- The mission has had one kind of appraisal since 0059: five stars, between
-- colleagues, inside a file that has ended. It answers "how did he carry it"
-- and nothing else, and it is deliberately anonymous to everyone. It is left
-- exactly as it stands and this migration has nothing to do with it. What is
-- added here is the other thing an administration means by تقييم — a FORM,
-- written once by the office, filled by a named person about a named subject,
-- and adding up to a mark out of a total.
--
-- Two halves, and they meet only at the moment somebody is assigned:
--
--   THE FORM     a template with stages, each stage with questions, each
--                question with its answers. A choice question carries a mark
--                and each of its answers carries what it earns; a written
--                question carries no mark at all, because a paragraph is not
--                something you can be right about by two points. The form's
--                total is the sum of its questions and is never typed in — a
--                number somebody keeps in step by hand is a number that stops
--                being in step.
--
--   THE FILLING  one row naming a template, a subject and ONE evaluator. There
--                is no `evaluations.fill` permission, and that absence is the
--                design: you fill what you were named to fill. A permission
--                would say "anyone trusted may evaluate anyone", and that is
--                not what an appraisal is — it is an errand given to a person.
--
-- Three rules shape the rest, and each costs something:
--
--   1. A SUBMITTED EVALUATION NEVER CHANGES ITS MEANING. Forms get edited; a
--      question is reworded in Shawwal and the answer given in Rajab still has
--      to read as what was actually asked. So every answer carries its own
--      wording, its own mark and its own stage — §6 — and the template's rows
--      become a pointer that may go null without taking the record with it.
--      This is `complaints.target_label` (0079) applied to a whole sheet.
--
--   2. THE SUBJECT NEVER LEARNS WHO EVALUATED HIM. Row security hides rows and
--      not columns, so an employee is given no read on `evaluations` about
--      himself at all: he reaches his own results through security-definer
--      functions that return the marks, the questions and no name. Same shape
--      as the complaints, and the same reason that file has more functions than
--      tables. A holder of `evaluations.view` DOES see the evaluator — he is
--      not a secret from the office, only from the man he judged.
--
--   3. NOTHING BUT `save_evaluation` MOVES A MARK. `evaluations` has no UPDATE
--      policy whatsoever. Not a narrow one, not a guarded one — none. Every
--      change to a sheet goes through a security-definer function that knows
--      which of the two people is calling, and a score therefore cannot be
--      written by anybody at all, including the manager who assigned it.

-- =============================================================== 1. the enums
--
-- The target set is the complaints' set, value for value, because it is the
-- same question — what in this mission may a thing be said ABOUT — and the
-- answer must not differ depending on whether the thing said is a grievance or
-- a mark. A shared enum was the other option and was rejected: the two features
-- will drift, and the day evaluations gain a kind complaints must not have,
-- one of them would have to be given a value it can never use.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'evaluation_target_type') then
    create type evaluation_target_type as enum
      ('employee', 'module', 'report', 'hotel', 'cluster', 'group', 'other');
  end if;

  -- Two kinds and, on present evidence, only ever two. A question either has a
  -- fixed set of answers each worth something, or it is prose. A third kind —
  -- a number, a scale, a date — is a choice question with its answers written
  -- out, and writing them out is what makes the mark explicit.
  if not exists (select 1 from pg_type where typname = 'evaluation_question_kind') then
    create type evaluation_question_kind as enum ('choice', 'text');
  end if;

  -- `draft` is the whole of "he has it and has not finished". There is no
  -- 'assigned' distinct from 'draft': the difference is whether any answer has
  -- been saved yet, which is a count and not a state, and a state that can be
  -- derived is a state that can disagree.
  if not exists (select 1 from pg_type where typname = 'evaluation_status') then
    create type evaluation_status as enum ('draft', 'submitted');
  end if;
end
$$;

-- ================================================================ 2. the form

create table if not exists evaluation_templates (
  id uuid primary key default gen_random_uuid(),
  title text not null
    constraint evaluation_template_title_not_blank check (btrim(title) <> ''),
  description text,

  -- What this form is for judging. Fixed once anything has been assigned from
  -- it (§4): a sheet about a hotel cannot become a sheet about an employee
  -- without every target on every filled copy becoming a lie.
  target_type evaluation_target_type not null,

  -- A form is a draft until somebody says it is finished. Only an active form
  -- may be assigned; deactivating one stops NEW assignments and leaves the ones
  -- in flight alone, which is why §10 reads the form through a definer function
  -- rather than off the table.
  is_active boolean not null default false,

  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- The stage. مرحلة, and it is a SECTION of one sheet rather than a round in
-- time: فريق التروية is stage 1 and الإعاشة is stage 2 of the same filling, by
-- the same person, in one sitting. The app draws them as steps because a form
-- of sixty questions is unreadable as a single scroll, not because the steps
-- are separately owned.
--
-- Every question belongs to a stage, including in a form that has only one.
-- Making the stage optional would mean two shapes for the same tree and two
-- code paths in everything that walks it.
create table if not exists evaluation_stages (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references evaluation_templates (id) on delete cascade,
  title text not null
    constraint evaluation_stage_title_not_blank check (btrim(title) <> ''),
  description text,
  sort_order int not null default 0
);

create table if not exists evaluation_questions (
  id uuid primary key default gen_random_uuid(),
  stage_id uuid not null references evaluation_stages (id) on delete cascade,
  kind evaluation_question_kind not null default 'choice',
  text text not null
    constraint evaluation_question_text_not_blank check (btrim(text) <> ''),

  -- What the question is worth: its full mark, which its best answer earns and
  -- no answer may exceed (§4). Numeric and not integer, because half a mark is
  -- a thing people write on forms.
  points numeric(7, 2) not null default 0
    constraint evaluation_question_points_not_negative check (points >= 0),

  -- Whether it may be left empty. Asked of both kinds: a written question
  -- carries no mark and can still be the one thing the sheet exists to collect.
  is_required boolean not null default true,

  sort_order int not null default 0,

  -- The rule that keeps prose out of the arithmetic. A written question with a
  -- mark on it would have to be scored by somebody, and the somebody would be
  -- the evaluator marking his own answer.
  constraint evaluation_written_question_has_no_mark
    check (kind <> 'text' or points = 0)
);

create table if not exists evaluation_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references evaluation_questions (id) on delete cascade,
  text text not null
    constraint evaluation_option_text_not_blank check (btrim(text) <> ''),
  -- What choosing this answer earns. Zero is an ordinary value and the commonest
  -- one: "لا" is an answer, not a missing answer.
  points numeric(7, 2) not null default 0
    constraint evaluation_option_points_not_negative check (points >= 0),
  sort_order int not null default 0
);

create index if not exists idx_evaluation_stages_template
  on evaluation_stages (template_id, sort_order);
create index if not exists idx_evaluation_questions_stage
  on evaluation_questions (stage_id, sort_order);
create index if not exists idx_evaluation_options_question
  on evaluation_options (question_id, sort_order);

drop trigger if exists evaluation_templates_set_updated_at on evaluation_templates;
create trigger evaluation_templates_set_updated_at
  before update on evaluation_templates
  for each row execute function set_updated_at();

-- ================================================== 3. what a form is worth
--
-- Derived, never stored. The total of a form is the sum of its questions and
-- the total of a stage is the sum of its own; a column holding either would be
-- a second copy of a fact that changes every time somebody edits a question,
-- and the copy is the one that would be shown.

create or replace function evaluation_stage_total(p_stage_id uuid)
  returns numeric
  language sql stable security definer set search_path = public as $$
  select coalesce(sum(q.points), 0)::numeric
    from evaluation_questions q
   where q.stage_id = p_stage_id;
$$;

create or replace function evaluation_template_total(p_template_id uuid)
  returns numeric
  language sql stable security definer set search_path = public as $$
  select coalesce(sum(q.points), 0)::numeric
    from evaluation_questions q
    join evaluation_stages s on s.id = q.stage_id
   where s.template_id = p_template_id;
$$;

-- =========================================================== 4. guarding a form
--
-- Two invariants a check constraint cannot state, because each needs to read a
-- row of another table:
--
--   * an answer is never worth more than the question it answers;
--   * a written question has no answers at all.
--
-- Both are DEFERRED constraint triggers, and that is the whole of why this
-- section is short. An immediate trigger would have to be satisfied statement
-- by statement, which makes the ORDER a form is saved in part of the rules:
-- lowering a question from 10 to 5 while lowering its answer from 10 to 3 is a
-- perfectly good edit that fails if the question goes first, and turning a
-- question into prose fails until its answers are gone. The editor would then
-- carry a topological sort of its own save — a second copy of these rules,
-- written in Dart, that would drift.
--
-- Deferred, the transaction may pass through any intermediate state it likes
-- and is judged only on what it leaves behind, which is the only state anybody
-- can read anyway.
--
-- One function for both tables. It ignores its own NEW beyond finding the
-- question, and re-reads the question whole at commit — by then the row it
-- fired for may have been deleted, or changed twice more.
--
-- NEW is reached through to_jsonb and NOT as `new.question_id`, and that is the
-- price of one function serving two tables. PL/pgSQL turns an expression into a
-- single SQL query and resolves EVERY field reference in it against NEW's row
-- type when it plans it — both arms of a CASE, not merely the arm that will
-- run. So `case tg_table_name when 'evaluation_options' then new.question_id
-- else new.id end` fails on an evaluation_questions row with
--
--     42703: record "new" has no field "question_id"
--
-- whichever branch the CASE would have taken. An IF statement would dodge it,
-- because plpgsql plans each statement on first execution and never plans a
-- branch it does not take — but that is a rule about lazy planning, and a guard
-- resting on one is a guard that breaks the day somebody tidies it back into an
-- expression. jsonb has no row type to disagree with: a key that is not there
-- reads as null, which is exactly the question being asked.
create or replace function evaluation_form_guard() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_row jsonb;
  v_question uuid;
  v_kind evaluation_question_kind;
  v_points numeric;
begin
  v_row := to_jsonb(new);

  -- An option carries the question it answers; a question IS the question.
  v_question := coalesce(
    nullif(v_row ->> 'question_id', ''),
    nullif(v_row ->> 'id', '')
  )::uuid;

  select q.kind, q.points into v_kind, v_points
    from evaluation_questions q where q.id = v_question;

  -- The question was deleted later in the same transaction. There is nothing
  -- left to be wrong.
  if v_kind is null then
    return null;
  end if;

  if v_kind = 'text' then
    if exists (select 1 from evaluation_options o
                where o.question_id = v_question) then
      raise exception 'evaluation_written_question_takes_no_options';
    end if;
    return null;
  end if;

  if exists (select 1 from evaluation_options o
              where o.question_id = v_question and o.points > v_points) then
    raise exception 'evaluation_option_worth_more_than_question';
  end if;

  return null;
end;
$$;

drop trigger if exists evaluation_options_guard on evaluation_options;
create constraint trigger evaluation_options_guard
  after insert or update on evaluation_options
  deferrable initially deferred
  for each row execute function evaluation_form_guard();

drop trigger if exists evaluation_questions_guard on evaluation_questions;
create constraint trigger evaluation_questions_guard
  after insert or update on evaluation_questions
  deferrable initially deferred
  for each row execute function evaluation_form_guard();

-- ========================================================== 5. the evaluation
--
-- One row per errand: this form, about this subject, by this person.
--
-- The target is four nullable foreign keys under the enum rather than a bare
-- `target_id uuid`, for the reason 0079 gives at length: without a key behind
-- it the label is unfalsifiable, and every predicate below would have to carry
-- the enum around as a discriminator that one of them will one day forget.

create table if not exists evaluations (
  id uuid primary key default gen_random_uuid(),

  -- RESTRICT, not CASCADE: a form that has been filled is a form that has
  -- become history. Deleting it must fail loudly rather than take the marks
  -- with it. Retiring a form is `is_active = false`, which is what that column
  -- is for.
  template_id uuid not null references evaluation_templates (id) on delete restrict,

  -- Which season's work this judges. Stamped at insert from the current season
  -- (§8) rather than sent by the client, and nullable only so that deleting a
  -- season does not delete the appraisals written during it.
  season_id uuid references seasons (id) on delete set null,

  target_type evaluation_target_type not null,
  target_profile_id uuid references profiles        (id) on delete set null,
  target_module_id  uuid references modules         (id) on delete set null,
  target_report_id  uuid references reports         (id) on delete set null,
  target_item_id    uuid references reference_items (id) on delete set null,

  -- Written once, at assignment. A sheet whose subject has since been deleted
  -- must still say who it was about, or it has stopped being a record.
  target_label text,

  -- The one person who may fill it. CASCADE: an errand belongs to the man it
  -- was given to, and when he is gone so is his half-finished sheet. A
  -- submitted one is history and is preserved by §13's log rather than by
  -- keeping an orphan row alive here.
  evaluator_id uuid not null references profiles (id) on delete cascade,
  assigned_by  uuid references profiles (id) on delete set null,

  -- What the office wants looked at, and by when. Both optional; neither is
  -- enforced. A due date that locks a form is a due date that loses the
  -- appraisal instead of the deadline.
  note text,
  due_on date,

  status evaluation_status not null default 'draft',
  submitted_at timestamptz,

  -- Frozen at submission and null before it. The total is stored beside the
  -- score deliberately: the form it came from will be edited, and "38" without
  -- the "out of 50" it was earned against means nothing a year later.
  score     numeric(9, 2),
  max_score numeric(9, 2),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- One-way, exactly as in 0079: "if a key is set it matches the type", never
  -- "a key must be set". The strict form would turn every `on delete set null`
  -- above into a constraint violation raised while deleting an unrelated hotel.
  -- Presence at birth is enforced by evaluations_resolve_target() below, which
  -- can tell an insert from a cascade.
  constraint evaluation_target_shape check (
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

  constraint evaluation_submission_is_whole check (
    (status = 'submitted') = (submitted_at is not null)
    and (status = 'submitted') = (score is not null)
    and (status = 'submitted') = (max_score is not null)
  )
);

create index if not exists idx_evaluations_evaluator
  on evaluations (evaluator_id, status, created_at desc);
create index if not exists idx_evaluations_created
  on evaluations (created_at desc);
create index if not exists idx_evaluations_template
  on evaluations (template_id);
create index if not exists idx_evaluations_target_profile
  on evaluations (target_profile_id, created_at desc)
  where target_type = 'employee';
create index if not exists idx_evaluations_target_module
  on evaluations (target_module_id) where target_module_id is not null;
create index if not exists idx_evaluations_target_report
  on evaluations (target_report_id) where target_report_id is not null;
create index if not exists idx_evaluations_target_item
  on evaluations (target_item_id) where target_item_id is not null;

drop trigger if exists evaluations_set_updated_at on evaluations;
create trigger evaluations_set_updated_at
  before update on evaluations
  for each row execute function set_updated_at();

-- ============================================ 6. the answers, and their wording
--
-- Rule 1 of the header lives in this table. Each answer carries a copy of what
-- was asked, what it was worth and which stage it stood in — so a submitted
-- sheet reads correctly after the form behind it has been reworded, re-marked,
-- re-ordered or deleted outright.
--
-- The pointers stay, and go null when their row goes. They are what lets a
-- draft be edited and what lets "how did everyone answer question 7" be asked
-- while question 7 still exists; they are never what the sheet is DRAWN from.

create table if not exists evaluation_answers (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null references evaluations (id) on delete cascade,

  question_id uuid references evaluation_questions (id) on delete set null,
  option_id   uuid references evaluation_options   (id) on delete set null,

  -- The snapshot, written by the trigger below and never by a caller.
  stage_title   text,
  question_text text,
  question_kind evaluation_question_kind not null default 'choice',
  answer_label  text,
  stage_order    int not null default 0,
  question_order int not null default 0,

  -- Prose, for a written question. Null on a choice.
  text_answer text,

  -- What this answer earned, and what the question was worth. Both zero for a
  -- written question, which is how the arithmetic below can be one sum over
  -- every row without a case for the kind.
  points     numeric(7, 2) not null default 0,
  max_points numeric(7, 2) not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- One answer per question per sheet. Nulls do not conflict in a unique index,
  -- which is the behaviour wanted: several answers to questions that have since
  -- been deleted may sit side by side, and none of them is a duplicate of
  -- anything.
  constraint evaluation_answer_is_once unique (evaluation_id, question_id)
);

create index if not exists idx_evaluation_answers_evaluation
  on evaluation_answers (evaluation_id, stage_order, question_order);
create index if not exists idx_evaluation_answers_question
  on evaluation_answers (question_id) where question_id is not null;

drop trigger if exists evaluation_answers_set_updated_at on evaluation_answers;
create trigger evaluation_answers_set_updated_at
  before update on evaluation_answers
  for each row execute function set_updated_at();

-- Fills the snapshot and refuses an answer that does not add up.
--
-- Four things are checked, and every one of them is a way a hand-built request
-- could otherwise score a sheet against a form it is not being filled on:
-- the question must exist, it must belong to THIS sheet's template, a chosen
-- option must belong to THAT question, and prose and choice must not be mixed.
create or replace function evaluation_answers_resolve() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_template uuid;
  q record;
  o record;
begin
  select e.template_id into v_template
    from evaluations e where e.id = new.evaluation_id;

  select qq.id, qq.kind, qq.text, qq.points, qq.sort_order,
         ss.title as stage_title, ss.sort_order as stage_order,
         ss.template_id
    into q
    from evaluation_questions qq
    join evaluation_stages ss on ss.id = qq.stage_id
   where qq.id = new.question_id;

  if q.id is null then
    raise exception 'evaluation_question_not_found';
  end if;
  if q.template_id is distinct from v_template then
    raise exception 'evaluation_question_not_on_this_form';
  end if;

  new.question_kind  := q.kind;
  new.question_text  := q.text;
  new.stage_title    := q.stage_title;
  new.stage_order    := coalesce(q.stage_order, 0);
  new.question_order := coalesce(q.sort_order, 0);
  new.max_points     := q.points;

  if q.kind = 'text' then
    -- Prose earns nothing, and there is nothing to have chosen.
    new.option_id    := null;
    new.answer_label := null;
    new.points       := 0;
    new.max_points   := 0;
    if btrim(coalesce(new.text_answer, '')) = '' then
      new.text_answer := null;
    end if;
  else
    new.text_answer := null;
    if new.option_id is null then
      new.answer_label := null;
      new.points := 0;
    else
      select oo.id, oo.text, oo.points into o
        from evaluation_options oo
       where oo.id = new.option_id and oo.question_id = q.id;
      if o.id is null then
        raise exception 'evaluation_option_not_on_this_question';
      end if;
      new.answer_label := o.text;
      new.points       := o.points;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists evaluation_answers_resolve on evaluation_answers;
create trigger evaluation_answers_resolve
  before insert or update on evaluation_answers
  for each row execute function evaluation_answers_resolve();

-- ================================================== 7. the permission catalog
--
-- Four actions, and the missing fifth is the point. There is no code for
-- FILLING one: an evaluation reaches its evaluator by name, the way a file
-- reaches its members by assignment. A permission there would mean "whoever is
-- trusted may judge whoever he likes", and an appraisal nobody asked for is not
-- an appraisal.

insert into permissions (code, description, sort_order)
values ('evaluations', 'Evaluations section', 11)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select v.code, v.description, p.id, v.sort_order
from (values
  ('evaluations.view',      'View every evaluation and its marks',      1),
  ('evaluations.templates', 'Build and edit the evaluation forms',      2),
  ('evaluations.assign',    'Open an evaluation and name its evaluator', 3),
  ('evaluations.delete',    'Delete an evaluation',                     4)
) as v(code, description, sort_order)
join permissions p on p.code = 'evaluations'
on conflict (code) do nothing;

-- The door first, on its own statement: the prerequisite trigger fires before
-- insert, and a single multi-row insert gives no order for it to be satisfied
-- in. Same shape as 0079's.
insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from (values ('evaluations.view', 'employees.view')) as v(code, requires_code)
join permissions c on c.code = v.code
join permissions r on r.code = v.requires_code
on conflict do nothing;

insert into permission_prerequisites (permission_id, requires_id)
select c.id, r.id
from (values
  ('evaluations.templates', 'evaluations.view'),
  ('evaluations.assign',    'evaluations.view'),
  ('evaluations.delete',    'evaluations.view')
) as v(code, requires_code)
join permissions c on c.code = v.code
join permissions r on r.code = v.requires_code
on conflict do nothing;

-- =========================================================== 8. the predicates
--
-- All of them before anything that uses them: a POLICY resolves the functions
-- named in it when the policy is created, so one defined further down would
-- fail this migration outright.

create or replace function can_read_all_evaluations() returns boolean
  language sql stable security definer set search_path = public as $$
  select is_admin() or has_permission('evaluations.view');
$$;

create or replace function can_edit_evaluation_forms() returns boolean
  language sql stable security definer set search_path = public as $$
  select is_admin() or has_permission('evaluations.templates');
$$;

create or replace function can_assign_evaluation() returns boolean
  language sql stable security definer set search_path = public as $$
  select is_admin() or has_permission('evaluations.assign');
$$;

-- Who the reader is to one sheet. 'subject' is tested first on purpose, for the
-- reason complaint_role() tests 'accused' first: a manager who is himself the
-- subject of an appraisal is not that appraisal's manager.
create or replace function evaluation_role(p_evaluation_id uuid) returns text
  language sql stable security definer set search_path = public as $$
  select case
    when e.target_type = 'employee' and e.target_profile_id = auth.uid()
      then 'subject'
    when e.evaluator_id = auth.uid() then 'evaluator'
    when can_read_all_evaluations() then 'manager'
  end
  from evaluations e where e.id = p_evaluation_id;
$$;

-- Stamps the label and the season, and refuses a sheet whose subject does not
-- add up. The label is computed by audit_record_label (0077) for the reason
-- 0079 gives: a second naming function is a second answer to "what is this row
-- called", and the two drift.
create or replace function evaluations_resolve_target() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_row jsonb;
  v_set text;
  v_table text;
  v_active boolean;
  v_form_target evaluation_target_type;
begin
  if tg_op = 'UPDATE'
     and (new.target_type  is distinct from old.target_type
       or new.template_id  is distinct from old.template_id
       or new.evaluator_id is distinct from old.evaluator_id) then
    -- An evaluation is of what it was opened about, on the form it was opened
    -- on, by the person it was given to. Changing any of the three is opening a
    -- different one, and that has its own row.
    raise exception 'evaluation_is_immutable';
  end if;

  if tg_op = 'INSERT' then
    select t.is_active, t.target_type into v_active, v_form_target
      from evaluation_templates t where t.id = new.template_id;

    if v_active is null then
      raise exception 'evaluation_form_not_found';
    end if;
    -- A retired form may be finished, never started.
    if not v_active then
      raise exception 'evaluation_form_not_active';
    end if;
    if v_form_target is distinct from new.target_type then
      raise exception 'evaluation_form_wrong_target_type';
    end if;

    if new.target_type <> 'other'
       and num_nonnulls(new.target_profile_id, new.target_module_id,
                        new.target_report_id, new.target_item_id) <> 1 then
      raise exception 'evaluation_target_missing';
    end if;

    -- Which set an item belongs to is the difference between a hotel and a
    -- cluster, and a check constraint may not run a subquery. The sets are
    -- named in the plural and the enum in the singular — the mismatch 0081 was
    -- written to fix, said here once so it is not fixed twice.
    if new.target_item_id is not null then
      select rs.code into v_set
        from reference_items ri
        join reference_sets rs on rs.id = ri.set_id
       where ri.id = new.target_item_id;
      if v_set is distinct from new.target_type::text || 's' then
        raise exception 'evaluation_target_wrong_set';
      end if;
    end if;

    if new.season_id is null then
      select s.id into new.season_id from seasons s where s.is_current;
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

drop trigger if exists evaluations_resolve_target on evaluations;
create trigger evaluations_resolve_target
  before insert or update on evaluations
  for each row execute function evaluations_resolve_target();

-- =========================================================== 9. row security

alter table evaluation_templates enable row level security;
alter table evaluation_stages    enable row level security;
alter table evaluation_questions enable row level security;
alter table evaluation_options   enable row level security;
alter table evaluations          enable row level security;
alter table evaluation_answers   enable row level security;

-- A form is not a secret — the man filling one has to read it — but a DRAFT
-- form is somebody's unfinished work and reads as an offer that is not on
-- offer. So: active forms to anyone signed in, everything to the office.
drop policy if exists evaluation_templates_select on evaluation_templates;
create policy evaluation_templates_select on evaluation_templates for select
  using (is_active or can_edit_evaluation_forms() or can_read_all_evaluations());

drop policy if exists evaluation_templates_write on evaluation_templates;
create policy evaluation_templates_write on evaluation_templates for all
  using (can_edit_evaluation_forms())
  with check (can_edit_evaluation_forms());

-- The three tables below the template inherit its answer, in one line each,
-- rather than repeating the rule three times in three shapes.
drop policy if exists evaluation_stages_select on evaluation_stages;
create policy evaluation_stages_select on evaluation_stages for select
  using (exists (select 1 from evaluation_templates t
                  where t.id = evaluation_stages.template_id));

drop policy if exists evaluation_stages_write on evaluation_stages;
create policy evaluation_stages_write on evaluation_stages for all
  using (can_edit_evaluation_forms())
  with check (can_edit_evaluation_forms());

drop policy if exists evaluation_questions_select on evaluation_questions;
create policy evaluation_questions_select on evaluation_questions for select
  using (exists (select 1 from evaluation_stages s
                  where s.id = evaluation_questions.stage_id));

drop policy if exists evaluation_questions_write on evaluation_questions;
create policy evaluation_questions_write on evaluation_questions for all
  using (can_edit_evaluation_forms())
  with check (can_edit_evaluation_forms());

drop policy if exists evaluation_options_select on evaluation_options;
create policy evaluation_options_select on evaluation_options for select
  using (exists (select 1 from evaluation_questions q
                  where q.id = evaluation_options.question_id));

drop policy if exists evaluation_options_write on evaluation_options;
create policy evaluation_options_write on evaluation_options for all
  using (can_edit_evaluation_forms())
  with check (can_edit_evaluation_forms());

-- Note what is absent: `target_profile_id = auth.uid()`. The subject has no
-- direct read at all, because a row he can select is a row whose evaluator_id
-- he can select. He reaches his own results through §10.
--
-- And a manager is fenced off his own sheet, or `evaluations.view` would be the
-- way to find out who marked you, and the first person to notice would be the
-- one it was hidden from.
drop policy if exists evaluations_select on evaluations;
create policy evaluations_select on evaluations for select
  using (
    evaluator_id = auth.uid()
    or (can_read_all_evaluations()
        and (target_type <> 'employee'
             or target_profile_id is distinct from auth.uid()))
  );

drop policy if exists evaluations_insert on evaluations;
create policy evaluations_insert on evaluations for insert
  with check (assigned_by = auth.uid() and can_assign_evaluation());

-- THERE IS NO UPDATE POLICY, and its absence is rule 3 of the header. A score,
-- a status and a submission time are not things a client may write — not the
-- evaluator's client and not the assigning manager's. Everything that moves
-- them is a security-definer function in §11, each of which knows which of the
-- two people is calling and refuses the other.

drop policy if exists evaluations_delete on evaluations;
create policy evaluations_delete on evaluations for delete
  using (
    is_admin()
    or has_permission('evaluations.delete')
    -- Handing out an errand and taking it back before it was touched is one
    -- act. Once an answer exists somebody has done work, and withdrawing it is
    -- a deletion like any other.
    or (assigned_by = auth.uid()
        and status = 'draft'
        and not exists (select 1 from evaluation_answers a
                         where a.evaluation_id = evaluations.id))
  );

-- Answers follow their sheet, which is where the whole rule already lives. No
-- write policy at all: they are written by save_evaluation() alone.
drop policy if exists evaluation_answers_select on evaluation_answers;
create policy evaluation_answers_select on evaluation_answers for select
  using (exists (select 1 from evaluations e
                  where e.id = evaluation_answers.evaluation_id));

-- ========================================================= 10. what is readable

-- One form, whole, as json: stages, their questions, their options, in order.
--
-- Through a function rather than three selects because a form is one thing and
-- arrives in one round trip either way — and because the man filling a sheet
-- must be able to read the form it is on even after the office retired it, and
-- the SELECT policy above would already have said no.
create or replace function evaluation_form(p_template_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'id', t.id,
    'title', t.title,
    'description', t.description,
    'target_type', t.target_type::text,
    'is_active', t.is_active,
    'total_points', evaluation_template_total(t.id),
    'stages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id,
        'title', s.title,
        'description', s.description,
        'sort_order', s.sort_order,
        'total_points', evaluation_stage_total(s.id),
        'questions', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', q.id,
            'kind', q.kind::text,
            'text', q.text,
            'points', q.points,
            'is_required', q.is_required,
            'sort_order', q.sort_order,
            'options', coalesce((
              select jsonb_agg(jsonb_build_object(
                'id', o.id, 'text', o.text,
                'points', o.points, 'sort_order', o.sort_order)
                order by o.sort_order, o.text)
                from evaluation_options o where o.question_id = q.id
            ), '[]'::jsonb))
            order by q.sort_order, q.text)
            from evaluation_questions q where q.stage_id = s.id
        ), '[]'::jsonb))
        order by s.sort_order, s.title)
        from evaluation_stages s where s.template_id = t.id
    ), '[]'::jsonb)
  ) into v
  from evaluation_templates t
  where t.id = p_template_id
    and (t.is_active or can_edit_evaluation_forms() or can_read_all_evaluations()
         or exists (select 1 from evaluations e
                     where e.template_id = t.id and e.evaluator_id = auth.uid()));

  if v is null then
    raise exception 'evaluation_form_not_found';
  end if;
  return v;
end;
$$;

-- The catalog of forms, with the two numbers the office actually wants beside
-- each: what it is worth, and how many sheets are out on it.
create or replace function evaluation_forms_list(
  p_include_inactive boolean default true,
  p_target_type text default null,
  p_query text default null
) returns table (
  id uuid,
  title text,
  description text,
  target_type text,
  is_active boolean,
  stage_count int,
  question_count int,
  total_points numeric,
  evaluation_count int,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not authorized';
  end if;
  if not (can_edit_evaluation_forms() or can_read_all_evaluations()
          or can_assign_evaluation()) then
    raise exception 'not authorized';
  end if;

  return query
  select t.id, t.title, t.description, t.target_type::text, t.is_active,
         (select count(*)::int from evaluation_stages s where s.template_id = t.id),
         (select count(*)::int from evaluation_questions q
            join evaluation_stages s on s.id = q.stage_id
           where s.template_id = t.id),
         evaluation_template_total(t.id),
         (select count(*)::int from evaluations e where e.template_id = t.id),
         t.created_at, t.updated_at
    from evaluation_templates t
   where (p_include_inactive or t.is_active)
     and (p_target_type is null or t.target_type::text = p_target_type)
     and (p_query is null or btrim(p_query) = ''
          or ar_fold(t.title) like '%' || ar_fold(p_query) || '%'
          or ar_fold(coalesce(t.description, '')) like '%' || ar_fold(p_query) || '%')
   order by t.is_active desc, t.updated_at desc;
end;
$$;

-- The register. 'mine' is what I was asked to fill; 'all' is everything and
-- asks for the permission. Never a row where the caller is the subject — that
-- is what evaluations_about_me is for, and it is the only door that redacts.
create or replace function evaluations_list(
  p_scope text default 'mine',
  p_status text default null,
  p_target_type text default null,
  p_target_id uuid default null,
  p_template_id uuid default null,
  p_query text default null,
  p_limit int default 100,
  p_before timestamptz default null
) returns table (
  id uuid,
  created_at timestamptz,
  template_id uuid,
  template_title text,
  target_type text,
  target_id uuid,
  target_label text,
  evaluator_id uuid,
  evaluator_name text,
  evaluator_photo_url text,
  note text,
  due_on date,
  status text,
  submitted_at timestamptz,
  score numeric,
  max_score numeric,
  answered_count int,
  question_count int,
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
  if v_all and not can_read_all_evaluations() then
    raise exception 'not authorized';
  end if;

  return query
  select e.id, e.created_at, e.template_id, t.title,
         e.target_type::text,
         coalesce(e.target_profile_id, e.target_module_id,
                  e.target_report_id, e.target_item_id),
         e.target_label,
         e.evaluator_id,
         nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
         p.photo_url,
         e.note, e.due_on,
         e.status::text, e.submitted_at, e.score, e.max_score,
         (select count(*)::int from evaluation_answers a
           where a.evaluation_id = e.id
             and (a.option_id is not null or a.text_answer is not null)),
         (select count(*)::int from evaluation_questions q
            join evaluation_stages s on s.id = q.stage_id
           where s.template_id = e.template_id),
         case when e.evaluator_id = v_uid then 'evaluator' else 'manager' end
    from evaluations e
    join evaluation_templates t on t.id = e.template_id
    left join profiles p on p.id = e.evaluator_id
   where (e.target_type <> 'employee' or e.target_profile_id is distinct from v_uid)
     and (case when v_all then true else e.evaluator_id = v_uid end)
     and (p_status is null or e.status::text = p_status)
     and (p_target_type is null or e.target_type::text = p_target_type)
     and (p_target_id is null
          or p_target_id in (e.target_profile_id, e.target_module_id,
                             e.target_report_id, e.target_item_id))
     and (p_template_id is null or e.template_id = p_template_id)
     and (p_query is null or btrim(p_query) = ''
          or ar_fold(coalesce(e.target_label, '')) like '%' || ar_fold(p_query) || '%'
          or ar_fold(t.title) like '%' || ar_fold(p_query) || '%')
     and (p_before is null or e.created_at < p_before)
   order by e.created_at desc
   limit least(greatest(coalesce(p_limit, 100), 1), 200);
end;
$$;

-- One sheet, whole: the header, every stage, every question, and the answer
-- given to each — the form and the filling in one shape, so the screen that
-- fills a draft and the screen that reads a finished one are the same screen.
--
-- The rule of §2 applies here and is the reason this is a function: a SUBMITTED
-- sheet is drawn from its own answers, wording and all, and never from the form
-- — which may have been reworded since. A DRAFT is drawn from the form, because
-- a draft is still being filled against it.
--
-- And the evaluator is named only to a reader who may know it. `my_role` always
-- comes back, so the app can label an unnamed sheet without naming anybody.
create or replace function evaluation_sheet(p_evaluation_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  e evaluations;
  v_role text;
  v_may_name boolean;
  v_body jsonb;
  v_head jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authorized';
  end if;

  select * into e from evaluations where id = p_evaluation_id;
  if e.id is null then
    raise exception 'evaluation_not_found';
  end if;

  v_role := evaluation_role(p_evaluation_id);
  if v_role is null then
    raise exception 'not authorized';
  end if;
  v_may_name := v_role <> 'subject';

  if e.status = 'submitted' then
    -- From the answers. Grouped by the stage each answer remembers standing in,
    -- which is why stage_order is on the row and not looked up.
    select coalesce(jsonb_agg(stage order by stage_order), '[]'::jsonb)
      into v_body
      from (
        select a.stage_order,
               jsonb_build_object(
                 'title', a.stage_title,
                 'sort_order', a.stage_order,
                 'points', sum(a.points),
                 'total_points', sum(a.max_points),
                 'questions', jsonb_agg(jsonb_build_object(
                   'question_id', a.question_id,
                   'kind', a.question_kind::text,
                   'text', a.question_text,
                   'points', a.points,
                   'total_points', a.max_points,
                   'option_id', a.option_id,
                   'answer', a.answer_label,
                   'text_answer', a.text_answer)
                   order by a.question_order)
               ) as stage
          from evaluation_answers a
         where a.evaluation_id = e.id
         group by a.stage_order, a.stage_title
      ) grouped;
  else
    -- From the form, with whatever has been answered so far laid over it.
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', s.id,
             'title', s.title,
             'description', s.description,
             'sort_order', s.sort_order,
             'total_points', evaluation_stage_total(s.id),
             'points', coalesce((
               select sum(a.points) from evaluation_answers a
                 join evaluation_questions q2 on q2.id = a.question_id
                where a.evaluation_id = e.id and q2.stage_id = s.id), 0),
             'questions', coalesce((
               select jsonb_agg(jsonb_build_object(
                 'question_id', q.id,
                 'kind', q.kind::text,
                 'text', q.text,
                 'total_points', q.points,
                 'is_required', q.is_required,
                 'options', coalesce((
                   select jsonb_agg(jsonb_build_object(
                     'id', o.id, 'text', o.text, 'points', o.points)
                     order by o.sort_order, o.text)
                     from evaluation_options o where o.question_id = q.id
                 ), '[]'::jsonb),
                 'option_id', (select a.option_id from evaluation_answers a
                                where a.evaluation_id = e.id and a.question_id = q.id),
                 'answer', (select a.answer_label from evaluation_answers a
                             where a.evaluation_id = e.id and a.question_id = q.id),
                 'text_answer', (select a.text_answer from evaluation_answers a
                                  where a.evaluation_id = e.id and a.question_id = q.id),
                 'points', coalesce((select a.points from evaluation_answers a
                                      where a.evaluation_id = e.id
                                        and a.question_id = q.id), 0))
                 order by q.sort_order, q.text)
                 from evaluation_questions q where q.stage_id = s.id
             ), '[]'::jsonb))
             order by s.sort_order, s.title), '[]'::jsonb)
      into v_body
      from evaluation_stages s
     where s.template_id = e.template_id;
  end if;

  select jsonb_build_object(
    'id', e.id,
    'template_id', e.template_id,
    'template_title', t.title,
    'template_description', t.description,
    'target_type', e.target_type::text,
    'target_id', coalesce(e.target_profile_id, e.target_module_id,
                          e.target_report_id, e.target_item_id),
    'target_label', e.target_label,
    'note', e.note,
    'due_on', e.due_on,
    'status', e.status::text,
    'created_at', e.created_at,
    'submitted_at', e.submitted_at,
    'score', e.score,
    'max_score', coalesce(e.max_score, evaluation_template_total(e.template_id)),
    'my_role', v_role,
    'can_fill', (e.evaluator_id = auth.uid() and e.status = 'draft'),
    'evaluator_id',   case when v_may_name then e.evaluator_id end,
    'evaluator_name', case when v_may_name then
      nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), '') end,
    'evaluator_photo_url', case when v_may_name then p.photo_url end,
    'stages', v_body
  ) into v_head
  from evaluation_templates t
  left join profiles p on p.id = e.evaluator_id
  where t.id = e.template_id;

  return v_head;
end;
$$;

-- What was written about the caller. Takes no argument, on 0059's rule: there
-- is nobody else it could be asked about, which is a stronger guarantee than a
-- check that it is being asked about the right person.
--
-- evaluator_id and assigned_by are not columns of the result. You do not null a
-- field you never selected, and that is the whole advantage of answering
-- through a function instead of through a view.
--
-- Drafts are absent. A mark that has not been submitted is not a judgement yet,
-- and showing a man a half-finished one is showing him a work in progress about
-- himself.
create or replace function evaluations_about_me(
  p_limit int default 50,
  p_before timestamptz default null
) returns table (
  id uuid,
  submitted_at timestamptz,
  template_title text,
  score numeric,
  max_score numeric,
  percent numeric
)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not authorized';
  end if;

  return query
  select e.id, e.submitted_at, t.title, e.score, e.max_score,
         case when coalesce(e.max_score, 0) > 0
              then round(e.score * 100 / e.max_score, 1) end
    from evaluations e
    join evaluation_templates t on t.id = e.template_id
   where e.target_type = 'employee'
     and e.target_profile_id = auth.uid()
     and e.status = 'submitted'
     and (p_before is null or e.submitted_at < p_before)
   order by e.submitted_at desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

-- Numbers about one subject, for the panel on its page. Here is where an id
-- argument belongs: it is asked about somebody, and it answers with counts and
-- an average and never with a name.
--
-- Answers for any of the seven kinds, not only for people — a hotel's standing
-- is the same question asked of a different table, and one function is one
-- answer to it.
create or replace function evaluations_about(
  p_target_type text,
  p_target_id uuid
) returns table (
  submitted_count int,
  pending_count int,
  average_score numeric,
  average_percent numeric,
  last_submitted_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_type evaluation_target_type := p_target_type::evaluation_target_type;
begin
  if not (can_read_all_evaluations()
          or (v_type = 'employee' and p_target_id = auth.uid())) then
    raise exception 'not authorized';
  end if;

  return query
  with mine as (
    select e.* from evaluations e
     where e.target_type = v_type
       and p_target_id in (e.target_profile_id, e.target_module_id,
                           e.target_report_id, e.target_item_id)
  )
  select (select count(*)::int from mine where status = 'submitted'),
         (select count(*)::int from mine where status = 'draft'),
         (select round(avg(score), 2) from mine where status = 'submitted'),
         (select round(avg(score * 100 / nullif(max_score, 0)), 1)
            from mine where status = 'submitted'),
         (select max(submitted_at) from mine where status = 'submitted');
end;
$$;

-- There is deliberately NO function here for "who may be handed the errand".
--
-- There was one, and it was wrong twice over: it read `job_titles.name_ar`, a
-- column that has never existed (0002 calls it `name`, and 0046 explains why it
-- was not renamed when `name_en` arrived beside it) — and, more to the point,
-- it answered a question this feature should not be answering on its own. The
-- app already has a page for choosing a person: `assignable_employees` (0029,
-- filtered in 0065) and the picker built on it, which searches, filters by post
-- and city, and — the part that matters when handing out an appraisal — lists
-- every file the candidate is already carrying this season.
--
-- So the evaluator is chosen there. The pool is this season's participants,
-- which is a narrowing and the right one: somebody who is not in the season is
-- not doing the season's work.

-- What an evaluation of this kind may be opened about — an id, a name, and a
-- face where the kind has one.
--
-- Word for word the argument of 0082, applied to a different door: the tables
-- behind these seven kinds are hidden by row security that is right, and the
-- answer to a question it cannot express is a function that returns less, not a
-- policy that shows more. Three columns leave here. Not a phone, not a
-- document, not an account's standing.
create or replace function evaluation_targets(
  p_target_type text,
  p_query text default null,
  p_limit int default 100
)
returns table (id uuid, name text, photo_url text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_type evaluation_target_type := p_target_type::evaluation_target_type;
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 200);
begin
  if not can_assign_evaluation() then
    return;
  end if;

  case v_type
    when 'employee' then
      -- Self included, unlike the complaints picker: an office may perfectly
      -- well ask a man to appraise himself, and refusing it here would be the
      -- app deciding an administrative question.
      return query
      select p.id,
             nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
             p.photo_url
        from profiles p
       where p.account_status = 'approved'
         and (v_query is null
              or concat_ws(' ', p.first_name, p.father_name, p.surname)
                   ilike '%' || v_query || '%')
       order by 2
       limit v_limit;

    when 'module' then
      -- Drafts included, and this is the difference from complaints: an
      -- unreleased file is exactly the thing an office may want appraised
      -- before it is released, and only the office reaches this function.
      return query
      select m.id, audit_record_label('modules', to_jsonb(m)), null::text
        from modules m
       where (v_query is null
              or audit_record_label('modules', to_jsonb(m))
                   ilike '%' || v_query || '%')
       order by m.created_at desc
       limit v_limit;

    when 'report' then
      return query
      select r.id, r.title, null::text
        from reports r
       where (v_query is null or coalesce(r.title, '') ilike '%' || v_query || '%')
       order by r.updated_at desc
       limit v_limit;

    when 'other' then
      return;

    else
      -- hotel, cluster, group. The set's code is the enum value's own name in
      -- the plural.
      return query
      select ri.id, ri.name_ar, null::text
        from reference_items ri
        join reference_sets rs on rs.id = ri.set_id
       where rs.code = v_type::text || 's'
         and ri.is_active
         and (v_query is null or ri.name_ar ilike '%' || v_query || '%')
       order by ri.sort_order
       limit v_limit;
  end case;
end;
$$;

-- ========================================================= 11. what is writable

-- Saving a form is one act, so it is one transaction — the argument of 0074,
-- and here it is worth more: a form is a three-level tree, and an editor that
-- wrote it level by level would leave a stage with no questions or a question
-- with no answers behind on any dropped connection.
--
-- SECURITY INVOKER on purpose: every policy of §9 and both guards of §4 apply
-- to the statements inside exactly as they would to the separate requests this
-- replaces.
--
-- Ids sent back are kept, ids absent are deleted, and sort order is the array's
-- own position — which is what makes drag-to-reorder a save rather than a
-- separate call per row.
create or replace function save_evaluation_form(
  p_template_id uuid,          -- null = create
  p_title text,
  p_description text,
  p_target_type text,
  p_is_active boolean,
  -- [{"id": uuid|null, "title": "...", "description": "...",
  --   "questions": [{"id": uuid|null, "kind": "choice"|"text", "text": "...",
  --                  "points": 10, "is_required": true,
  --                  "options": [{"id": uuid|null, "text": "...", "points": 10}]}]}]
  p_stages jsonb default '[]'::jsonb
) returns uuid
  language plpgsql security invoker set search_path = public as $$
declare
  v_id uuid;
  v_type evaluation_target_type := p_target_type::evaluation_target_type;
  v_stage jsonb;
  v_question jsonb;
  v_option jsonb;
  v_stage_id uuid;
  v_question_id uuid;
  v_option_id uuid;
  v_stage_ord int := 0;
  v_question_ord int;
  v_option_ord int;
  v_kept_stages uuid[] := '{}';
  v_kept_questions uuid[] := '{}';
  v_kept_options uuid[] := '{}';
begin
  if p_template_id is null then
    insert into evaluation_templates
      (title, description, target_type, is_active, created_by)
    values
      (p_title, p_description, v_type, coalesce(p_is_active, false), auth.uid())
    returning id into v_id;
  else
    v_id := p_template_id;
    -- What a form is FOR cannot change once anything has been opened on it:
    -- every sheet already out would be about a kind of thing the form no longer
    -- describes. Before that, it is an ordinary edit.
    if exists (select 1 from evaluations e where e.template_id = v_id)
       and exists (select 1 from evaluation_templates t
                    where t.id = v_id and t.target_type is distinct from v_type) then
      raise exception 'evaluation_form_in_use';
    end if;

    update evaluation_templates
       set title = p_title,
           description = p_description,
           target_type = v_type,
           is_active = coalesce(p_is_active, false)
     where id = v_id;
    -- Zero rows updated under RLS reads the same as the form not existing:
    -- either way there is nothing here for this caller to save into.
    if not found then
      raise exception 'evaluation_form_not_found';
    end if;
  end if;

  for v_stage in select value from jsonb_array_elements(coalesce(p_stages, '[]'::jsonb))
  loop
    v_stage_ord := v_stage_ord + 1;
    v_stage_id := nullif(v_stage ->> 'id', '')::uuid;

    if v_stage_id is null then
      insert into evaluation_stages (template_id, title, description, sort_order)
      values (v_id, v_stage ->> 'title', nullif(v_stage ->> 'description', ''),
              v_stage_ord)
      returning id into v_stage_id;
    else
      update evaluation_stages
         set title = v_stage ->> 'title',
             description = nullif(v_stage ->> 'description', ''),
             sort_order = v_stage_ord
       where id = v_stage_id and template_id = v_id;
    end if;
    v_kept_stages := v_kept_stages || v_stage_id;

    v_question_ord := 0;
    for v_question in
      select value from jsonb_array_elements(coalesce(v_stage -> 'questions', '[]'::jsonb))
    loop
      v_question_ord := v_question_ord + 1;
      v_question_id := nullif(v_question ->> 'id', '')::uuid;

      if v_question_id is null then
        insert into evaluation_questions
          (stage_id, kind, text, points, is_required, sort_order)
        values (
          v_stage_id,
          coalesce((v_question ->> 'kind')::evaluation_question_kind, 'choice'),
          v_question ->> 'text',
          coalesce((v_question ->> 'points')::numeric, 0),
          coalesce((v_question ->> 'is_required')::boolean, true),
          v_question_ord)
        returning id into v_question_id;
      else
        -- The order the three levels are written in does not matter: §4's
        -- guards are deferred, and a form is judged on what this transaction
        -- leaves behind rather than on how it got there.
        update evaluation_questions
           set stage_id = v_stage_id,
               kind = coalesce((v_question ->> 'kind')::evaluation_question_kind,
                               'choice'),
               text = v_question ->> 'text',
               points = coalesce((v_question ->> 'points')::numeric, 0),
               is_required = coalesce((v_question ->> 'is_required')::boolean, true),
               sort_order = v_question_ord
         where id = v_question_id;
      end if;
      v_kept_questions := v_kept_questions || v_question_id;

      v_option_ord := 0;
      for v_option in
        select value from jsonb_array_elements(
          coalesce(v_question -> 'options', '[]'::jsonb))
      loop
        v_option_ord := v_option_ord + 1;
        v_option_id := nullif(v_option ->> 'id', '')::uuid;
        if v_option_id is null then
          insert into evaluation_options (question_id, text, points, sort_order)
          values (v_question_id, v_option ->> 'text',
                  coalesce((v_option ->> 'points')::numeric, 0), v_option_ord)
          returning id into v_option_id;
        else
          update evaluation_options
             set question_id = v_question_id,
                 text = v_option ->> 'text',
                 points = coalesce((v_option ->> 'points')::numeric, 0),
                 sort_order = v_option_ord
           where id = v_option_id;
        end if;
        v_kept_options := v_kept_options || v_option_id;
      end loop;
    end loop;
  end loop;

  -- Every delete AFTER every write, and scoped to the whole template rather
  -- than to the branch that was just walked.
  --
  -- Deleting inside the loops looks tidier and is wrong the first time a
  -- question is dragged from one stage to another: at the moment stage 1's
  -- sweep runs, the question has not been re-parented yet — that happens when
  -- stage 2 comes round — so it is still stage 1's and not yet in the kept
  -- list, and the sweep takes it. The UPDATE that would have moved it then
  -- matches nothing, and the question is gone from a save that was only meant
  -- to move it. Sweeping at the end means no row is judged before the payload
  -- has finished having its say about it.
  delete from evaluation_options o
   using evaluation_questions q, evaluation_stages s
   where o.question_id = q.id
     and q.stage_id = s.id
     and s.template_id = v_id
     and not (o.id = any (v_kept_options));

  delete from evaluation_questions q
   using evaluation_stages s
   where q.stage_id = s.id
     and s.template_id = v_id
     and not (q.id = any (v_kept_questions));

  delete from evaluation_stages s
   where s.template_id = v_id
     and not (s.id = any (v_kept_stages));

  return v_id;
end;
$$;

-- Opening them. INVOKER, like file_complaint and for the same reason: every
-- policy and the resolve trigger apply to these inserts exactly as they would
-- to plain ones, and the ids come back because the app shows what it made.
--
-- ONE ERRAND PER PAIR, and this is the whole shape of the feature.
--
-- An office does not name one judge and one subject. It names the three people
-- who will appraise, and the eleven files to be appraised, and means all
-- thirty-three — so the picker takes sets and this takes arrays, and the cross
-- product is written out as thirty-three rows rather than held as one row with
-- lists in it.
--
-- The alternative — one sheet carrying several evaluators — is not a smaller
-- version of this, it is a broken one. `evaluation_answers` is unique on
-- (evaluation, question): the second judge's answer would overwrite the first's
-- rather than stand beside it, one score would have to stand for two verdicts,
-- and the anonymity of §26.9 is defined per evaluator and would have nothing
-- left to attach to. Independent judgements are the point of an appraisal, and
-- independence is a row each.
--
-- All or nothing: a function body is one transaction, so a set that fails
-- halfway leaves no half-issued batch behind for somebody to finish by hand.
create or replace function assign_evaluations(
  p_template_id uuid,
  p_target_type text,
  -- Empty (or null) for `other`, which points at nothing. Any other kind with
  -- an empty array opens nothing at all, which is the honest answer to being
  -- asked for no subjects.
  p_target_ids uuid[],
  p_evaluator_ids uuid[],
  p_note text default null,
  p_due_on date default null
) returns setof uuid
  language plpgsql security invoker set search_path = public as $$
declare
  v_type evaluation_target_type := p_target_type::evaluation_target_type;
  v_targets uuid[] := coalesce(p_target_ids, '{}');
  v_evaluators uuid[] := coalesce(p_evaluator_ids, '{}');
  v_target uuid;
  v_evaluator uuid;
  v_id uuid;
begin
  if array_length(v_evaluators, 1) is null then
    raise exception 'evaluation_evaluator_missing';
  end if;

  -- `other` has nothing to point at, so it runs the loop once with a null
  -- subject rather than not at all.
  if v_type = 'other' then
    v_targets := array[null::uuid];
  elsif array_length(v_targets, 1) is null then
    raise exception 'evaluation_target_missing';
  end if;

  foreach v_target in array v_targets loop
    foreach v_evaluator in array v_evaluators loop
      insert into evaluations (
        template_id, target_type, evaluator_id, assigned_by, note, due_on,
        target_profile_id, target_module_id, target_report_id, target_item_id
      ) values (
        p_template_id, v_type, v_evaluator, auth.uid(),
        nullif(btrim(p_note), ''), p_due_on,
        case when v_type = 'employee' then v_target end,
        case when v_type = 'module'   then v_target end,
        case when v_type = 'report'   then v_target end,
        case when v_type in ('hotel', 'cluster', 'group') then v_target end
      )
      returning id into v_id;

      return next v_id;
    end loop;
  end loop;
end;
$$;

-- The single case, kept as a thin call on the plural one so that "what happens
-- when an evaluation is opened" has exactly one answer. Anything already
-- pointing at this name keeps working.

create or replace function assign_evaluation(
  p_template_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_evaluator_id uuid,
  p_note text default null,
  p_due_on date default null
) returns uuid
  language sql security invoker set search_path = public as $$
  select assign_evaluations(
    p_template_id, p_target_type,
    case when p_target_id is null then '{}'::uuid[] else array[p_target_id] end,
    array[p_evaluator_id], p_note, p_due_on)
  limit 1;
$$;

-- Filling one, and — when asked — finishing it. One call, one transaction, and
-- rule 3 of the header: this is the only thing in the schema that writes a
-- score, and it computes that score from the answers rather than accepting one.
--
-- DEFINER because there is no UPDATE policy for it to run under, which is the
-- point rather than an obstacle.
--
-- p_answers: [{"question_id": uuid, "option_id": uuid|null, "text": "..."|null}]
-- Answers absent from the array are DELETED — clearing a question is saying
-- nothing about it, and a save is the whole state of the sheet.
create or replace function save_evaluation(
  p_evaluation_id uuid,
  p_answers jsonb default '[]'::jsonb,
  p_submit boolean default false
) returns jsonb
  language plpgsql security definer set search_path = public as $$
declare
  e evaluations;
  v_answer jsonb;
  v_kept uuid[] := '{}';
  v_missing text;
  v_score numeric;
  v_max numeric;
begin
  select * into e from evaluations where id = p_evaluation_id;
  if e.id is null then
    raise exception 'evaluation_not_found';
  end if;
  if e.evaluator_id is distinct from auth.uid() then
    raise exception 'not authorized';
  end if;
  if e.status = 'submitted' then
    raise exception 'evaluation_already_submitted';
  end if;

  for v_answer in select value from jsonb_array_elements(coalesce(p_answers, '[]'::jsonb))
  loop
    insert into evaluation_answers
      (evaluation_id, question_id, option_id, text_answer)
    values (
      e.id,
      (v_answer ->> 'question_id')::uuid,
      nullif(v_answer ->> 'option_id', '')::uuid,
      nullif(btrim(coalesce(v_answer ->> 'text', '')), ''))
    on conflict (evaluation_id, question_id) do update
       set option_id   = excluded.option_id,
           text_answer = excluded.text_answer;

    v_kept := v_kept || (v_answer ->> 'question_id')::uuid;
  end loop;

  delete from evaluation_answers a
   where a.evaluation_id = e.id
     and (a.question_id is null or not (a.question_id = any (v_kept)));

  if not coalesce(p_submit, false) then
    return jsonb_build_object('status', 'draft', 'score', null,
                              'max_score', evaluation_template_total(e.template_id));
  end if;

  -- Finishing. Every required question of the form AS IT STANDS NOW must have
  -- an answer — the form may have gained one since the sheet was opened, and a
  -- sheet submitted against yesterday's requirements is a sheet with a hole in
  -- it.
  select q.text into v_missing
    from evaluation_questions q
    join evaluation_stages s on s.id = q.stage_id
   where s.template_id = e.template_id
     and q.is_required
     and not exists (
       select 1 from evaluation_answers a
        where a.evaluation_id = e.id
          and a.question_id = q.id
          and (a.option_id is not null or a.text_answer is not null))
   order by s.sort_order, q.sort_order
   limit 1;

  if v_missing is not null then
    raise exception 'evaluation_incomplete: %', v_missing;
  end if;

  -- The score is the answers; the total is the FORM. They are read from
  -- different places on purpose: a question left blank because it was optional
  -- still counts against the total it was worth, or a sheet could be improved
  -- by skipping the questions it would have done badly on.
  select coalesce(sum(a.points), 0) into v_score
    from evaluation_answers a where a.evaluation_id = e.id;
  v_max := evaluation_template_total(e.template_id);

  update evaluations
     set status = 'submitted',
         submitted_at = now(),
         score = v_score,
         max_score = v_max
   where id = e.id;

  return jsonb_build_object('status', 'submitted', 'score', v_score,
                            'max_score', v_max);
end;
$$;

-- Sending one back. The office's act, and it keeps the answers: what is undone
-- is the finishing, not the work.
create or replace function reopen_evaluation(p_evaluation_id uuid)
  returns void
  language plpgsql security definer set search_path = public as $$
begin
  if not can_assign_evaluation() then
    raise exception 'not authorized';
  end if;
  update evaluations
     set status = 'draft', submitted_at = null, score = null, max_score = null
   where id = p_evaluation_id and status = 'submitted';
end;
$$;

-- The two things about an errand that are not the errand: what to look at, and
-- by when. Editable because both are the office talking to the evaluator, and
-- neither touches a mark. The subject, the form and the evaluator are refused
-- by the trigger in §8 whichever door the write comes through.
create or replace function update_evaluation_assignment(
  p_evaluation_id uuid,
  p_note text default null,
  p_due_on date default null
) returns void
  language plpgsql security definer set search_path = public as $$
begin
  if not can_assign_evaluation() then
    raise exception 'not authorized';
  end if;
  update evaluations
     set note = nullif(btrim(coalesce(p_note, '')), ''),
         due_on = p_due_on
   where id = p_evaluation_id;
end;
$$;

-- ============================================================ 12. the notices

-- The errand, told to the man who has it. Without this the feature depends on
-- somebody happening to open a screen, and an appraisal nobody knew was theirs
-- is an appraisal that is late.
--
-- A trigger rather than a call inside assign_evaluation, so it fires for a
-- plain insert too and the notice does not depend on which door was used.
create or replace function evaluations_notify_evaluator() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_title text;
begin
  select t.title into v_title
    from evaluation_templates t where t.id = new.template_id;

  insert into notifications (recipient_id, sender_id, title, body, data)
  values (
    new.evaluator_id,
    auth.uid(),
    'كُلِّفت بتقييم',
    concat_ws(' — ', v_title, nullif(new.target_label, '')),
    jsonb_build_object('type', 'evaluation_assigned', 'evaluation_id', new.id)
  );
  return null;
exception when others then
  -- Best effort, always: the assignment is the record, and a notice that failed
  -- to send must never take it down with it.
  return null;
end;
$$;

drop trigger if exists evaluations_notify_evaluator on evaluations;
create trigger evaluations_notify_evaluator
  after insert on evaluations
  for each row execute function evaluations_notify_evaluator();

-- And the subject, when it is finished — told THAT, never by whom. The row is
-- written with a null sender for the reason 0079 writes one: the recipient
-- reads his own inbox row, and a notification would be the last place the
-- anonymity is given away and it would be given away whole.
create or replace function evaluations_notify_subject() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_title text;
begin
  if new.status <> 'submitted' or old.status = 'submitted' then
    return null;
  end if;
  if new.target_type <> 'employee' or new.target_profile_id is null then
    return null;
  end if;

  select t.title into v_title
    from evaluation_templates t where t.id = new.template_id;

  insert into notifications (recipient_id, sender_id, title, body, data)
  values (
    new.target_profile_id,
    null,
    'صدر تقييم بحقك',
    concat_ws(' — ', v_title, 'اطّلع عليه من صفحتك الشخصية.'),
    jsonb_build_object('type', 'evaluation_submitted')
  );
  return null;
exception when others then
  return null;
end;
$$;

drop trigger if exists evaluations_notify_subject on evaluations;
create trigger evaluations_notify_subject
  after update of status on evaluations
  for each row execute function evaluations_notify_subject();

-- ================================================================ 13. the log
--
-- The forms are audited by 0077's generic trigger without amendment: a template
-- is the office's own paperwork and names nobody.
--
-- The two tables below the assignment are not. `evaluator_id` is on the row and
-- `audit_events` hands whole rows to anybody with `audit.view` — so a subject
-- who happens to hold that permission would read, in a column no screen in this
-- app draws, the name §9 spent six policies hiding from him. The evaluator's
-- name comes out of the payload, and his own saves are recorded without an
-- actor. A manager's acts — opening one, sending one back, deleting one — keep
-- their actor, because naming the manager is exactly what a log is for.

create or replace function audit_evaluation_change() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_row jsonb;
  v_changed text[];
  v_secret boolean;
  v_evaluator uuid;
begin
  -- OLD and NEW are read first and only where they exist. Naming NEW inside a
  -- DELETE trigger is not a null — it is an error raised before anything else
  -- in this function runs.
  if tg_op = 'UPDATE' then
    v_old := to_jsonb(old) - 'evaluator_id' - 'text_answer';
    v_new := to_jsonb(new) - 'evaluator_id' - 'text_answer';
    v_row := to_jsonb(new);
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
    v_new := to_jsonb(new) - 'evaluator_id' - 'text_answer';
    v_row := to_jsonb(new);
  else
    v_old := to_jsonb(old) - 'evaluator_id' - 'text_answer';
    v_row := to_jsonb(old);
  end if;

  -- Read off the untrimmed row: `evaluations` carries the evaluator itself, an
  -- answer carries the sheet that names him.
  v_evaluator := coalesce(
    nullif(v_row ->> 'evaluator_id', '')::uuid,
    (select e.evaluator_id from evaluations e
      where e.id = nullif(v_row ->> 'evaluation_id', '')::uuid));

  -- The act is the evaluator's own. Everything else here was done by the
  -- office, and the office is named.
  v_secret := v_evaluator is not null and v_evaluator = auth.uid();

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

-- 0077 attaches its trigger to every table that existed when it ran, and says
-- in as many words that a table created afterwards starts unaudited. Six are
-- created here: four take the generic trigger, two take the redacting one.
do $$
declare t text;
begin
  foreach t in array array[
    'evaluation_templates', 'evaluation_stages',
    'evaluation_questions', 'evaluation_options'
  ] loop
    execute format('drop trigger if exists audit_row on %I', t);
    execute format(
      'create trigger audit_row after insert or update or delete on %I '
      'for each row execute function audit_row_change()', t);
  end loop;
end
$$;

drop trigger if exists audit_row on evaluations;
create trigger audit_row after insert or update or delete on evaluations
  for each row execute function audit_evaluation_change();

drop trigger if exists audit_row on evaluation_answers;
create trigger audit_row after insert or update or delete on evaluation_answers
  for each row execute function audit_evaluation_change();

-- And a line in the log should say WHICH form and WHICH sheet.
--
-- Restated whole, on top of 0083's version: the body is one CASE and Postgres
-- has no way to add an arm to it. The six new arms are at the bottom, and one
-- of them is deliberately narrow — an answer is labelled by the sheet it
-- belongs to and never by the words it contains, because those words are what
-- the redaction above is protecting.
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
    when 'module_tasks' then
      concat_ws(' — ',
        p_row ->> 'title_ar',
        audit_actor_name(nullif(p_row ->> 'profile_id', '')::uuid))
    when 'module_task_status' then
      concat_ws(' — ',
        coalesce(
          (select t.title_ar from module_type_tasks t
            where t.id = nullif(p_row ->> 'type_task_id', '')::uuid),
          (select t.title_ar from module_tasks t
            where t.id = nullif(p_row ->> 'module_task_id', '')::uuid)),
        p_row ->> 'state')
    when 'module_task_attachments' then
      (p_row ->> 'name')
    -- A form reads as its own title; the three levels under it read as the
    -- form's title and their own, so a line in the log says which paper was
    -- being edited and not merely that some question changed.
    when 'evaluation_templates' then
      nullif(p_row ->> 'title', '')
    when 'evaluation_stages' then
      concat_ws(' — ',
        (select t.title from evaluation_templates t
          where t.id = (p_row ->> 'template_id')::uuid),
        p_row ->> 'title')
    when 'evaluation_questions' then
      concat_ws(' — ',
        (select t.title from evaluation_templates t
           join evaluation_stages s on s.template_id = t.id
          where s.id = (p_row ->> 'stage_id')::uuid),
        p_row ->> 'text')
    when 'evaluation_options' then
      concat_ws(' — ',
        (select q.text from evaluation_questions q
          where q.id = (p_row ->> 'question_id')::uuid),
        p_row ->> 'text')
    -- The sheet is named by its form and its subject. Never by its evaluator.
    when 'evaluations' then
      concat_ws(' — ',
        (select t.title from evaluation_templates t
          where t.id = (p_row ->> 'template_id')::uuid),
        nullif(p_row ->> 'target_label', ''))
    when 'evaluation_answers' then
      (select concat_ws(' — ',
                (select t.title from evaluation_templates t
                  where t.id = e.template_id),
                nullif(e.target_label, ''))
         from evaluations e
        where e.id = (p_row ->> 'evaluation_id')::uuid)
    else null
  end;

  return coalesce(v,
    p_row ->> 'name_ar', p_row ->> 'title', p_row ->> 'name',
    p_row ->> 'label', p_row ->> 'code', p_row ->> 'email');
exception when others then
  return null;
end;
$$;

-- NOTE for future migrations, restated from 0079 because it now covers two
-- features: 0077's do-block, which attaches the generic audit trigger to every
-- table in the schema, must NEVER be re-run after this file. It would replace
-- both redacting triggers with the generic one and start writing complainant_id
-- and evaluator_id into a log that managers read.

-- ================================================================ 14. grants

revoke execute on function evaluation_stage_total(uuid)        from public, anon;
revoke execute on function evaluation_template_total(uuid)     from public, anon;
revoke execute on function can_read_all_evaluations()          from public, anon;
revoke execute on function can_edit_evaluation_forms()         from public, anon;
revoke execute on function can_assign_evaluation()             from public, anon;
revoke execute on function evaluation_role(uuid)               from public, anon;
revoke execute on function evaluation_form(uuid)               from public, anon;
revoke execute on function evaluation_forms_list(boolean, text, text)
  from public, anon;
revoke execute on function evaluations_list(
  text, text, text, uuid, uuid, text, int, timestamptz) from public, anon;
revoke execute on function evaluation_sheet(uuid)              from public, anon;
revoke execute on function evaluations_about_me(int, timestamptz) from public, anon;
revoke execute on function evaluations_about(text, uuid)       from public, anon;
revoke execute on function evaluation_targets(text, text, int) from public, anon;
revoke execute on function save_evaluation_form(uuid, text, text, text, boolean, jsonb)
  from public, anon;
revoke execute on function assign_evaluation(uuid, text, uuid, uuid, text, date)
  from public, anon;
revoke execute on function assign_evaluations(
  uuid, text, uuid[], uuid[], text, date) from public, anon;
revoke execute on function save_evaluation(uuid, jsonb, boolean) from public, anon;
revoke execute on function reopen_evaluation(uuid)             from public, anon;
revoke execute on function update_evaluation_assignment(uuid, text, date)
  from public, anon;

grant execute on function evaluation_stage_total(uuid)        to authenticated;
grant execute on function evaluation_template_total(uuid)     to authenticated;
grant execute on function can_read_all_evaluations()          to authenticated;
grant execute on function can_edit_evaluation_forms()         to authenticated;
grant execute on function can_assign_evaluation()             to authenticated;
grant execute on function evaluation_role(uuid)               to authenticated;
grant execute on function evaluation_form(uuid)               to authenticated;
grant execute on function evaluation_forms_list(boolean, text, text) to authenticated;
grant execute on function evaluations_list(
  text, text, text, uuid, uuid, text, int, timestamptz) to authenticated;
grant execute on function evaluation_sheet(uuid)              to authenticated;
grant execute on function evaluations_about_me(int, timestamptz) to authenticated;
grant execute on function evaluations_about(text, uuid)       to authenticated;
grant execute on function evaluation_targets(text, text, int) to authenticated;
grant execute on function save_evaluation_form(uuid, text, text, text, boolean, jsonb)
  to authenticated;
grant execute on function assign_evaluation(uuid, text, uuid, uuid, text, date)
  to authenticated;
grant execute on function assign_evaluations(
  uuid, text, uuid[], uuid[], text, date) to authenticated;
grant execute on function save_evaluation(uuid, jsonb, boolean) to authenticated;
grant execute on function reopen_evaluation(uuid)             to authenticated;
grant execute on function update_evaluation_assignment(uuid, text, date)
  to authenticated;

-- The function this file used to carry, dropped by name so that a database
-- which already ran an earlier copy of 0084 is left in the state this file
-- describes rather than keeping a broken orphan.
drop function if exists evaluation_evaluators(text, int);
