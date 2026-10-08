-- The register, asked about one thing.
--
-- 0079 could be asked for a KIND — every complaint about a hotel — but not for
-- one hotel, or one man. The panel at the foot of an employee's page needs the
-- second question, and filtering the first answer on the client would have been
-- a lie the moment the register passed its hundred-row ceiling.
--
-- A new file rather than an edit to 0079, because 0079 has already been applied:
-- a migration that has run somewhere is history, and history is appended to.
--
-- The old six-argument function is dropped rather than left beside the new one.
-- `create or replace` with a different argument list makes an OVERLOAD, and two
-- functions of the same name would leave PostgREST to guess which one a call
-- meant — the sort of thing that works until the day it does not.

drop function if exists complaints_list(text, text, boolean, text, int, timestamptz);

create or replace function complaints_list(
  p_scope text default 'mine',
  p_target_type text default null,
  p_target_id uuid default null,
  p_include_dismissed boolean default true,
  p_query text default null,
  p_limit int default 50,
  p_before timestamptz default null
) returns table (
  id uuid,
  created_at timestamptz,
  target_type text,
  target_id uuid,
  target_label text,
  complainant_id uuid,
  complainant_name text,
  complainant_photo_url text,
  body text,
  is_locked boolean,
  is_dismissed boolean,
  reply_count int,
  attachment_count int,
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
  if v_all and not can_read_all_complaints() then
    raise exception 'not authorized';
  end if;

  return query
  select c.id, c.created_at, c.target_type::text,
         coalesce(c.target_profile_id, c.target_module_id,
                  c.target_report_id, c.target_item_id),
         c.target_label,
         c.complainant_id,
         nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
         p.photo_url,
         c.body,
         c.locked_at is not null,
         c.dismissed_at is not null,
         (select count(*)::int from complaint_replies r where r.complaint_id = c.id),
         (select count(*)::int from complaint_attachments a where a.complaint_id = c.id),
         case when c.complainant_id = v_uid then 'complainant' else 'manager' end
    from complaints c
    left join profiles p on p.id = c.complainant_id
   -- Never a row where the caller is the accused: that is what
   -- complaints_against_me is for, and it is the only door that redacts.
   -- Asking p_target_id for YOURSELF is therefore answered with nothing, which
   -- is the point rather than an oversight.
   where (c.target_type <> 'employee' or c.target_profile_id is distinct from v_uid)
     and (case when v_all then true else c.complainant_id = v_uid end)
     and (p_target_type is null or c.target_type::text = p_target_type)
     -- One person's, or one file's, for the panel at the foot of their page.
     and (p_target_id is null
          or p_target_id in (c.target_profile_id, c.target_module_id,
                             c.target_report_id, c.target_item_id))
     and (p_include_dismissed or c.dismissed_at is null)
     and (p_query is null or btrim(p_query) = ''
          or ar_fold(coalesce(c.target_label, '')) like '%' || ar_fold(p_query) || '%'
          or ar_fold(c.body) like '%' || ar_fold(p_query) || '%')
     and (p_before is null or c.created_at < p_before)
   order by c.created_at desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

revoke execute on function
  complaints_list(text, text, uuid, boolean, text, int, timestamptz)
  from public, anon;
grant execute on function
  complaints_list(text, text, uuid, boolean, text, int, timestamptz)
  to authenticated;
