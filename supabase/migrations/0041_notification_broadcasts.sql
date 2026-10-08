-- Sending to everyone, and sending to a file.
--
-- Until now a notification went to one person: the client inserted one row and
-- asked the push function to fan out over that person's devices. At five hundred
-- members that shape does not hold. Sending to a file would be five hundred
-- inserts from the client and five hundred FCM calls from the function, one HTTP
-- round trip each, for one message.
--
-- Two changes, and they solve different halves of it:
--
--   * the INBOX rows are still one per recipient — they have to be, a read mark
--     belongs to a person — but they are written by one INSERT..SELECT inside
--     the database instead of five hundred round trips from a phone;
--
--   * the PUSH stops being per-device. A send now names an FCM topic and the
--     function makes ONE call to it. Google fans it out.
--
-- What ties a broadcast together is `group_id`: one id per send, shared by every
-- recipient row of it. It is also what makes attachments possible on a
-- broadcast — one uploaded file, not one copy per recipient.

-- ------------------------------------------------------------------- grouping

alter table notifications
  add column if not exists group_id uuid;

-- Existing rows are each their own group of one. Deliberately the row id: the
-- attachments of those rows already live under `{notification_id}/…` in storage,
-- and this keeps every one of those paths valid.
update notifications set group_id = id where group_id is null;

alter table notifications alter column group_id set not null;
alter table notifications alter column group_id set default gen_random_uuid();

create index if not exists idx_notifications_group on notifications (group_id);

-- Attachments hang off the GROUP, not the row. One send, one upload, however
-- many people receive it.
alter table notification_attachments
  add column if not exists group_id uuid;

update notification_attachments a
   set group_id = n.group_id
  from notifications n
 where n.id = a.notification_id
   and a.group_id is null;

-- Rows whose notification is gone take their attachments with them; from here
-- the link is the group, so the old column stops being required.
delete from notification_attachments where group_id is null;
alter table notification_attachments alter column group_id set not null;
alter table notification_attachments alter column notification_id drop not null;

create index if not exists idx_notification_attachments_group
  on notification_attachments (group_id);

-- Visible when you hold any notification of that group.
drop policy if exists notification_attachments_select on notification_attachments;
create policy notification_attachments_select on notification_attachments
  for select using (
    exists (
      select 1 from notifications n
      where n.group_id = notification_attachments.group_id
    )
  );

-- Storage follows: the folder is the group, so one file is read by everyone the
-- message went to.
create or replace function can_read_notification_file(p_path text) returns boolean
  language plpgsql stable security definer set search_path = public, storage as $$
declare
  v_group_id uuid;
begin
  if is_admin() then
    return true;
  end if;
  begin
    v_group_id := (storage.foldername(p_path))[1]::uuid;
  exception when others then
    return false;
  end;
  return exists (
    select 1 from notifications
    where group_id = v_group_id and recipient_id = auth.uid()
  );
end;
$$;

-- ------------------------------------------------------------------ broadcast

-- Everyone holding a role anywhere in one file — on the file itself or on any
-- node of its tree. Returns the group id, which is what the caller then uploads
-- attachments under and pushes to.
create or replace function broadcast_to_module(
  p_module_id uuid,
  p_title text,
  p_body text default null
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_group uuid := gen_random_uuid();
begin
  if not (is_admin() or has_permission('notifications.send')) then
    raise exception 'not authorized';
  end if;

  insert into notifications (recipient_id, sender_id, title, body, group_id, data)
  select distinct p.profile_id, auth.uid(), p_title, p_body, v_group,
         jsonb_build_object('type', 'module_broadcast', 'module_id', p_module_id)
    from (
      select mm.profile_id
        from module_members mm
       where mm.module_id = p_module_id
      union
      select nm.profile_id
        from module_node_members nm
        join module_nodes n on n.id = nm.node_id
       where n.module_id = p_module_id
    ) p;

  return v_group;
end;
$$;

-- Everyone with a working account. Optionally narrowed to the participants of
-- one season, which is what "everyone" usually means during a season.
create or replace function broadcast_to_all(
  p_title text,
  p_body text default null,
  p_season_id uuid default null
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare
  v_group uuid := gen_random_uuid();
begin
  if not (is_admin() or has_permission('notifications.send')) then
    raise exception 'not authorized';
  end if;

  insert into notifications (recipient_id, sender_id, title, body, group_id, data)
  select pr.id, auth.uid(), p_title, p_body, v_group,
         jsonb_build_object('type', 'broadcast')
    from profiles pr
   where pr.account_status = 'approved'
     and not pr.is_suspended
     and (
       p_season_id is null
       or exists (
         select 1 from season_participants sp
          where sp.profile_id = pr.id
            and sp.season_id = p_season_id
            and sp.status = 'active'
       )
     );

  return v_group;
end;
$$;

revoke execute on function broadcast_to_module(uuid, text, text) from public, anon;
revoke execute on function broadcast_to_all(text, text, uuid) from public, anon;
grant execute on function broadcast_to_module(uuid, text, text) to authenticated;
grant execute on function broadcast_to_all(text, text, uuid) to authenticated;
