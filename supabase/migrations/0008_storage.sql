-- Storage buckets: avatars (profile photos) and documents (sensitive PII, private)
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

-- Path convention: {uid}/<file>. The first path segment is the owner's user id.

-- ---- avatars ----
create policy avatars_read on storage.objects for select
  to authenticated using (bucket_id = 'avatars');

create policy avatars_write_own on storage.objects for insert
  to authenticated with check (
    bucket_id = 'avatars'
    and (public.is_admin() or (storage.foldername(name))[1] = auth.uid()::text)
  );

create policy avatars_update_own on storage.objects for update
  to authenticated using (
    bucket_id = 'avatars'
    and (public.is_admin() or (storage.foldername(name))[1] = auth.uid()::text)
  );

create policy avatars_delete_own on storage.objects for delete
  to authenticated using (
    bucket_id = 'avatars'
    and (public.is_admin() or (storage.foldername(name))[1] = auth.uid()::text)
  );

-- ---- documents (private) ----
create policy documents_read on storage.objects for select
  to authenticated using (
    bucket_id = 'documents'
    and (
      public.is_admin()
      or public.has_permission('view_documents')
      or (storage.foldername(name))[1] = auth.uid()::text
    )
  );

create policy documents_write_own on storage.objects for insert
  to authenticated with check (
    bucket_id = 'documents'
    and (public.is_admin() or (storage.foldername(name))[1] = auth.uid()::text)
  );

create policy documents_update_own on storage.objects for update
  to authenticated using (
    bucket_id = 'documents'
    and (public.is_admin() or (storage.foldername(name))[1] = auth.uid()::text)
  );

create policy documents_delete_own on storage.objects for delete
  to authenticated using (
    bucket_id = 'documents'
    and (public.is_admin() or (storage.foldername(name))[1] = auth.uid()::text)
  );
