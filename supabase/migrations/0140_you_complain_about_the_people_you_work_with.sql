-- You complain about the people you work with.
--
-- 0082 gave the complaint form its own SECURITY DEFINER picker, and it was the
-- right shape for the wrong width. The problem it solved was real: an ordinary
-- employee opened the form, chose «موظف», and was handed an empty list, because
-- the picker read `profiles` directly and row security hid everyone from him.
-- The fix returned three columns — an id, a name, a photograph — from a
-- function instead of widening `employees.view`, and that part stands.
--
-- What it got wrong is how far it opened. It answered "he must be able to name
-- SOMEBODY" with "he may name ANYBODY":
--
--     employee   every approved account in the system but his own
--     module     every released file, of every season
--
-- Neither is a list the man filing has any use for. A tower supervisor in مكة
-- scrolling four hundred names to find his sector supervisor is being asked to
-- do the system's work; and «قطاعات وأبراج حجاج سوريا في مكة المكرمة» is not
-- improved by sitting in a list beside fourteen files he has never touched and
-- a دورة تدريبية from two seasons ago.
--
-- ------------------------------------------------------- what it should be
--
-- The people he works with, and the files he was posted to. And a manager who
-- holds the directory or the files sees all of them, because his complaint may
-- genuinely be about any of them.
--
-- The striking part is that both rules were already written down, and this
-- function is the only thing in the system that was not reading them:
--
--   profiles_select (0137)  … or shares_a_module_with(id)
--   modules_select  (0073)  … or (is_active and is_module_member(id))
--
-- So this is not a new policy. It is the picker stopping bypassing the one
-- there was. What 0082 needed from SECURITY DEFINER was never the width — it
-- was the NARROWNESS: three columns, not the phone and the documents and the
-- account's standing behind them. That is kept exactly.
--
-- The guards are restated by hand rather than inherited, for the reason 0110
-- gives in the same words: `security definer` does not inherit the policies on
-- the tables below it. The two predicates themselves are the policies' own
-- functions, so the parts that could drift are called, not copied.
--
-- ---------------------------------------------------------- the man in no file
--
-- He now has no employees and no files to point at, where before he had all of
-- them. That is the intended answer and not an oversight: a complaint naming a
-- colleague he has none of, or a file he was never posted to, is a complaint
-- about something he is telling us he has no part in. «شكوى أخرى» takes no
-- target at all and stays open to him, which is where such a complaint belongs.
-- The form now says so instead of showing him an empty list (see the app's
-- `complaintTargetNone`).
--
-- Untouched: `report`, `hotel`, `cluster`, `group`. A قرار is published to the
-- mission at large and a فندق is master data any approved account could already
-- read — neither is narrowed by who works where, and neither was asked about.

create or replace function complaint_targets(
  p_target_type text,
  p_query text default null,
  p_limit int default 100
)
returns table (id uuid, name text, photo_url text)
language plpgsql stable security definer set search_path = public as $$
declare
  v_type complaint_target_type := p_target_type::complaint_target_type;
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 200);

  -- The directory, as `profiles_select` (0137) defines it. `approvals.view` is
  -- left out of the copy on purpose: it opens only the accounts that are not
  -- yet approved, and those are already excluded below.
  v_every_name boolean := is_admin()
                       or has_permission('employees.view')
                       or has_permission('employees.edit')
                       or has_permission('export.data');

  -- The files, as `modules_select` (0073) defines them.
  v_every_file boolean := is_admin()
                       or has_permission('modules.view_all')
                       or has_permission('modules.members');
begin
  if not can_file_complaint() then
    return;
  end if;

  case v_type
    when 'employee' then
      return query
      select p.id,
             nullif(concat_ws(' ', p.first_name, p.father_name, p.surname), ''),
             p.photo_url
        from profiles p
       where p.account_status = 'approved'
         and p.id <> auth.uid()
         -- Whom he actually works with. Every file counts, this season's and
         -- any other's: a complaint about last season's supervisor is still a
         -- complaint about a man he served under.
         and (v_every_name or shares_a_module_with(p.id))
         and (v_query is null
              or concat_ws(' ', p.first_name, p.father_name, p.surname)
                   ilike '%' || v_query || '%')
       order by 2
       limit v_limit;

    when 'module' then
      return query
      select m.id, audit_record_label('modules', to_jsonb(m)), null::text
        from modules m
       where m.is_active
         and (v_every_file or is_module_member(m.id))
         and (v_query is null
              or audit_record_label('modules', to_jsonb(m))
                   ilike '%' || v_query || '%')
       order by m.created_at desc
       limit v_limit;

    when 'report' then
      return query
      select r.id, r.title, null::text
        from reports r
       where (r.is_published or r.created_by = auth.uid())
         and (v_query is null or coalesce(r.title, '') ilike '%' || v_query || '%')
       order by r.updated_at desc
       limit v_limit;

    when 'other' then
      return;

    else
      -- hotel, cluster, group. The set's code is the enum value's own name in
      -- the plural — the mismatch 0081 was written to fix.
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

comment on function complaint_targets(text, text, int) is
  'What this account may point a complaint at: the colleagues of the files he '
  'is posted to and those files themselves (0140), or all of both for whoever '
  'holds the directory or the files. Three columns and no more — the row '
  'security that hides these tables is right, and this returns less rather '
  'than showing more (0082).';

revoke execute on function complaint_targets(text, text, int) from public, anon;
grant  execute on function complaint_targets(text, text, int) to authenticated;
