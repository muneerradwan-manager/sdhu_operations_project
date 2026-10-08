-- The log that only ever grew.
--
-- 0077 put a trigger on EVERY table and no ceiling on what it writes. That was
-- right for what it is — a register nobody reads until something is disputed
-- has to have been keeping the row all along, and a log with gaps in it answers
-- nothing — but a table that only grows is a decision postponed, not avoided.
-- Every profile edit, every posting, every reference entry renamed, both the
-- `old_data` and the `new_data` of it, for as long as the project runs.
--
-- Two costs, and the second is the one that bites first:
--
--   * size. The jsonb pair is the bulk of the row and there is one per write.
--   * time. `audit_events` is keyset-paged and indexed, so READING stays fast
--     however large it gets — but a filtered read with `p_query` scans, and
--     backups, restores and the nightly `pg_dump` all carry the whole thing.
--
-- ---------------------------------------------------------------- the window
--
-- Two seasons, and the number is an argument rather than a round figure.
--
-- The question this log exists to answer is "who changed this, and when" —
-- and it is asked during a season, or while the next one is being arranged out
-- of what the last one did. A dispute about a posting in 1447 is raised in 1447
-- or while 1448 is being built; by 1449 the files themselves are the record and
-- the audit rows behind them are archaeology.
--
-- Measured in days rather than seasons because the log is not season-scoped —
-- it has no `season_id` and should not, since it also carries logins and rows
-- from tables that belong to no year. 800 days is two Hijri years (~709) plus
-- most of a third: a full margin, so that "the season before last" is never
-- half-deleted while somebody is still looking at it.
--
-- ------------------------------------------------------------ what is spared
--
-- `login` and `logout` are kept for a year longer than the rest, and this is
-- deliberate. They are the smallest rows in the table — no `old_data`, no
-- `new_data`, no `changed_fields` — so they cost almost nothing to keep, and
-- they are the rows most likely to be wanted late: "was this account being used
-- in the weeks before it was suspended" is a question asked long after the fact
-- and answerable from nothing else.

-- ------------------------------------------------------------------ the sweep

create or replace function prune_audit_log(
  p_keep_days int default 800,
  p_keep_auth_days int default 1165
) returns bigint
  language plpgsql security definer set search_path = public as $$
declare
  v_deleted bigint := 0;
  v_batch   bigint;
begin
  -- In batches, and not for tidiness. One `delete` over two years of a table
  -- this wide takes a lock and a transaction big enough to matter on a project
  -- whose writes are field staff pressing save — and the whole point of running
  -- this at 03:20 is that nobody notices it at all. Ten thousand at a time,
  -- committed as it goes.
  loop
    with doomed as (
      select id from audit_log
       where occurred_at < now() - make_interval(days =>
               case when action in ('login', 'logout')
                    then p_keep_auth_days
                    else p_keep_days
               end)
       limit 10000
    )
    delete from audit_log a using doomed d where a.id = d.id;

    get diagnostics v_batch = row_count;
    v_deleted := v_deleted + v_batch;
    exit when v_batch = 0;
  end loop;

  -- Recorded in the log itself, which is the only place it belongs: a register
  -- that silently drops rows is worse than one that grows, because the gap
  -- cannot be told from "nothing happened". `table_name` names this table so
  -- the line is findable, and the count is the fact worth keeping.
  if v_deleted > 0 then
    insert into audit_log (action, table_name, record_label, new_data)
    values (
      'delete',
      'audit_log',
      'retention sweep',
      jsonb_build_object(
        'deleted',        v_deleted,
        'keep_days',      p_keep_days,
        'keep_auth_days', p_keep_auth_days
      )
    );
  end if;

  return v_deleted;
end;
$$;

-- Executable by nobody the app can sign in as. Same reasoning as 0086's
-- escalation, and sharper: this function DELETES history, and an account able
-- to call it with `p_keep_days => 0` could erase the record of what it had just
-- done. The scheduler runs it as the database owner; an administrator runs it
-- from the SQL editor, which is the same thing.
revoke execute on function prune_audit_log(int, int) from public, anon, authenticated;

-- ------------------------------------------------------------------ the clock
--
-- 03:20 UTC — the quietest hour in Makkah (06:20), after the escalation pass at
-- 17:00 and well clear of it. Monthly, on the 1st: a sweep that runs daily
-- spends most of its runs finding nothing, and the window is 800 days wide, so
-- a month of drift in either direction changes nothing about what is kept.
--
-- Guarded exactly as 0086 is, and for the same reason: pg_cron has to be
-- enabled on the project first, and a migration that died without it would
-- block every migration after it.
--
-- IF THE NOTICE BELOW APPEARS, NOTHING IS SCHEDULED — the function exists and
-- no one is calling it, which looks exactly like a working retention policy
-- until somebody looks at the table size. To finish the job:
--
--   create extension pg_cron;
--
-- Then re-run this migration; every statement in it is repeatable.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'prune-audit-log') then
      perform cron.unschedule('prune-audit-log');
    end if;
    perform cron.schedule(
      'prune-audit-log',
      '20 3 1 * *',
      $cron$select prune_audit_log()$cron$
    );
  else
    raise notice
      'pg_cron is not installed — the audit log will never be pruned. Enable '
      'the extension and re-run migration 0109.';
  end if;
end
$$;

-- ----------------------------------------------------------------- first run
--
-- Not run here. A migration that deleted two years of history the moment it was
-- applied would be doing the one thing this file is careful about — removing
-- rows before anybody had decided the window was right — and it would do it
-- inside a migration transaction, on a table that may be large, on whatever day
-- the deploy happened to be.
--
-- To sweep now, deliberately, from the SQL editor:
--
--   select prune_audit_log();
--
-- And to see what a sweep WOULD take before taking it:
--
--   select count(*) filter (where action in ('login', 'logout')
--                             and occurred_at < now() - interval '1165 days')
--        + count(*) filter (where action not in ('login', 'logout')
--                             and occurred_at < now() - interval '800 days')
--          as would_delete,
--          count(*) as total,
--          min(occurred_at) as oldest
--     from audit_log;
