-- The push that could not find the function it calls.
--
-- 0107 one file up calls `net.http_post`, fully qualified, and says in a
-- comment that this is safe because pg_net pins its own schema and is not
-- relocatable. That claim is wrong, and this project is the proof: pg_net is
-- installed here with `extnamespace = extensions`, so its FUNCTIONS are
-- `extensions.http_post` — while its TABLES (`http_request_queue`,
-- `_http_response`) are reachable as `net.*`. Both spellings are live at once,
-- for different objects, which is exactly the situation in which a confident
-- guess is worse than no guess.
--
-- What that cost: nothing visible. 0107's outer handler exists so that a
-- failure to ANNOUNCE can never roll back the row being announced — and it
-- swallowed this too. The symptom would have been an operator setting both
-- Vault secrets correctly, raising a test incident, and getting the same
-- silence as before, with the diagnostic table now saying every part was
-- present. A bug that survives its own fix being applied.
--
-- The repair is to stop naming the schema at all and let resolution do it:
-- `search_path` carries both candidates, and a schema in a search_path that
-- does not exist is skipped rather than raised over. So this works whether
-- pg_net sits in `extensions` (as here), in `net` (as on a default install),
-- or is moved between them later by somebody upgrading the platform.
--
-- Nothing else about 0107 changes. Same trigger, same statement-level batching,
-- same per-group topic decision, same two guards. Only the call site moves.

create or replace function push_notification_batch()
  returns trigger
  language plpgsql
  security definer
  -- `net` and `extensions` both, and the order does not matter: whichever one
  -- holds `http_post` is the one that answers, and the other is skipped. This
  -- line is the entire fix.
  set search_path = public, extensions, net
as $$
declare
  v_url   text;
  v_key   text;
  v_topic text;
  v_body  jsonb;
  r       record;
begin
  -- Read the configuration. Absent is a normal state, not a fault: it is what
  -- a fresh clone, a local stack and a restored dump all look like, and none of
  -- them should refuse to write a notification because they cannot announce it.
  begin
    select decrypted_secret into v_url
      from vault.decrypted_secrets where name = 'push_function_url';
    select decrypted_secret into v_key
      from vault.decrypted_secrets where name = 'push_service_key';
  exception when others then
    -- No vault, no extension, no grant — all the same answer.
    return null;
  end;

  if v_url is null or v_key is null or v_url = '' or v_key = '' then
    return null;
  end if;

  -- One row per SEND. Grouping by the payload as well as the id is not
  -- defensive noise: it is what lets the group's title and body be selected
  -- without an aggregate over columns that are identical by construction. If a
  -- writer ever did put two different messages under one group, this splits
  -- them into two pushes — which is the correct outcome, not a failure.
  for r in
    select n.group_id,
           n.title,
           n.body,
           n.data,
           array_agg(n.recipient_id) as recipients
      from new_rows n
     group by n.group_id, n.title, n.body, n.data
  loop
    -- Topic or people. The discriminator is already written by 0041 for the
    -- app's own tap-routing, and is read back rather than added to.
    v_topic := case
      when r.data->>'type' = 'broadcast' then 'all'
      when r.data->>'type' = 'module_broadcast'
       and r.data->>'module_id' is not null
        then 'module_' || (r.data->>'module_id')
      else null
    end;

    v_body := jsonb_build_object(
      'title',    r.title,
      'body',     r.body,
      'data',     r.data,
      'group_id', r.group_id
    ) || case
           when v_topic is not null
             then jsonb_build_object('topic', v_topic)
             else jsonb_build_object('recipient_ids', to_jsonb(r.recipients))
         end;

    -- Wrapped per send, so one malformed group cannot cost the others their
    -- push — and cannot cost any of them their inbox row.
    --
    -- UNQUALIFIED, and that is the whole point of this migration. See the top.
    begin
      perform http_post(
        url     := v_url,
        headers := jsonb_build_object(
                     'Content-Type',  'application/json',
                     'Authorization', 'Bearer ' || v_key
                   ),
        body    := v_body,
        timeout_milliseconds := 5000
      );
    exception when others then
      raise warning 'push_notification_batch: group % not queued (%)',
        r.group_id, sqlerrm;
    end;
  end loop;

  return null;
exception when others then
  -- The outermost guard, and the reason it exists: everything above is an
  -- attempt to ANNOUNCE something that has already been recorded. A trigger
  -- that raises here would roll back the INSERT — turning a missed push into a
  -- lost incident, which is the one outcome worse than the bug being fixed.
  raise warning 'push_notification_batch: skipped (%)', sqlerrm;
  return null;
end;
$$;

revoke execute on function push_notification_batch() from public, anon, authenticated;

-- The trigger itself is unchanged and already installed by 0107; `create or
-- replace function` above is picked up by it without touching it. Recreated
-- anyway, and only because `if not exists` is not available for triggers and a
-- database restored from before 0107 would otherwise have the fixed function
-- and no trigger to call it.
drop trigger if exists notifications_push on notifications;
create trigger notifications_push
  after insert on notifications
  referencing new table as new_rows
  for each statement
  execute function push_notification_batch();

-- --------------------------------------------------------------- verification
--
-- Where the function actually resolved, for the next person who wonders:
--
--   select n.nspname as schema, p.proname
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where p.proname = 'http_post';
--
-- And whether a send left the building — this is the table to watch, not the
-- app:
--
--   select id, status_code, content, created
--     from net._http_response order by created desc limit 5;
