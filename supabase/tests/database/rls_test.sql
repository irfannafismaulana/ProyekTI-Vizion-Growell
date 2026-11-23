-- Uji hak akses database (RLS) — jalankan: npx supabase test db
-- Memastikan aturan SRS ditegakkan di server, bukan hanya di aplikasi.
begin;
create extension if not exists pgtap with schema extensions;
select plan(45);

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
select throws_ok($$ insert into public.quiz_scores (user_id, display_name, points) values ('10000000-0000-4000-8000-000000000004', 'Dina Ayu', 700) $$,
                 '42501', null, 'v0.6: skor kuis tidak bisa ditulis aplikasi (hanya server)');

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

-- ------------------------------------------------------------ Video edukasi (v0.4)
select set_config('request.jwt.claims', json_build_object('sub', :sarah, 'role', 'authenticated')::text, true);
select lives_ok($$ insert into public.edu_videos (id, title, audience, storage_path, duration_seconds, size_bytes)
                   values ('v_uji', 'MPASI hati ayam', '{parent,teen}', '10000000-0000-4000-8000-000000000014/v_uji.mp4', 45, 1000) $$,
                'nakes terverifikasi boleh mengunggah video edukasi');
select throws_ok($$ insert into public.edu_videos (id, title, storage_path, duration_seconds, size_bytes)
                   values ('v_lain', 'Folder nakes lain', '10000000-0000-4000-8000-000000000011/v_lain.mp4', 45, 1000) $$,
                 '42501', null, 'nakes tidak bisa menyimpan video di folder nakes lain');
select throws_ok($$ insert into public.edu_videos (id, title, storage_path, duration_seconds, size_bytes)
                   values ('v_panjang', 'Video panjang', '10000000-0000-4000-8000-000000000014/v_panjang.mp4', 600, 1000) $$,
                 '23514', null, 'video lebih dari 3 menit ditolak');

select set_config('request.jwt.claims', json_build_object('sub', :dina, 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.edu_videos where id = 'v_uji'), 1, 'remaja dapat menonton video nakes');
select throws_ok($$ insert into public.edu_videos (id, title, storage_path, duration_seconds, size_bytes)
                   values ('v_dina', 'Video remaja', '10000000-0000-4000-8000-000000000004/v_dina.mp4', 30, 1000) $$,
                 '42501', null, 'remaja tidak bisa mengunggah video');
delete from public.edu_videos where id = 'v_uji';
select is((select count(*)::int from public.edu_videos where id = 'v_uji'), 1, 'remaja tidak bisa menghapus video nakes');

-- ------------------------------------------------------------ Kuis live (v0.6, PRD F5)
create temp table qroom (id uuid);
grant all on qroom to authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :dina, 'role', 'authenticated')::text, true);
insert into qroom select public.quiz_create_room(2, 'mudah', 'campuran', 5, 10, 'remaja');
select is((select count(*)::int from public.quiz_room_players), 1, 'host otomatis menjadi pemain pertama');
select throws_ok($$ select public.quiz_start((select id from qroom), array['u1','u2','u3','u4','u5']) $$,
                 'P0001', null, 'kuis tidak bisa dimulai sebelum ruang penuh');
select throws_ok($$ select count(*) from public.quiz_questions $$, '42501', null, 'kunci jawaban tidak bisa dibaca aplikasi');

reset role;
select code as qcode from public.quiz_rooms where id = (select id from qroom) \gset
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :sarah, 'role', 'authenticated')::text, true);
select throws_ok(format($$ select public.quiz_join_room(%L, 'umum') $$, :'qcode'), '42501', null, 'nakes tidak bisa ikut kuis');
select is((select count(*)::int from public.quiz_rooms), 0, 'bukan anggota tidak melihat ruang');

select set_config('request.jwt.claims', json_build_object('sub', :rani, 'role', 'authenticated')::text, true);
select lives_ok(format($$ select public.quiz_join_room(%L, 'orangTua') $$, :'qcode'), 'orang tua bergabung dengan kode');

select set_config('request.jwt.claims', json_build_object('sub', :dina, 'role', 'authenticated')::text, true);
select throws_ok($$ select public.quiz_start((select id from qroom), array['u1','u2','u3','u4','zz']) $$,
                 'P0001', null, 'daftar soal palsu ditolak');
select lives_ok($$ select public.quiz_start((select id from qroom), array['u1','u2','u3','u4','u5']) $$, 'host memulai saat ruang penuh');
select lives_ok($$ select public.quiz_answer((select id from qroom), 0, 1) $$, 'host menjawab soal 1 (benar)');
select throws_ok($$ insert into public.quiz_answers (room_id, user_id, question_index, choice, elapsed_ms, correct, points)
                   values ((select id from qroom), '10000000-0000-4000-8000-000000000004', 1, 0, 0, true, 1000) $$,
                 '42501', null, 'jawaban tidak bisa ditulis langsung (hanya lewat RPC)');

select set_config('request.jwt.claims', json_build_object('sub', :rani, 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.quiz_answers), 0, 'jawaban pemain lain tidak terlihat');
select lives_ok($$ select public.quiz_answer((select id from qroom), 0, 2) $$, 'pemain menjawab soal 1 (salah)');
select is((select status from public.quiz_rooms), 'reveal', 'semua menjawab → pembahasan');
select ok((select score > 500 from public.quiz_room_players where user_id = :dina), 'jawaban benar mendapat poin dari server');
select is((select score from public.quiz_room_players where user_id = :rani), 0, 'jawaban salah 0 poin');

-- ------------------------------------------------------------ Dokumen STR & push token (v0.6, PRD F2/F8)
select throws_ok($$ update public.profiles set str_document_path = 'orang-lain/str.pdf' where id = '10000000-0000-4000-8000-000000000001' $$,
                 '23514', null, 'jalur dokumen STR harus di folder sendiri');
select lives_ok($$ select public.register_push_token('token-uji-rani', 'web') $$, 'pengguna mendaftarkan token push');
select set_config('request.jwt.claims', json_build_object('sub', :dina, 'role', 'authenticated')::text, true);
select is((select count(*)::int from public.push_tokens), 0, 'token push pengguna lain tidak terlihat');
select throws_ok($$ select public.ai_take_quota('10000000-0000-4000-8000-000000000004', 'chat', 99) $$,
                 '42501', null, 'kuota AI hanya bisa diubah server');

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
