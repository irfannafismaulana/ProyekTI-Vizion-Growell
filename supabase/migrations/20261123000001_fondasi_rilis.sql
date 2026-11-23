-- GroWell v0.6 — fondasi rilis (PRD F2, F3) + tabel pendukung AI (F6/F7) dan push (F8).

-- ============================================================ F2. Dokumen STR nakes
alter table public.profiles add column str_document_path text;
comment on column public.profiles.str_document_path is 'Jalur berkas STR di bucket privat str-documents (<user_id>/...).';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('str-documents', 'str-documents', false, 5242880, array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "nakes unggah STR sendiri" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'str-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.my_role() = 'health'
  );

create policy "STR terlihat pemilik dan admin" on storage.objects for select to authenticated
  using (
    bucket_id = 'str-documents'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );

create policy "hapus STR sendiri" on storage.objects for delete to authenticated
  using (bucket_id = 'str-documents' and (storage.foldername(name))[1] = auth.uid()::text);

-- Jalur dokumen hanya boleh menunjuk ke folder pemilik profil.
alter table public.profiles add constraint str_document_path_own_folder
  check (str_document_path is null or split_part(str_document_path, '/', 1) = id::text);

-- ============================================================ F3. Foto makanan & pertumbuhan
alter table public.food_entries add column photo_path text;
alter table public.measurements add column photo_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', false, 8388608, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Jalur: <id orang tua>/<id anak>/<food|growth>/<id>.<ext>
create policy "orang tua unggah foto anak sendiri" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_parent_of((storage.foldername(name))[2])
  );

create policy "foto terlihat orang tua dan nakes" on storage.objects for select to authenticated
  using (
    bucket_id = 'photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_verified_health() or public.is_admin())
  );

create policy "orang tua hapus foto sendiri" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- ============================================================ F8. Token push notification
create table public.push_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null check (platform in ('web', 'android', 'ios')),
  updated_at timestamptz not null default now()
);
create index on public.push_tokens (user_id);
alter table public.push_tokens enable row level security;
create policy "token sendiri" on public.push_tokens for select to authenticated using (user_id = auth.uid());
revoke all on public.push_tokens from anon;

-- Satu perangkat bisa berganti akun: token dipindahkan ke pengguna yang sedang masuk.
create function public.register_push_token(p_token text, p_platform text) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Harus masuk.' using errcode = '42501';
  end if;
  insert into public.push_tokens (token, user_id, platform)
  values (p_token, auth.uid(), p_platform)
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end;
$$;

create function public.unregister_push_token(p_token text) returns void
language sql security definer set search_path = ''
as $$ delete from public.push_tokens where token = p_token and user_id = auth.uid() $$;

revoke execute on function public.register_push_token(text, text) from anon, public;
revoke execute on function public.unregister_push_token(text) from anon, public;
grant execute on function public.register_push_token(text, text) to authenticated;
grant execute on function public.unregister_push_token(text) to authenticated;

-- ============================================================ F6/F7. Kuota AI per pengguna per hari
-- Hanya Edge Function (service_role) yang menulis/membaca; tanpa kebijakan untuk klien.
create table public.ai_usage (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day date not null default public.today_wib(),
  kind text not null check (kind in ('chat', 'food_photo')),
  count int not null default 0,
  primary key (user_id, day, kind)
);
alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from anon, authenticated;

-- Menambah pemakaian bila masih di bawah batas; mengembalikan false bila kuota habis.
create function public.ai_take_quota(p_user uuid, p_kind text, p_limit int) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  n int;
begin
  insert into public.ai_usage (user_id, kind, count) values (p_user, p_kind, 1)
  on conflict (user_id, day, kind) do update set count = public.ai_usage.count + 1
    where public.ai_usage.count < p_limit
  returning count into n;
  return n is not null;
end;
$$;
revoke execute on function public.ai_take_quota(uuid, text, int) from anon, authenticated, public;
grant execute on function public.ai_take_quota(uuid, text, int) to service_role;
