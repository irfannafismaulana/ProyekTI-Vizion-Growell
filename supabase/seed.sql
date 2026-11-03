-- GroWell v0.3 — data contoh (fiktif). Semua akun memakai password: demo123
-- Dijalankan otomatis oleh `supabase start` / `supabase db reset`.
-- Tanggal dibuat relatif terhadap hari ini (WIB) agar umur anak selalu sesuai.

-- ============================================================ Akun demo
with akun (id, email, name, role, str_number, title, specialty, exp, workplace) as (
  values
    ('10000000-0000-4000-8000-000000000001'::uuid, 'rani@demo.id',   'Rani Lestari',             'parent', null, null, null, null, null),
    ('10000000-0000-4000-8000-000000000002'::uuid, 'fitri@demo.id',  'Fitri Handayani',          'parent', null, null, null, null, null),
    ('10000000-0000-4000-8000-000000000003'::uuid, 'wulan@demo.id',  'Wulan Sari',               'parent', null, null, null, null, null),
    ('10000000-0000-4000-8000-000000000004'::uuid, 'dina@demo.id',   'Dina Ayu',                 'teen',   null, null, null, null, null),
    ('10000000-0000-4000-8000-000000000011'::uuid, 'irfan@demo.id',  'Dr. Irfan Nufis M, Sp.A',  'health', 'STR-CONTOH-0001', 'Dokter spesialis anak', 'Spesialis Anak', 8, 'RS Contoh Sehat'),
    ('10000000-0000-4000-8000-000000000012'::uuid, 'siti@demo.id',   'Dr. Siti Rahmawati, Sp.PD', 'health', 'STR-CONTOH-0002', 'Dokter spesialis penyakit dalam', 'Spesialis Penyakit Dalam', 10, 'RS Contoh Sehat'),
    ('10000000-0000-4000-8000-000000000013'::uuid, 'budi@demo.id',   'Dr. Budi Santoso, Sp.OG',  'health', 'STR-CONTOH-0003', 'Dokter spesialis kandungan', 'Spesialis Kandungan', 12, 'RS Contoh Sehat'),
    ('10000000-0000-4000-8000-000000000014'::uuid, 'sarah@demo.id',  'dr. Sarah Wijaya, Sp.A',   'health', 'STR-CONTOH-0004', 'Dokter spesialis anak', 'Spesialis Anak', 6, 'Puskesmas Contoh'),
    ('10000000-0000-4000-8000-000000000015'::uuid, 'rina@demo.id',   'Rina Kartika, S.Gz.',      'health', 'STR-CONTOH-0005', 'Ahli gizi (dietisien)', 'Ahli Gizi', 6, 'Puskesmas Contoh'),
    ('10000000-0000-4000-8000-000000000016'::uuid, 'candra@demo.id', 'dr. Candra Wijaya',        'health', 'STR-CONTOH-0006', 'Dokter umum', 'Dokter Umum', 2, 'Klinik Contoh'),
    ('10000000-0000-4000-8000-000000000099'::uuid, 'admin@demo.id',  'Admin GroWell',            'admin',  null, null, null, null, null)
),
users as (
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  )
  select
    '00000000-0000-0000-0000-000000000000', a.id, 'authenticated', 'authenticated', a.email,
    extensions.crypt('demo123', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('name', a.name, 'role', case when a.role = 'admin' then 'parent' else a.role end,
                       'str_number', a.str_number, 'title', a.title, 'specialty', a.specialty),
    now(), now(), '', '', '', ''
  from akun a
  returning id, email
)
insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now(), now(), now()
from users u;

-- Trigger handle_new_user sudah membuat profil; lengkapi data nakes, verifikasi STR, dan admin.
update public.profiles p set
  verified = (p.email <> 'candra@demo.id'),
  experience_years = x.exp,
  workplace = x.workplace
from (values
  ('irfan@demo.id', 8, 'RS Contoh Sehat'),
  ('siti@demo.id', 10, 'RS Contoh Sehat'),
  ('budi@demo.id', 12, 'RS Contoh Sehat'),
  ('sarah@demo.id', 6, 'Puskesmas Contoh'),
  ('rina@demo.id', 6, 'Puskesmas Contoh'),
  ('candra@demo.id', 2, 'Klinik Contoh')
) as x(email, exp, workplace)
where p.email = x.email;

update public.profiles set role = 'admin' where email = 'admin@demo.id';

-- ============================================================ Baduta (umur relatif terhadap hari ini)
insert into public.children (id, parent_id, name, sex, birth_date, posyandu)
select c.id, p.id, c.name, c.sex::public.sex, public.today_wib() - c.age_days, c.posyandu
from (values
  ('c_abiyu', 'rani@demo.id',  'Abiyu',  'male',   198, 'Posyandu Melati'),
  ('c_alya',  'rani@demo.id',  'Alya',   'female', 300, 'Posyandu Melati'),
  ('c_rafa',  'fitri@demo.id', 'Rafa',   'male',   600, 'Posyandu Melati'),
  ('c_kenzo', 'fitri@demo.id', 'Kenzo',  'male',   400, 'Posyandu Melati'),
  ('c_citra', 'fitri@demo.id', 'Citra',  'female', 200, 'Posyandu Melati'),
  ('c_sekar', 'fitri@demo.id', 'Sekar',  'female', 700, 'Posyandu Melati'),
  ('c_nadia', 'wulan@demo.id', 'Nadia',  'female', 500, 'Posyandu Mawar'),
  ('c_bayu',  'wulan@demo.id', 'Bayu',   'male',   650, 'Posyandu Mawar'),
  ('c_dimas', 'wulan@demo.id', 'Dimas',  'male',   120, 'Posyandu Mawar')
) as c(id, email, name, sex, age_days, posyandu)
join public.profiles p on p.email = c.email;

-- Pengukuran: (anak, umur saat diukur dalam hari, berat kg, panjang cm)
insert into public.measurements (child_id, measured_on, weight_kg, height_cm, created_by)
select m.child_id, ch.birth_date + m.age, m.w, m.h, ch.parent_id
from (values
  ('c_abiyu', 30, 3.9, 52.0), ('c_abiyu', 61, 4.6, 55.0), ('c_abiyu', 91, 5.3, 57.5),
  ('c_abiyu', 122, 5.8, 59.5), ('c_abiyu', 152, 6.2, 61.0), ('c_abiyu', 183, 6.5, 62.3),
  ('c_alya', 120, 5.9, 61.0), ('c_alya', 150, 6.4, 63.0), ('c_alya', 180, 6.8, 64.6), ('c_alya', 210, 7.2, 66.5),
  ('c_alya', 240, 7.5, 67.8), ('c_alya', 270, 7.8, 69.0), ('c_alya', 290, 8.0, 70.0),
  ('c_rafa', 420, 8.9, 73.5), ('c_rafa', 480, 9.2, 75.0), ('c_rafa', 570, 9.6, 77.0),
  ('c_kenzo', 390, 9.3, 74.5),
  ('c_citra', 190, 7.0, 65.0),
  ('c_sekar', 690, 10.8, 83.5),
  ('c_nadia', 490, 8.2, 72.0),
  ('c_bayu', 640, 9.0, 75.5),
  ('c_dimas', 110, 6.3, 61.5)
) as m(child_id, age, w, h)
join public.children ch on ch.id = m.child_id;

-- ============================================================ Catatan makan (sama dengan data lokal v0.2)
-- Variasi porsi: base * (0,85 + ((hari*37) mod 30)/100)
insert into public.food_entries (child_id, eaten_on, meal, food_id, grams)
select 'c_abiyu', public.today_wib() - d, x.meal::public.meal, x.food,
       round((x.base * (0.85 + (((d + x.shift) * 37) % 30) / 100.0))::numeric, 1)
from generate_series(1, 14) as d
cross join lateral (values
  ('pagi', 'bubur', 80.0, 0),
  ('pagi', 'telur', 15.0, 0),
  ('siang', 'bubur', 80.0, 3),
  ('siang', case when d % 2 = 0 then 'hati' else 'ikan' end, 12.0, 0)
) as x(meal, food, base, shift)
union all
select 'c_abiyu', public.today_wib() - d, 'siang', x.food, x.g
from generate_series(1, 14) as d
cross join (values ('wortel', 10.0), ('minyak', 2.0)) as x(food, g)
union all
select 'c_abiyu', public.today_wib() - d, 'selingan', 'pisang', round((30 * (0.85 + ((d * 37) % 30) / 100.0))::numeric, 1)
from generate_series(1, 14) as d where d % 3 <> 0
union all
select 'c_abiyu', public.today_wib(), 'pagi', f, g from (values ('bubur', 80.0), ('telur', 15.0)) as t(f, g);

insert into public.food_entries (child_id, eaten_on, meal, food_id, grams)
select 'c_alya', public.today_wib() - d, x.meal::public.meal, x.food,
       round((x.base * (0.85 + (((d + x.shift) * 37) % 30) / 100.0))::numeric, 1)
from generate_series(1, 60) as d
cross join lateral (values
  ('pagi', 'bubur', 100.0, 0),
  ('pagi', 'telur', 25.0, 0),
  ('siang', 'nasi', 50.0, 5),
  ('siang', case d % 3 when 0 then 'ayam' when 1 then 'ikan' else 'tempe' end, 20.0, 0),
  ('malam', 'nasi', 50.0, 9),
  ('malam', case when d % 2 = 1 then 'hati' else 'tahu' end, 15.0, 0),
  ('selingan', case when d % 2 = 0 then 'pepaya' else 'alpukat' end, 40.0, 0)
) as x(meal, food, base, shift)
union all
select 'c_alya', public.today_wib() - d, x.meal::public.meal, x.food, x.g
from generate_series(1, 60) as d
cross join lateral (values
  ('siang', case when d % 2 = 0 then 'bayam' else 'brokoli' end, 20.0),
  ('malam', 'minyak', 3.0)
) as x(meal, food, g)
union all
select 'c_alya', public.today_wib(), 'pagi', f, g from (values ('bubur', 100.0), ('telur', 25.0)) as t(f, g);

-- ============================================================ Konsultasi
insert into public.consult_threads (id, parent_id, doctor_id) values
  ('t_seed',  '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000014'),
  ('t_irfan', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000011');

insert into public.consult_messages (thread_id, sender_id, body, sent_at) values
  ('t_seed', '10000000-0000-4000-8000-000000000001',
   'Dok, panjang badan Abiyu naiknya sedikit sekali dua bulan ini. Apa perlu khawatir?', now() - interval '8 days 3 hours'),
  ('t_seed', '10000000-0000-4000-8000-000000000014',
   'Bu, mohon datang ke Puskesmas untuk pengukuran ulang. Sementara itu catat MPASI Abiyu di menu Gizi Harian ya.', now() - interval '8 days 1 hour'),
  ('t_irfan', '10000000-0000-4000-8000-000000000011', 'Halo, ada yang bisa saya bantu?', now() - interval '20 hours'),
  ('t_irfan', '10000000-0000-4000-8000-000000000001', 'Halo dok, saya ingin konsultasi.', now() - interval '19 hours 58 minutes'),
  ('t_irfan', '10000000-0000-4000-8000-000000000011', 'Silakan, keluhan apa yang ingin disampaikan?', now() - interval '19 hours 55 minutes');

insert into public.consult_notes (id, thread_id, child_id, doctor_id, title, keterangan, diagnosis, anjuran, catatan, created_at) values (
  'n_seed', 't_seed', 'c_abiyu', '10000000-0000-4000-8000-000000000014',
  'Deteksi Dini Stunting',
  'Deteksi dini stunting (anak 6 bulan). Panjang badan 62,3 cm dan berat badan 6,5 kg. Panjang badan anak di bawah standar WHO. '
    || 'Diperlukan evaluasi asupan nutrisi, riwayat kesehatan, dan pola makan untuk intervensi stunting.',
  'Risiko stunting – panjang badan kurang dari standar usia',
  'Lanjutkan ASI. MPASI 2–3 kali sehari dengan protein hewani setiap makan (telur, ikan, hati ayam) dan tambahan lemak. '
    || 'Timbang dan ukur rutin setiap bulan.',
  'Kontrol ulang dalam 1 bulan. Jika tidak ada peningkatan, rujuk ke spesialis gizi.',
  ((public.today_wib() - 7) + time '13:42') at time zone 'Asia/Jakarta'
);

insert into public.appointments (id, child_id, doctor_id, scheduled_at) values (
  'ap_seed', 'c_abiyu', '10000000-0000-4000-8000-000000000014',
  ((public.today_wib() + 5) + time '09:00') at time zone 'Asia/Jakarta'
);

-- ============================================================ Papan skor kuis minggu ini
insert into public.quiz_scores (user_id, display_name, points, correct, total) values
  ('10000000-0000-4000-8000-000000000004', 'Dina Ayu', 2350, 9, 10),
  ('10000000-0000-4000-8000-000000000002', 'Fitri Handayani', 1980, 8, 10),
  (null, 'Bot Rina', 3120, 10, 10),
  (null, 'Bot Adi', 1640, 7, 10);
