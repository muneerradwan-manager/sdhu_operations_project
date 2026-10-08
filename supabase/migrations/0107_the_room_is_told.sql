-- Making true the one sentence this system already believed.
--
-- `IncidentsRepository.raise` says it plainly, and says it as the reason the
-- write is an RPC rather than two calls:
--
--   > The alarm is sent by the database rather than from here … if the row
--   > exists, the room has been told.
--
-- It was not true. The row existed and nobody was told.
--
-- Ten migrations write into `notifications` — 0017, 0024, 0041, 0073, 0079,
-- 0083, 0084, 0086, 0088 and 0105 — and until this file the ONLY thing in the
-- whole system that ever reached FCM was one Dart method called by hand from
-- the compose screen. Everything the database decided on its own landed in an
-- inbox and waited to be found. Realtime delivers those rows, which hid it: a
-- developer with the app open sees the badge move and concludes it works. A
-- phone in a pocket has no socket, and that is the case the feature exists for.
--
-- What that cost, feature by feature:
--
--   * 0088 urgent incidents — the whole point, and the sharpest loss. Its own
--     header describes "a bus broken down on the road to Arafat with two
--     hundred pilgrims on it". The room learned of it whenever somebody next
--     opened the app.
--   * 0086 automatic escalation — worse, because it is STRUCTURALLY silent.
--     A pg_cron pass at night tells whoever is late, and at night every app is
--     closed. The one thing in this system that watches for what did NOT
--     happen could not report what it found.
--   * 0105 task assignment — documented as "with a notification on assignment".
--   * 0079 complaints, 0084 evaluations, 0017/0024 posting to a file.
--
-- ---------------------------------------------------------------- the design
--
-- **One push per SEND, not per row**, and `group_id` is what a send is. 0041
-- introduced it for exactly this shape of question — it is already `not null`,
-- already defaulted, already indexed, and already what attachments hang off.
-- A broadcast to five hundred people is five hundred inbox rows and ONE group.
--
-- So the trigger is FOR EACH STATEMENT with a transition table, not FOR EACH
-- ROW. Every writer above inserts a group in a single `insert … select`, which
-- means one statement, one batch, one decision. A row-level trigger would have
-- made 0041's whole argument backwards: it replaced five hundred pushes with
-- one, and firing per row would quietly restore the five hundred.
--
-- **The topic survives.** 0041 chose FCM topics so Google does the fan-out, and
-- that choice is kept by reading it back out of the row: `data->>'type'` says
-- `broadcast` (topic `all`) or `module_broadcast` (topic `module_<uuid>`). Any
-- other type is a real send to real people, and travels as a list of recipient
-- ids for the function to resolve to devices. Nothing new is stored to make
-- this work — the discriminator was already being written for the app's own
-- tap-routing.
--
-- **It cannot lose a notification.** Two independent guards, because this
-- trigger sits inside the transaction that writes the row and a trigger that
-- raises takes the INSERT down with it:
--
--   1. every failure path returns instead of raising, and the whole body is
--      wrapped so that even an unforeseen one is swallowed;
--   2. `net.http_post` is asynchronous by construction — it queues a row and a
--      background worker sends it after commit — so a slow or dead FCM cannot
--      hold a transaction open, and an incident is never made slower to record
--      by the attempt to announce it.
--
-- The inbox row remains the source of truth, exactly as before. Push is how you
-- find out early; the row is what is true.
--
-- **It is off until configured, and says so rather than failing.** The URL and
-- key live in Vault (see the bottom of this file). Missing means no push, not
-- a broken INSERT — a project restored from a dump, or a fresh local stack,
-- must keep working the moment it comes up.

-- --------------------------------------------------------------- the plumbing

-- Asynchronous HTTP from inside Postgres. Present on Supabase; created here so
-- a local stack and a restored dump both have it.
--
-- No `with schema` clause: pg_net pins its own schema (`net`) in its control
-- file and is not relocatable, so naming a different one is an error rather
-- than a preference. Every call below is written `net.http_post`, fully
-- qualified, which resolves whatever the search_path happens to be.
create extension if not exists pg_net;

-- ------------------------------------------------------------------ the trigger

create or replace function push_notification_batch()
  returns trigger
  language plpgsql
  security definer
  set search_path = public, extensions
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
    -- Topic or people. See the header: the discriminator is already written by
    -- 0041 for the app's own tap-routing, and is read back rather than added to.
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
    begin
      perform net.http_post(
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

drop trigger if exists notifications_push on notifications;
create trigger notifications_push
  after insert on notifications
  referencing new table as new_rows
  for each statement
  execute function push_notification_batch();

-- ------------------------------------------------------------------- the setup
--
-- Two secrets, set once per project, from a machine that has them:
--
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1/send-notification',
--     'push_function_url');
--
--   select vault.create_secret('<service_role key>', 'push_service_key');
--
-- To rotate either, `select vault.update_secret(id, new_value)`.
--
-- **The key is the service_role key, and Vault is where such a key belongs** —
-- the server's own secret store, reachable only by `security definer` code
-- running as the database owner. This is the same key that was found bundled
-- inside the APK and removed on 2026-08-07 (see §1.6); the fix was never "this
-- key is dangerous", it is "this key belongs on the server". Here it is on the
-- server.
--
-- The function is deployed with its JWT gate off, because a Supabase publishable
-- or secret key is not a JWT and the gateway would reject the call before the
-- function could authorise it itself. That is not a hole: `send-notification`
-- has always authenticated its own caller, and now refuses anything that is
-- neither a signed-in user with the right grant nor a bearer of this exact key.
-- See supabase/config.toml and the function's own header.
