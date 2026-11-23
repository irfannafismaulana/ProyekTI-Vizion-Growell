-- GroWell v0.4 — video edukasi singkat yang diunggah tenaga kesehatan.
-- Video tampil di tab Reels orang tua/remaja sesuai sasaran (audience).
-- Berkas disimpan di Supabase Storage (bucket edu-videos), metadata di tabel edu_videos.

-- ============================================================ Tabel
create table public.edu_videos (
  id text primary key,
  author_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 3 and 120),
  caption text not null default '' check (char_length(caption) <= 1000),
  audience public.user_role[] not null default '{parent,teen}'
    check (cardinality(audience) > 0 and audience <@ array['parent', 'teen']::public.user_role[]),
  storage_path text not null unique,
  duration_seconds integer not null check (duration_seconds between 1 and 180),
  size_bytes bigint not null check (size_bytes between 1 and 52428800),
  created_at timestamptz not null default now()
);

create index edu_videos_created_at_idx on public.edu_videos (created_at desc);

-- ============================================================ RLS
alter table public.edu_videos enable row level security;

-- Semua pengguna yang masuk boleh menonton.
create policy "video dapat ditonton" on public.edu_videos for select to authenticated using (true);

-- Hanya nakes terverifikasi yang mengunggah, atas namanya sendiri, ke foldernya sendiri.
create policy "nakes mengunggah video" on public.edu_videos for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.is_verified_health()
    and split_part(storage_path, '/', 1) = auth.uid()::text
  );

-- Pengunggah atau admin boleh menghapus.
create policy "hapus video sendiri" on public.edu_videos for delete to authenticated
  using (author_id = auth.uid() or public.is_admin());

revoke all on public.edu_videos from anon;

-- ============================================================ Storage
-- Bucket publik: berkas bisa diputar lewat URL publik (konten edukasi, bukan data pribadi).
-- Batas 50 MB per berkas (sama dengan batas paket gratis Supabase).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('edu-videos', 'edu-videos', true, 52428800, array['video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Unggah hanya ke folder <id pengguna>/ oleh nakes terverifikasi.
create policy "nakes unggah berkas video" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'edu-videos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_verified_health()
  );

-- Storage butuh izin SELECT agar berkas bisa dihapus lewat API.
create policy "lihat berkas video" on storage.objects for select to authenticated
  using (bucket_id = 'edu-videos');

create policy "hapus berkas video sendiri" on storage.objects for delete to authenticated
  using (
    bucket_id = 'edu-videos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );

-- ============================================================ Realtime
alter publication supabase_realtime add table public.edu_videos;
