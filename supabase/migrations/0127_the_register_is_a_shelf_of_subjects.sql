-- The register is asked "how is THIS being judged", not "what rows exist".
--
-- 0125 answered the ninety-cards problem by tagging the rows one assignment
-- call produced and grouping on that tag. It worked, and it was the wrong
-- grouping. A batch is a fact about the OFFICE — when somebody pressed send —
-- and nobody opens the register to ask that. What is actually asked is about
-- a SUBJECT: this file was put up for appraisal, twenty people were asked to
-- appraise it, how did that go. Two files under judgement is two cards, and
-- it stays two cards whether they were assigned in one act or in five.
--
-- So the tag goes back out (§1 here), and the register groups by the thing
-- being judged instead: one row per (form, subject), carrying the counts, the
-- marks — average, best, worst — and every person who was asked, each with
-- their own sheet's id so the card can lead straight into it.
--
-- Which also settles a question 0125 left open. A batch card had to send the
-- reader to a second, filtered copy of the register before they could reach a
-- sheet. A subject card carries its evaluators inside it: the name IS the
-- link, and there is no in-between screen at all.

-- ================================================ 1. the batch tag, withdrawn
--
-- Dropped rather than left in place. It is read by nothing now, and a column
-- the schema stamps but no question ever asks is the kind of thing that is
-- still there in three seasons with nobody able to say what it meant.

drop function if exists evaluation_batches_list(text, text, int);

drop index if exists idx_evaluations_batch;
alter table evaluations drop column if exists batch_id;

-- Back to the three fields of 0084 exactly: target, form, evaluator.
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

-- The writer, with the stamping taken back out. Its signature never changed.
create or replace function assign_evaluations(
  p_template_id uuid,
  p_target_type text,
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

  -- The kind that points at nothing runs the loop once with a null subject
  -- rather than not at all.
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

-- And the flat register, back to the eight arguments 0084 gave it.
drop function if exists evaluations_list(
  text, text, text, uuid, uuid, uuid, text, int, timestamptz);
drop function if exists evaluations_list(
  text, text, text, uuid, uuid, text, int, timestamptz);

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

-- ============================================ 2. the register, by its subjects

-- One row per (form, subject): what is under judgement, how far the judging
-- has gotten, what it has come to, and every person who was asked — each
-- carrying their own sheet's id, because the name on the card IS the way in.
--
-- The marks are over SUBMITTED sheets only, and as percentages rather than raw
-- scores. Two reasons, and the second is the one that matters: a half-filled
-- sheet adds up to a number nobody should quote (§26.10.2 is the same argument
-- one level down), and a form that was re-marked between one assignment and
-- the next puts 38/50 and 38/80 in the same column — the percentage is the
-- only thing that survives being compared.
--
-- Grouped by (template_id, target_id) and not by the subject alone: the same
-- file appraised on two different papers is two different questions, and an
-- average taken across both answers neither. A null target_id groups the
-- 'other' kind together, which is right — it points at nothing by definition.
create or replace function evaluation_subjects_list(
  p_scope text default 'all',
  p_target_type text default null,
  p_template_id uuid default null,
  p_query text default null,
  p_limit int default 100
) returns table (
  template_id uuid,
  template_title text,
  target_type text,
  target_id uuid,
  target_label text,
  opened_at timestamptz,
  due_on date,
  total_count int,
  submitted_count int,
  overdue_count int,
  avg_percent numeric,
  best_percent numeric,
  worst_percent numeric,
  evaluators jsonb
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
  with sheets as (
    select e.id,
           e.template_id as t_id,
           t.title as t_title,
           e.target_type::text as t_type,
           coalesce(e.target_profile_id, e.target_module_id,
                    e.target_report_id, e.target_item_id) as t_target,
           e.target_label as t_label,
           e.created_at, e.due_on, e.status::text as status,
           e.submitted_at, e.score, e.max_score,
           e.evaluator_id,
           nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), '')
             as evaluator_name,
           p.photo_url as evaluator_photo_url,
           (select count(*)::int from evaluation_answers a
             where a.evaluation_id = e.id
               and (a.option_id is not null or a.text_answer is not null))
             as answered_count,
           (select count(*)::int from evaluation_questions q
              join evaluation_stages s on s.id = q.stage_id
             where s.template_id = e.template_id) as question_count,
           case when e.status = 'submitted' and coalesce(e.max_score, 0) > 0
                then round(e.score * 100 / e.max_score, 1) end as percent
      from evaluations e
      join evaluation_templates t on t.id = e.template_id
      left join profiles p on p.id = e.evaluator_id
     where (e.target_type <> 'employee'
            or e.target_profile_id is distinct from v_uid)
       and (case when v_all then true else e.evaluator_id = v_uid end)
       and (p_target_type is null or e.target_type::text = p_target_type)
       and (p_template_id is null or e.template_id = p_template_id)
       and (p_query is null or btrim(p_query) = ''
            or ar_fold(coalesce(e.target_label, ''))
                 like '%' || ar_fold(p_query) || '%'
            or ar_fold(t.title) like '%' || ar_fold(p_query) || '%')
  )
  select s.t_id, min(s.t_title), min(s.t_type), s.t_target, min(s.t_label),
         min(s.created_at), min(s.due_on),
         count(*)::int,
         count(*) filter (where s.status = 'submitted')::int,
         count(*) filter (where s.due_on is not null
                            and s.status <> 'submitted'
                            and s.due_on < current_date)::int,
         round(avg(s.percent), 1), max(s.percent), min(s.percent),
         jsonb_agg(
           jsonb_build_object(
             'id', s.id,
             'evaluator_id', s.evaluator_id,
             'evaluator_name', s.evaluator_name,
             'evaluator_photo_url', s.evaluator_photo_url,
             'status', s.status,
             'score', s.score,
             'max_score', s.max_score,
             'percent', s.percent,
             'due_on', s.due_on,
             'submitted_at', s.submitted_at,
             'answered_count', s.answered_count,
             'question_count', s.question_count
           )
           -- What is still owed first: 'draft' sorts before 'submitted', and
           -- the card is read to find out who has not answered yet.
           order by s.status, s.evaluator_name nulls last
         )
    from sheets s
   group by s.t_id, s.t_target
   order by min(s.created_at) desc
   limit least(greatest(coalesce(p_limit, 100), 1), 200);
end;
$$;

-- ================================================================ 3. grants

revoke execute on function evaluations_list(
  text, text, text, uuid, uuid, text, int, timestamptz) from public, anon;
revoke execute on function evaluation_subjects_list(text, text, uuid, text, int)
  from public, anon;

grant execute on function evaluations_list(
  text, text, text, uuid, uuid, text, int, timestamptz) to authenticated;
grant execute on function evaluation_subjects_list(text, text, uuid, text, int)
  to authenticated;
