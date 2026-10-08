-- Employee notifications: an in-app inbox (works without push) plus a place to
-- register device tokens for FCM push.

-- Device tokens (one row per user+device token).
create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  token text not null,
  platform text,
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

alter table device_tokens enable row level security;

create policy device_tokens_own on device_tokens for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Notifications inbox.
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles (id) on delete cascade,
  sender_id uuid references profiles (id),
  title text not null,
  body text,
  data jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_recipient
  on notifications (recipient_id, created_at desc);

alter table notifications enable row level security;

-- Recipients read their own; admins read all.
create policy notifications_select on notifications for select
  using (recipient_id = auth.uid() or is_admin());

-- Admins or holders of notifications.send may create notifications.
create policy notifications_insert on notifications for insert
  with check (is_admin() or has_permission('notifications.send'));

-- Recipients (or admins) may update — used to set read_at.
create policy notifications_update on notifications for update
  using (recipient_id = auth.uid() or is_admin())
  with check (recipient_id = auth.uid() or is_admin());

-- Permission catalog: a Notifications section with a send action.
insert into permissions (code, description, sort_order)
values ('notifications', 'Notifications section', 5)
on conflict (code) do nothing;

insert into permissions (code, description, parent_id, sort_order)
select 'notifications.send', 'Send notifications', p.id, 1
from permissions p
where p.code = 'notifications'
on conflict (code) do nothing;
