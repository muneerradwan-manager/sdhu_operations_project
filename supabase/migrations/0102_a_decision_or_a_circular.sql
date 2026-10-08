-- القرارات are not all قرارات. Some of them are تعميمات.
--
-- The `reports` tables have carried both since 0067 with nothing to tell them
-- apart, because at the time everything in them was read as one thing: a
-- document the Administration issues, numbered, published to the mission. The
-- section was even called التقارير until it was corrected to القرارات.
--
-- But a قرار and a تعميم are different acts and the mission reads them
-- differently. A قرار DECIDES — it forms a committee, appoints a supervisor,
-- allots the camps — and somebody is bound by it. A تعميم TELLS — the meal
-- times, the movement plan, what to do on the day of Tarwiyah — and everybody
-- is meant to know it. Filed in one undifferentiated list, a man looking for
-- what he must DO reads past everything he merely needs to know, and the other
-- way round.
--
-- ------------------------------------------------------------------- per ROW
--
-- Not per `report_type`, and the distinction is worth stating because the type
-- table was the obvious place. A type says what SHAPE a document has — a table
-- of meal times, a written body with blocks — and the same shape carries both
-- acts: 'general' (تقرير عام) is used for قرارات that form committees and for
-- تعميمات that announce a timetable, and neither is more general than the
-- other. Shape and act are different questions, so they are different columns.
--
-- Default 'decision', because every row that exists today was written when the
-- section was called القرارات and read as one. Anything among them that is
-- really a تعميم is one edit away, and an edit somebody makes on purpose is
-- better than a guess this migration makes on his behalf from a title.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'decision_kind') then
    create type decision_kind as enum ('decision', 'circular');
  end if;
end
$$;

alter table reports
  add column if not exists kind decision_kind not null default 'decision';

comment on column reports.kind is
  'Whether this is a قرار — which decides something and binds somebody — or a '
  'تعميم, which tells the mission something it needs to know. Per row rather '
  'than per report_type: the type says what SHAPE the document has, and the '
  'same shape carries both acts.';

create index if not exists idx_reports_kind on reports (kind, created_at desc);

-- ------------------------------------------- the subtitle, and what it is not
--
-- 0069 gave the general type three header fields: عنوان فرعي, ملاحظات, and the
-- signed PDF. ملاحظات goes; عنوان فرعي stays but stops being a type field and
-- becomes a column of its own.
--
-- **The subtitle here is not the subheading in the content**, and keeping the
-- two apart is the point. The block kind `subheading` divides a BODY — it says
-- "what follows is about the buses" halfway down. This one names the DOCUMENT
-- beside its title, on the card, in the list, in every place the title appears.
-- They were one field only because the type table happened to hold both, and a
-- man writing a قرار could put its subject in either.
--
-- ملاحظات is not brought back. It was a paragraph block that is always last and
-- never where it belongs, and it invited somebody to put the substance of a
-- قرار where the reader is not looking for it.
--
-- The values already typed are CARRIED, not orphaned: a subtitle written when
-- it lived in jsonb keeps showing after it becomes a column. The note's text
-- stays where it is in `data` — deleting a manager's typed sentence to tidy a
-- schema is not a trade this migration is entitled to make.

alter table reports
  add column if not exists subtitle text;

comment on column reports.subtitle is
  'A second line naming the DOCUMENT, beside its title. Not the `subheading` '
  'block, which divides a body — these were one field only because the type '
  'table happened to hold both.';

update reports
   set subtitle = nullif(btrim(data ->> 'subtitle'), '')
 where subtitle is null
   and nullif(btrim(data ->> 'subtitle'), '') is not null;

delete from report_type_fields f
 using report_types t
 where t.id = f.report_type_id
   and t.code = 'general'
   and f.key in ('subtitle', 'note');

-- ------------------------------------------------------------------ the saver
--
-- `save_report` (0074) writes the whole document in one transaction, and it has
-- to carry the new column or the editor's choice would be dropped on the way
-- to the table.
--
-- The OLD signature is dropped, because `create or replace` cannot change a
-- parameter list — it would leave both, and PostgREST seeing two functions of
-- one name refuses the call as ambiguous rather than picking. It is named in
-- full so this fails loudly if it ever drifted.
--
-- And the new one is `create or replace`, not `create`. With a plain `create`
-- this migration works exactly once: a second run finds nothing to drop — the
-- nine-argument version is already gone — and then collides with the ten
-- argument version it made itself, reporting "already exists with same argument
-- types" about a function it is trying to write. Every other statement in this
-- file is re-runnable, and a migration that is re-runnable in nine places and
-- not in the tenth is worse than one that is not re-runnable at all, because
-- the failure looks like a real conflict.

drop function if exists save_report(
  uuid, uuid, uuid, text, text, jsonb, boolean, jsonb, jsonb);
-- And the ten-argument shape, which an earlier run of THIS file may already
-- have created before the subtitle was added to it. Same reasoning: two
-- overloads of one name and PostgREST refuses the call as ambiguous.
drop function if exists save_report(
  uuid, uuid, uuid, text, text, jsonb, boolean, jsonb, jsonb, decision_kind);

create or replace function save_report(
  p_report_id uuid,          -- null = create
  p_report_type_id uuid,
  p_season_id uuid,
  p_title text,
  p_number text,             -- null = the document has no number
  p_data jsonb,
  p_is_published boolean,
  p_rows jsonb default '[]'::jsonb,    -- [{"data": {...}, "sort_order": 1}]
  p_blocks jsonb default '[]'::jsonb,  -- [{"kind": "...", "data": {...}, ...}]
  -- Defaulted, and last, both of them. An older build that does not know about
  -- these yet keeps working: it files a قرار, which is what every document was
  -- until today, and no subtitle, which is what most of them have.
  p_kind decision_kind default 'decision',
  p_subtitle text default null
) returns uuid
  language plpgsql security invoker set search_path = public as $$
declare
  v_id uuid;
begin
  if p_report_id is null then
    insert into reports
      (report_type_id, season_id, title, subtitle, kind, number, data,
       is_published, created_by)
    values
      (p_report_type_id, p_season_id, p_title, p_subtitle,
       coalesce(p_kind, 'decision'), p_number,
       coalesce(p_data, '{}'::jsonb), coalesce(p_is_published, false),
       auth.uid())
    returning id into v_id;
  else
    v_id := p_report_id;
    update reports
       set report_type_id = p_report_type_id,
           season_id      = p_season_id,
           title          = p_title,
           subtitle       = p_subtitle,
           kind           = coalesce(p_kind, 'decision'),
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

revoke execute on function save_report(
  uuid, uuid, uuid, text, text, jsonb, boolean, jsonb, jsonb, decision_kind,
  text) from public, anon;
grant execute on function save_report(
  uuid, uuid, uuid, text, text, jsonb, boolean, jsonb, jsonb, decision_kind,
  text) to authenticated;

-- ------------------------------------------------------------------ the report

select kind, count(*) as documents
  from reports
 group by kind
 order by kind;
