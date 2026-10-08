-- Notifications carry things now: a photo, a voice note, a video, a document.
--
-- The inbox has been text since 0014, and text is not how this mission actually
-- communicates. A tower supervisor is sent the seating plan, not a description
-- of it; a bus fault is a photo of the bus. Those were going out over WhatsApp
-- and coming back to this app as "see the group", which is how a record stops
-- being a record.
--
-- One row per attached thing, hanging off the notification. Not a jsonb column
-- on `notifications`: the file lives in storage and the row is what says a
-- recipient may read it, so it has to be something RLS can be written against.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'attachment_kind') then
    create type attachment_kind as enum ('image', 'video', 'audio', 'file');
  end if;
end
$$;

create table if not exists notification_attachments (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null
    references notifications (id) on delete cascade,
  -- What it is, decided when it is attached rather than guessed from the name
  -- afterwards: the app shows a photo inline and a document as a row, and the
  -- difference should not rest on a file extension.
  kind attachment_kind not null,
  -- Path inside the private `notifications` bucket: {notification_id}/{file}.
  path text not null,
  -- The name the sender's device gave it. Shown, and used for the download.
  name text not null,
  mime_type text,
  size_bytes bigint,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_notification_attachments_notification
  on notification_attachments (notification_id);

alter table notification_attachments enable row level security;

-- Visible exactly when the notification it hangs off is. That row's own policy
-- is the single source of truth, so this one defers to it rather than restating
-- who may read what.
drop policy if exists notification_attachments_select on notification_attachments;
create policy notification_attachments_select on notification_attachments
  for select using (
    exists (
      select 1 from notifications n
      where n.id = notification_attachments.notification_id
    )
  );

-- Attaching is part of sending, and goes with the permission to send.
drop policy if exists notification_attachments_write on notification_attachments;
create policy notification_attachments_write on notification_attachments
  for all
  using (is_admin() or has_permission('notifications.send'))
  with check (is_admin() or has_permission('notifications.send'));

-- -------------------------------------------------------------------- storage

insert into storage.buckets (id, name, public)
values ('notifications', 'notifications', false)
on conflict (id) do nothing;

-- Path convention: {notification_id}/{file}. Readable by that notification's
-- recipient, and by admins.
create or replace function can_read_notification_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_notification_id uuid;
begin
  if is_admin() then
    return true;
  end if;
  begin
    v_notification_id := (storage.foldername(p_path))[1]::uuid;
  exception when others then
    return false;
  end;
  return exists (
    select 1 from notifications
    where id = v_notification_id and recipient_id = auth.uid()
  );
end;
$$;

drop policy if exists notification_files_read on storage.objects;
create policy notification_files_read on storage.objects for select
  to authenticated using (
    bucket_id = 'notifications'
    and public.can_read_notification_file(name)
  );

drop policy if exists notification_files_write on storage.objects;
create policy notification_files_write on storage.objects for insert
  to authenticated with check (
    bucket_id = 'notifications'
    and (public.is_admin() or public.has_permission('notifications.send'))
  );

drop policy if exists notification_files_update on storage.objects;
create policy notification_files_update on storage.objects for update
  to authenticated using (
    bucket_id = 'notifications'
    and (public.is_admin() or public.has_permission('notifications.send'))
  );

drop policy if exists notification_files_delete on storage.objects;
create policy notification_files_delete on storage.objects for delete
  to authenticated using (
    bucket_id = 'notifications'
    and (public.is_admin() or public.has_permission('notifications.send'))
  );
