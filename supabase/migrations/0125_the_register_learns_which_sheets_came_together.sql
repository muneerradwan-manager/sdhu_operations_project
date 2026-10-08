-- Ninety rows and nothing that says they were one ask.
--
-- assign_evaluations (0084) writes the cross product on purpose — "an office
-- does not name one judge and one subject… the cross product is written out
-- as thirty-three rows rather than held as one row with lists in it." That is
-- still right: thirty-three independent verdicts need thirty-three rows. But
-- the register reads those rows back one card each, so the office that just
-- asked for ninety appraisals gets ninety identical-looking cards to scroll
-- past before it can ask "how many of these are even done yet."
--
-- The fix borrows the shape already sitting in this schema for the same
-- problem on a different feature — tasks (0118): a batch is not a table of
-- its own, because everything a batch card needs (which form, whose note,
-- whose due date, who assigned it) is already identical across every row one
-- call produced. It is a GROUP BY away, not a write away. So this migration
-- adds one nullable tag column, teaches the one function that writes rows to
-- stamp it — only when it is actually opening more than one, exactly the
-- rule tasks already uses ("a batch is written when one task goes to more
-- than one person") — and adds one function to read the groups back.
--
-- A single assignment (one subject, one evaluator — the ordinary case) gets
-- no tag, joins nothing, and renders exactly as it does today.

-- ================================================== 1. the tag, and its guard

alter table evaluations add column if not exists batch_id uuid;

comment on column evaluations.batch_id is
  'Shared by every row one assign_evaluations() call produced, but only when '
  'it produced more than one. Null for an ordinary single-subject, '
  'single-evaluator assignment. Not a foreign key: nothing else is ever '
  'named by it, it only groups sibling rows back together for the register.';

create index if not exists idx_evaluations_batch
  on evaluations (batch_id) where batch_id is not null;

-- The three fields an evaluation may never change after it is opened —
-- target, form, evaluator — already raise evaluation_is_immutable in
-- evaluations_resolve_target (0084). batch_id joins them: nothing legitimate
-- ever moves a sheet from one batch to another or invents one after the
-- fact, so a bug that tried should fail as loudly as the other three do.
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
       or new.evaluator_id is distinct from old.evaluator_id
       or new.batch_id     is distinct from old.batch_id) then
    -- An evaluation is of what it was opened about, on the form it was opened
    -- on, by the person it was given to, in the batch it was opened with.
    -- Changing any of the four is opening a different one, and that has its
    -- own row.
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

-- ============================================== 2. the writer stamps the tag

-- Same signature, same behaviour, one more column filled in. Nothing calling
-- assign_evaluations or its single-target wrapper (assign_evaluation, itself
-- a thin call into this one) needs to change.
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
  v_batch_id uuid;
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

  -- A batch is written when one ask reaches more than one sheet — the same
  -- rule personal_task_batches (0118) uses for the same reason. One subject
  -- and one evaluator is the ordinary case and stays tagless, so it renders
  -- exactly as it always has.
  if array_length(v_targets, 1) * array_length(v_evaluators, 1) > 1 then
    v_batch_id := gen_random_uuid();
  end if;

  foreach v_target in array v_targets loop
    foreach v_evaluator in array v_evaluators loop
      insert into evaluations (
        template_id, target_type, evaluator_id, assigned_by, note, due_on,
        batch_id,
        target_profile_id, target_module_id, target_report_id, target_item_id
      ) values (
        p_template_id, v_type, v_evaluator, auth.uid(),
        nullif(btrim(p_note), ''), p_due_on,
        v_batch_id,
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

-- =================================================== 3. the register, tagged

-- The signature grows by one filter, so this is a drop-and-replace rather
-- than a plain create-or-replace — the grants below repeat the exact
-- signature for the same reason every other grant in this file does.
drop function if exists evaluations_list(
  text, text, text, uuid, uuid, text, int, timestamptz);

create or replace function evaluations_list(
  p_scope text default 'mine',
  p_status text default null,
  p_target_type text default null,
  p_target_id uuid default null,
  p_template_id uuid default null,
  p_batch_id uuid default null,
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
     and (p_batch_id is null or e.batch_id = p_batch_id)
     and (p_query is null or btrim(p_query) = ''
          or ar_fold(coalesce(e.target_label, '')) like '%' || ar_fold(p_query) || '%'
          or ar_fold(t.title) like '%' || ar_fold(p_query) || '%')
     and (p_before is null or e.created_at < p_before)
   order by e.created_at desc
   limit least(greatest(coalesce(p_limit, 100), 1), 200);
end;
$$;

-- ============================================== 4. the batches, read whole

-- One row per batch rather than one per sheet: the counts a card needs, and
-- nothing this reader is not already allowed to see. Same scope split and
-- the same self-redaction predicate as evaluations_list, because a batch
-- card is a summary OF those rows and must never say more than the rows
-- themselves would.
create or replace function evaluation_batches_list(
  p_scope text default 'mine',
  p_target_type text default null,
  p_limit int default 50
) returns table (
  batch_id uuid,
  created_at timestamptz,
  template_id uuid,
  template_title text,
  target_type text,
  due_on date,
  note text,
  subject_count int,
  subject_label text,
  evaluator_count int,
  evaluator_label text,
  total_count int,
  submitted_count int,
  overdue_count int
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
  select e.batch_id, min(e.created_at), e.template_id, min(t.title),
         min(e.target_type::text), min(e.due_on), min(e.note),
         count(distinct coalesce(e.target_profile_id, e.target_module_id,
                                  e.target_report_id, e.target_item_id))::int,
         case when count(distinct coalesce(e.target_profile_id, e.target_module_id,
                                            e.target_report_id, e.target_item_id)) = 1
              then min(e.target_label) end,
         count(distinct e.evaluator_id)::int,
         case when count(distinct e.evaluator_id) = 1
              then min(nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''))
              end,
         count(*)::int,
         count(*) filter (where e.status = 'submitted')::int,
         count(*) filter (where e.due_on is not null
                             and e.status <> 'submitted'
                             and e.due_on < current_date)::int
    from evaluations e
    join evaluation_templates t on t.id = e.template_id
    left join profiles p on p.id = e.evaluator_id
   where e.batch_id is not null
     and (e.target_type <> 'employee' or e.target_profile_id is distinct from v_uid)
     and (case when v_all then true else e.evaluator_id = v_uid end)
     and (p_target_type is null or e.target_type::text = p_target_type)
   group by e.batch_id, e.template_id
   order by min(e.created_at) desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

-- ================================================================ 5. grants

revoke execute on function evaluations_list(
  text, text, text, uuid, uuid, uuid, text, int, timestamptz) from public, anon;
revoke execute on function evaluation_batches_list(text, text, int)
  from public, anon;

grant execute on function evaluations_list(
  text, text, text, uuid, uuid, uuid, text, int, timestamptz) to authenticated;
grant execute on function evaluation_batches_list(text, text, int)
  to authenticated;
