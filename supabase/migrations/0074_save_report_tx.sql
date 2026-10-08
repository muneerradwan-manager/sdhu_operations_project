-- Saving a report is one act, so it is one transaction.
--
-- The editor used to write a report in five requests: update the header,
-- delete the rows, insert the rows, delete the blocks, insert the blocks. A
-- connection that died between a delete and its insert left the report
-- stripped of its table in the database — the person saw an error, but the
-- loss was already committed, and closing the editor made it permanent. A
-- function body is a single transaction: either the whole report lands, or
-- nothing changes.
--
-- SECURITY INVOKER on purpose: every RLS policy on reports/report_rows/
-- report_blocks and the publish-vs-edit guard trigger (0073) apply to the
-- statements inside exactly as they applied to the five separate requests.

create or replace function save_report(
  p_report_id uuid,          -- null = create
  p_report_type_id uuid,
  p_season_id uuid,
  p_title text,
  p_number text,             -- null = the report has no number
  p_data jsonb,
  p_is_published boolean,
  p_rows jsonb default '[]'::jsonb,    -- [{"data": {...}, "sort_order": 1}]
  p_blocks jsonb default '[]'::jsonb   -- [{"kind": "...", "data": {...}, "sort_order": 1}]
) returns uuid
  language plpgsql security invoker set search_path = public as $$
declare
  v_id uuid;
begin
  if p_report_id is null then
    insert into reports
      (report_type_id, season_id, title, number, data, is_published, created_by)
    values
      (p_report_type_id, p_season_id, p_title, p_number,
       coalesce(p_data, '{}'::jsonb), coalesce(p_is_published, false),
       auth.uid())
    returning id into v_id;
  else
    v_id := p_report_id;
    update reports
       set report_type_id = p_report_type_id,
           season_id      = p_season_id,
           title          = p_title,
           number         = p_number,
           data           = coalesce(p_data, '{}'::jsonb),
           is_published   = coalesce(p_is_published, false)
     where id = v_id;
    -- Zero rows updated under RLS reads the same as the report not existing:
    -- either way there is nothing here for this caller to save into.
    if not found then
      raise exception 'report not found';
    end if;
    delete from report_rows   where report_id = v_id;
    delete from report_blocks where report_id = v_id;
  end if;

  insert into report_rows (report_id, data, sort_order)
  select v_id,
         coalesce(r.value -> 'data', '{}'::jsonb),
         coalesce((r.value ->> 'sort_order')::int, r.ordinality::int)
    from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb))
         with ordinality as r(value, ordinality);

  insert into report_blocks (report_id, kind, data, sort_order)
  select v_id,
         (b.value ->> 'kind')::report_block_kind,
         coalesce(b.value -> 'data', '{}'::jsonb),
         coalesce((b.value ->> 'sort_order')::int, b.ordinality::int)
    from jsonb_array_elements(coalesce(p_blocks, '[]'::jsonb))
         with ordinality as b(value, ordinality);

  return v_id;
end;
$$;
