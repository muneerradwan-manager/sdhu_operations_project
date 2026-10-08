-- The inbox stream was never a stream.
--
-- `NotificationsRepository.streamMine` uses `.stream()`, which does an initial
-- read and then listens for changes over Realtime. Listening requires the table
-- to be in the `supabase_realtime` publication, and no table in this project
-- ever was — so the initial read was the whole of it. Open the screen and you
-- saw what existed at that moment, and nothing after.
--
-- It went unnoticed because a notification normally arrives while the app is
-- elsewhere, and reopening the screen re-read it. Sending to yourself while
-- watching the list is what makes it obvious.
--
-- Realtime honours RLS with the subscriber JWT, so `notifications_select` still
-- decides what reaches whom: a recipient sees their own rows and nobody sees
-- anybody else.

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table notifications;
  end if;
end
$$;

-- An update carries the old row as well as the new one, which is what lets a
-- client tell a read mark from a fresh arrival rather than re-reading the list.
alter table notifications replica identity full;
