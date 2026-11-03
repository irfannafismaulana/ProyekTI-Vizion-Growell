-- GroWell v0.3 — skema database (Supabase / PostgreSQL)
-- Tabel inti sesuai SRS draft_v3.2: akun & peran, data baduta, pengukuran,
-- gizi harian, konsultasi, kuis, dan preferensi konten.
-- Z-score dihitung di aplikasi dari tabel WHO; database menyimpan data mentah.

-- ============================================================ Tipe
create type public.user_role as enum ('parent', 'teen', 'health', 'admin');
create type public.sex as enum ('male', 'female');
create type public.meal as enum ('pagi', 'siang', 'malam', 'selingan');

-- Tanggal "hari ini" mengikuti WIB agar input pagi hari tidak dianggap masa depan.
create function public.today_wib() returns date
language sql stable
as $$ select (now() at time zone 'Asia/Jakarta')::date $$;

-- ============================================================ Akun & peran
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  email text not null,
  role public.user_role not null default 'parent',
  str_number text,
  verified boolean not null default false,
  title text,
  specialty text,
  experience_years int,
  workplace text,
  created_at timestamptz not null default now()
);
comment on table public.profiles is 'Profil pengguna; dibuat otomatis saat registrasi. Nakes aktif setelah STR diverifikasi admin.';

-- ============================================================ Data referensi
create table public.posyandu (
  name text primary key,
  region text not null
);
insert into public.posyandu (name, region) values
  ('Posyandu Melati', 'Kel. Kalideres'),
  ('Posyandu Mawar', 'Kel. Cilandak');

-- ============================================================ Baduta & pengukuran
create table public.children (
  id text primary key default gen_random_uuid()::text,
  parent_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  sex public.sex not null,
  birth_date date not null,
  posyandu text not null references public.posyandu (name),
  created_at timestamptz not null default now()
);
create index on public.children (parent_id);

create table public.measurements (
  id text primary key default gen_random_uuid()::text,
  child_id text not null references public.children (id) on delete cascade,
  measured_on date not null,
  weight_kg numeric(5, 2) not null check (weight_kg between 1 and 30),
  height_cm numeric(5, 1) not null check (height_cm between 40 and 120),
  source text not null default 'manual' check (source in ('manual', 'foto_simulasi')),
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index on public.measurements (child_id, measured_on);

-- ============================================================ Gizi harian
create table public.food_entries (
  id text primary key default gen_random_uuid()::text,
  child_id text not null references public.children (id) on delete cascade,
  eaten_on date not null,
  meal public.meal not null,
  food_id text not null,
  grams numeric(6, 1) not null check (grams > 0 and grams <= 1000),
  created_at timestamptz not null default now()
);
create index on public.food_entries (child_id, eaten_on);

-- ============================================================ Konsultasi
create table public.consult_threads (
  id text primary key default gen_random_uuid()::text,
  parent_id uuid not null references public.profiles (id) on delete cascade,
  doctor_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (parent_id, doctor_id)
);

create table public.consult_messages (
  id text primary key default gen_random_uuid()::text,
  thread_id text not null references public.consult_threads (id) on delete cascade,
  sender_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  sent_at timestamptz not null default now()
);
create index on public.consult_messages (thread_id, sent_at);

create table public.consult_notes (
  id text primary key default gen_random_uuid()::text,
  thread_id text not null references public.consult_threads (id) on delete cascade,
  child_id text not null references public.children (id) on delete cascade,
  doctor_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  keterangan text not null default '',
  diagnosis text not null check (length(trim(diagnosis)) > 0),
  anjuran text not null default '',
  catatan text not null default '',
  created_at timestamptz not null default now()
);

create table public.appointments (
  id text primary key default gen_random_uuid()::text,
  child_id text not null references public.children (id) on delete cascade,
  doctor_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  scheduled_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- ============================================================ Kuis
create table public.quiz_scores (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles (id) on delete cascade, -- null = pemain contoh/bot
  display_name text not null,
  points int not null check (points >= 0),
  correct int not null default 0,
  total int not null default 0,
  played_at timestamptz not null default now()
);

create table public.user_badges (
  user_id uuid not null references public.profiles (id) on delete cascade,
  badge text not null,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge)
);

-- Papan skor minggu berjalan (ER-7.5).
create view public.weekly_leaderboard with (security_invoker = true) as
  select display_name, sum(points)::int as points
  from public.quiz_scores
  where played_at >= date_trunc('week', now())
  group by display_name;

-- ============================================================ Preferensi konten
create table public.bookmarks (
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  item_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

create table public.reel_likes (
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  reel_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, reel_id)
);

-- ============================================================ Fungsi bantu RLS
-- SECURITY DEFINER agar kebijakan bisa membaca profiles tanpa rekursi RLS.
create function public.my_role() returns public.user_role
language sql stable security definer set search_path = ''
as $$ select role from public.profiles where id = auth.uid() $$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') $$;

create function public.is_verified_health() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'health' and verified) $$;

create function public.is_verified_health_user(uid uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles where id = uid and role = 'health' and verified) $$;

create function public.is_parent_of(child text) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.children where id = child and parent_id = auth.uid()) $$;

create function public.is_thread_member(thread text) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.consult_threads
    where id = thread and (parent_id = auth.uid() or doctor_id = auth.uid())
  )
$$;

-- ============================================================ Trigger
-- Profil dibuat dari metadata registrasi. Peran admin dan status verifikasi
-- tidak pernah bisa diminta sendiri saat mendaftar.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  r text := coalesce(meta ->> 'role', 'parent');
begin
  if r not in ('parent', 'teen', 'health') then
    r := 'parent';
  end if;
  insert into public.profiles (id, email, name, role, str_number, title, specialty, verified)
  values (
    new.id,
    new.email,
    coalesce(nullif(trim(meta ->> 'name'), ''), split_part(new.email, '@', 1)),
    r::public.user_role,
    nullif(trim(meta ->> 'str_number'), ''),
    meta ->> 'title',
    case when r = 'health' then coalesce(meta ->> 'specialty', 'Dokter Umum') end,
    false
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Hanya admin (lewat API) yang boleh mengubah peran atau status verifikasi.
-- Skrip seed/SQL langsung (tanpa JWT) tetap diizinkan.
create function public.protect_profile_columns() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if (new.role is distinct from old.role or new.verified is distinct from old.verified
      or new.id is distinct from old.id or new.email is distinct from old.email)
     and coalesce(auth.role(), '') in ('authenticated', 'anon')
     and not public.is_admin() then
    raise exception 'Hanya admin yang dapat mengubah peran atau status verifikasi STR.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger protect_profile_columns
  before update on public.profiles
  for each row execute function public.protect_profile_columns();

-- Validasi tanggal (ER-6.2): tidak di masa depan dan dalam cakupan baduta 0–24 bulan.
create function public.validate_child() returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.birth_date > public.today_wib() then
    raise exception 'Tanggal lahir tidak boleh di masa depan.' using errcode = '23514';
  end if;
  if tg_op = 'INSERT' and public.today_wib() - new.birth_date > 731 then
    raise exception 'GroWell memantau baduta usia 0–24 bulan.' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger validate_child
  before insert or update on public.children
  for each row execute function public.validate_child();

create function public.validate_measurement() returns trigger
language plpgsql set search_path = ''
as $$
declare
  born date;
begin
  select birth_date into born from public.children where id = new.child_id;
  if new.measured_on > public.today_wib() then
    raise exception 'Tanggal ukur tidak boleh di masa depan.' using errcode = '23514';
  end if;
  if new.measured_on < born then
    raise exception 'Tanggal ukur sebelum tanggal lahir anak.' using errcode = '23514';
  end if;
  if new.measured_on - born > 731 then
    raise exception 'Umur anak pada tanggal ukur di luar cakupan 0–24 bulan.' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger validate_measurement
  before insert or update on public.measurements
  for each row execute function public.validate_measurement();

-- ============================================================ Row Level Security
alter table public.profiles enable row level security;
alter table public.posyandu enable row level security;
alter table public.children enable row level security;
alter table public.measurements enable row level security;
alter table public.food_entries enable row level security;
alter table public.consult_threads enable row level security;
alter table public.consult_messages enable row level security;
alter table public.consult_notes enable row level security;
alter table public.appointments enable row level security;
alter table public.quiz_scores enable row level security;
alter table public.user_badges enable row level security;
alter table public.bookmarks enable row level security;
alter table public.reel_likes enable row level security;

-- profiles: diri sendiri, daftar dokter terverifikasi, lawan bicara konsultasi;
-- nakes terverifikasi & admin melihat semua (nama orang tua di kotak masuk, verifikasi STR).
create policy "profil terlihat sesuai peran" on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or (role = 'health' and verified)
    or public.is_admin()
    or public.is_verified_health()
    or exists (select 1 from public.consult_threads t
               where (t.parent_id = auth.uid() and t.doctor_id = profiles.id)
                  or (t.doctor_id = auth.uid() and t.parent_id = profiles.id))
  );
create policy "ubah profil sendiri atau admin" on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

create policy "posyandu dapat dibaca" on public.posyandu for select to authenticated using (true);

-- children: orang tua pemilik; nakes terverifikasi & admin hanya membaca (dashboard).
create policy "anak terlihat oleh pemilik dan nakes" on public.children for select to authenticated
  using (parent_id = auth.uid() or public.is_verified_health() or public.is_admin());
create policy "orang tua menambah anak" on public.children for insert to authenticated
  with check (parent_id = auth.uid() and public.my_role() = 'parent');
create policy "orang tua mengubah anak" on public.children for update to authenticated
  using (parent_id = auth.uid()) with check (parent_id = auth.uid());
create policy "orang tua menghapus anak" on public.children for delete to authenticated
  using (parent_id = auth.uid());

-- measurements & food_entries: diisi orang tua; dibaca nakes terverifikasi.
create policy "pengukuran terlihat" on public.measurements for select to authenticated
  using (public.is_parent_of(child_id) or public.is_verified_health() or public.is_admin());
create policy "orang tua mencatat pengukuran" on public.measurements for insert to authenticated
  with check (public.is_parent_of(child_id));
create policy "orang tua menghapus pengukuran" on public.measurements for delete to authenticated
  using (public.is_parent_of(child_id));

create policy "catatan makan terlihat" on public.food_entries for select to authenticated
  using (public.is_parent_of(child_id) or public.is_verified_health() or public.is_admin());
create policy "orang tua mencatat makan" on public.food_entries for insert to authenticated
  with check (public.is_parent_of(child_id));
create policy "orang tua menghapus catatan makan" on public.food_entries for delete to authenticated
  using (public.is_parent_of(child_id));

-- Konsultasi (ER-4.2 / TC-03).
create policy "percakapan terlihat peserta" on public.consult_threads for select to authenticated
  using (parent_id = auth.uid() or doctor_id = auth.uid());
create policy "orang tua membuka percakapan dengan nakes terverifikasi" on public.consult_threads for insert to authenticated
  with check (parent_id = auth.uid() and public.my_role() = 'parent' and public.is_verified_health_user(doctor_id));

create policy "pesan terlihat peserta" on public.consult_messages for select to authenticated
  using (public.is_thread_member(thread_id));
create policy "hanya penanya atau nakes terverifikasi yang ditunjuk" on public.consult_messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.consult_threads t
      where t.id = thread_id
        and (t.parent_id = auth.uid() or (t.doctor_id = auth.uid() and public.is_verified_health()))
    )
  );

create policy "catatan konsultasi terlihat peserta" on public.consult_notes for select to authenticated
  using (public.is_thread_member(thread_id));
create policy "nakes yang menangani menulis catatan" on public.consult_notes for insert to authenticated
  with check (
    doctor_id = auth.uid()
    and public.is_verified_health()
    and exists (
      select 1 from public.consult_threads t
      join public.children c on c.parent_id = t.parent_id
      where t.id = thread_id and t.doctor_id = auth.uid() and c.id = child_id
    )
  );

create policy "jadwal terlihat orang tua dan dokter" on public.appointments for select to authenticated
  using (public.is_parent_of(child_id) or doctor_id = auth.uid());
create policy "nakes terverifikasi menjadwalkan kontrol" on public.appointments for insert to authenticated
  with check (doctor_id = auth.uid() and public.is_verified_health() and scheduled_at >= now() - interval '1 day');

-- Kuis: semua pengguna login melihat papan skor; hanya orang tua & remaja yang bermain.
create policy "papan skor terlihat" on public.quiz_scores for select to authenticated using (true);
create policy "pemain menyimpan skor sendiri" on public.quiz_scores for insert to authenticated
  with check (user_id = auth.uid() and public.my_role() in ('parent', 'teen'));

create policy "lencana sendiri" on public.user_badges for select to authenticated using (user_id = auth.uid());
create policy "simpan lencana sendiri" on public.user_badges for insert to authenticated with check (user_id = auth.uid());

create policy "simpanan sendiri" on public.bookmarks for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "suka sendiri" on public.reel_likes for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Pengguna anonim tidak mendapat akses data apa pun.
revoke all on all tables in schema public from anon;

-- ============================================================ Realtime
-- Perubahan dikirim ke aplikasi secara langsung (tetap disaring RLS).
alter publication supabase_realtime add table
  public.profiles, public.children, public.measurements,
  public.consult_threads, public.consult_messages, public.consult_notes, public.appointments;
