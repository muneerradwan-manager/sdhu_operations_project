-- Three tables the log never heard of.
--
-- 0077 attached its generic trigger to every table that existed the day it ran,
-- and wrote the consequence down in as many words: **a table created afterwards
-- starts unaudited**, and its own migration must attach the trigger. Most of
-- them read the note — 0079, 0083, 0084, 0098, 0105, 0114, 0117, 0118 all
-- attach their own, and 0121 went back for the two 0088 missed.
--
-- These three were never attached by anybody:
--
--   * `place_check_ins` (0098) — and this one is not a gap in a feature, it is
--     a hole in the record. It is THE table that says where people were: every
--     arrival filed at a camp gate for the whole of the season. A row could be
--     edited or deleted with nothing anywhere saying who did it or what it said
--     before. Of everything in this schema, an attendance register is the one
--     nobody should be able to quietly correct — the entire value of "he
--     checked in at Mina at 14:20" is that it was not written afterwards.
--   * `report_misses` (0086) — what the nightly escalation pass decided was
--     late, and how far up the ladder it was carried. The evidence behind a
--     3am notification to somebody's superior.
--   * `module_type_teams` (0115) — master data, the same kind of thing as
--     every other `module_type_*` table, all of which have been audited since
--     0077.
--
-- Nothing here changes behaviour. It closes three holes in the record, which is
-- why it is its own migration rather than a line inside something else.

drop trigger if exists audit_row on place_check_ins;
create trigger audit_row after insert or update or delete on place_check_ins
  for each row execute function audit_row_change();

drop trigger if exists audit_row on report_misses;
create trigger audit_row after insert or update or delete on report_misses
  for each row execute function audit_row_change();

drop trigger if exists audit_row on module_type_teams;
create trigger audit_row after insert or update or delete on module_type_teams
  for each row execute function audit_row_change();

-- ------------------------------------------------------------- what they SAY
--
-- A trigger with no label is half the job. `audit_record_label` falls back on
-- six columns — `name_ar`, `title`, `name`, `label`, `code`, `email` — and two
-- of these three tables carry none of them, so every line they wrote would read
-- as a bare uuid in a list of Arabic sentences. `module_type_teams` needs
-- nothing: it has `name_ar` and the fallback already finds it.
--
-- Restated whole on top of 0121's version. The body is one CASE and Postgres
-- has no way to add an arm to it.
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
    when 'incidents' then
      nullif(left(btrim(coalesce(p_row ->> 'body', '')), 80), '')
    -- New in 0122. Who, and where — in that order, because the question asked
    -- of this table is always about a PERSON: "was he at the gate?".
    when 'place_check_ins' then
      concat_ws(' — ',
        audit_actor_name((p_row ->> 'profile_id')::uuid),
        (select ri.name_ar from reference_items ri
          where ri.id = (p_row ->> 'item_id')::uuid))
    -- Who owed the report, and for which period. The period matters here in a
    -- way it does not elsewhere: the same man is late for three weeks running
    -- and those are three different rows about three different failures.
    when 'report_misses' then
      concat_ws(' — ',
        audit_actor_name((p_row ->> 'profile_id')::uuid),
        (p_row ->> 'period_start'))
    else null
  end;

  return coalesce(v,
    p_row ->> 'name_ar', p_row ->> 'title', p_row ->> 'name',
    p_row ->> 'label', p_row ->> 'code', p_row ->> 'email');
exception when others then
  return null;
end;
$$;
