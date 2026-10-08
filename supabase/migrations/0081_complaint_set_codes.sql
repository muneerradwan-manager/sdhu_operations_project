-- A complaint about a hotel could not be filed at all.
--
-- 0079 checks that a master-data item really belongs to the kind the complaint
-- claims — so that a cluster cannot be filed as a hotel, which no constraint
-- can express because it needs a subquery. The check compared
-- `reference_sets.code` against the enum value directly:
--
--     if v_set is distinct from new.target_type::text then ...
--
-- and those two are not written the same. The sets are named for what they
-- hold — `hotels`, `clusters`, `groups` — and the enum names one of a kind:
-- `hotel`, `cluster`, `group`. So the comparison was 'clusters' <> 'cluster',
-- which is true, and EVERY complaint about a hotel, a cluster or a group was
-- refused with `complaint_target_wrong_set` — the error meant for the one case
-- that is actually wrong.
--
-- The Dart side already knew: complaints_repository pluralises the enum name to
-- find the set. This is the same rule, written down once more where it was
-- missing.

create or replace function complaints_resolve_target() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_row jsonb;
  v_set text;
  v_table text;
begin
  if tg_op = 'UPDATE'
     and (new.target_type    is distinct from old.target_type
       or new.complainant_id is distinct from old.complainant_id) then
    -- A complaint is about what it was filed about, by whom it was filed.
    raise exception 'complaint_is_immutable';
  end if;

  if tg_op = 'INSERT' then
    if new.target_type <> 'other'
       and num_nonnulls(new.target_profile_id, new.target_module_id,
                        new.target_report_id, new.target_item_id) <> 1 then
      raise exception 'complaint_target_missing';
    end if;

    -- Which set an item belongs to is the difference between a hotel and a
    -- cluster, and a check constraint cannot ask.
    --
    -- The set is named in the plural and the enum in the singular, so the
    -- comparison has to say so out loud rather than hope they match.
    if new.target_item_id is not null then
      select rs.code into v_set
        from reference_items ri
        join reference_sets rs on rs.id = ri.set_id
       where ri.id = new.target_item_id;
      if v_set is distinct from new.target_type::text || 's' then
        raise exception 'complaint_target_wrong_set';
      end if;
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
