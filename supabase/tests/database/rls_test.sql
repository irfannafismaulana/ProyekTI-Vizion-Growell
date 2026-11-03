-- Uji hak akses database (RLS) — jalankan: npx supabase test db
-- Memastikan aturan SRS ditegakkan di server, bukan hanya di aplikasi.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

-- id akun demo (lihat supabase/seed.sql)
\set rani   '''10000000-0000-4000-8000-000000000001'''
\set dina   '''10000000-0000-4000-8000-000000000004'''
\set irfan  '''10000000-0000-4000-8000-000000000011'''
\set sarah  '''10000000-0000-4000-8000-000000000014'''
\set candra '''10000000-0000-4000-8000-000000000016'''
\set admin  '''10000000-0000-4000-8000-000000000099'''

-- ------------------------------------------------------------ Orang tua (Rani)
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :rani, 'role', 'authenticated')::text, true);

select is((select count(*)::int from public.children), 2, 'orang tua hanya melihat 2 anaknya sendiri');
select is((select count(*)::int from public.consult_threads), 2, 'orang tua melihat 2 percakapannya');
select lives_ok($$ insert into public.consult_messages (thread_id, sender_id, body)
                   values ('t_seed', '10000000-0000-4000-8000-000000000001', 'Baik dok, terima kasih') $$,
                'orang tua pemilik percakapan boleh bertanya');
select throws_ok($$ insert into public.measurements (child_id, measured_on, weight_kg, height_cm) values ('c_rafa', current_date, 9.8, 78) $$,
                 '42501', null, 'orang tua tidak bisa mencatat pengukuran anak orang lain');
select throws_ok($$ insert into public.measurements (child_id, measured_on, weight_kg, height_cm) values ('c_abiyu', current_date + 3, 6.8, 63) $$,
                 '23514', null, 'tanggal ukur di masa depan ditolak (ER-6.2)');
select throws_ok($$ insert into public.consult_threads (parent_id, doctor_id) values ('10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000016') $$,
                 '42501', null, 'tidak bisa konsultasi ke nakes yang STR-nya belum diverifikasi');
select throws_ok($$ update public.profiles set role = 'admin' where id = '10000000-0000-4000-8000-000000000001' $$,
                 '42501', null, 'orang tua tidak bisa menjadikan dirinya admin');
update public.profiles set verified = true where id = '10000000-0000-4000-8000-000000000016';

-- ------------------------------------------------------------ Remaja (Dina)
select set_config('request.jwt.claims', json_build_object('sub', :dina, 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.children), 0, 'remaja tidak melihat data baduta');
select throws_ok($$ insert into public.consult_messages (thread_id, sender_id, body) values ('t_seed', '10000000-0000-4000-8000-000000000004', 'Jawaban') $$,
                 '42501', null, 'TC-03: remaja ditolak memberi jawaban medis');
select lives_ok($$ insert into public.quiz_scores (user_id, display_name, points) values ('10000000-0000-4000-8000-000000000004', 'Dina Ayu', 700) $$,
                'remaja boleh menyimpan skor kuis sendiri');

-- ------------------------------------------------------------ Dokter lain (Irfan) dan nakes belum terverifikasi (Candra)
select set_config('request.jwt.claims', json_build_object('sub', :irfan, 'role', 'authenticated')::text, true);
select throws_ok($$ insert into public.consult_messages (thread_id, sender_id, body) values ('t_seed', '10000000-0000-4000-8000-000000000011', 'Jawaban') $$,
                 '42501', null, 'TC-03: dokter yang tidak ditunjuk ditolak menjawab');

select set_config('request.jwt.claims', json_build_object('sub', :candra, 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.children), 0, 'nakes belum terverifikasi tidak melihat dashboard baduta');

-- ------------------------------------------------------------ Dokter yang ditunjuk (Sarah)
select set_config('request.jwt.claims', json_build_object('sub', :sarah, 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.children), 9, 'nakes terverifikasi melihat 9 baduta (dashboard)');
select lives_ok($$ insert into public.consult_messages (thread_id, sender_id, body) values ('t_seed', '10000000-0000-4000-8000-000000000014', 'Sama-sama, Bu') $$,
                'TC-03: nakes terverifikasi yang ditunjuk boleh menjawab');
select throws_ok($$ insert into public.measurements (child_id, measured_on, weight_kg, height_cm) values ('c_abiyu', current_date, 6.8, 63) $$,
                 '42501', null, 'nakes hanya membaca data pengukuran');
select throws_ok($$ insert into public.quiz_scores (user_id, display_name, points) values ('10000000-0000-4000-8000-000000000014', 'dr. Sarah', 100) $$,
                 '42501', null, 'nakes tidak ikut kuis');

-- ------------------------------------------------------------ Admin
select set_config('request.jwt.claims', json_build_object('sub', :admin, 'role', 'authenticated')::text, true);
select is((select verified from public.profiles where id = :candra), false, 'update verifikasi oleh orang tua tidak berpengaruh');
update public.profiles set verified = true where id = '10000000-0000-4000-8000-000000000016';
select is((select verified from public.profiles where id = :candra), true, 'admin dapat memverifikasi STR');

-- ------------------------------------------------------------ Pengguna anonim
reset role;
set local role anon;
select throws_ok($$ select count(*) from public.children $$, '42501', null, 'pengguna tanpa login tidak bisa membaca data');

-- ------------------------------------------------------------ Registrasi
reset role;
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data)
values ('00000000-0000-0000-0000-000000000000', '20000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
        'penyusup@demo.id', '{"name":"Penyusup","role":"admin"}');
select is(
  (select role::text || '/' || verified::text from public.profiles where email = 'penyusup@demo.id'), 'parent/false',
  'registrasi yang meminta peran admin tetap menjadi orang tua, tidak terverifikasi'
);

select * from finish();
rollback;
