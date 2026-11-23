-- GroWell v0.6 — kuis multiplayer antar-perangkat (PRD F5).
-- Ruang, pemain, dan fase permainan disimpan di database dan disiarkan lewat Realtime.
-- Semua perubahan lewat fungsi RPC SECURITY DEFINER: klien tidak bisa menulis
-- tabel kuis secara langsung, dan nilai dihitung server dengan jam server (ER-7.3, ER-7.5).

-- ============================================================ Kunci jawaban
-- Salinan kunci dari lib/data/quiz_bank.dart (diuji agar selalu sama: test/v06_test.dart).
-- Tidak bisa dibaca klien.
create table public.quiz_questions (
  id text primary key,
  category text not null check (category in ('umum', 'remaja', 'orangTua')),
  difficulty text not null check (difficulty in ('mudah', 'sedang', 'sulit')),
  answer smallint not null check (answer between 0 and 3)
);
alter table public.quiz_questions enable row level security;
revoke all on public.quiz_questions from anon, authenticated;

insert into public.quiz_questions (id, category, difficulty, answer) values
  ('u1', 'umum', 'mudah', 1),
  ('u2', 'umum', 'mudah', 1),
  ('u3', 'umum', 'mudah', 0),
  ('u4', 'umum', 'mudah', 1),
  ('u5', 'umum', 'sedang', 1),
  ('u6', 'umum', 'sedang', 1),
  ('u7', 'umum', 'sedang', 2),
  ('u8', 'umum', 'sedang', 0),
  ('u9', 'umum', 'sulit', 1),
  ('u10', 'umum', 'sulit', 0),
  ('u11', 'umum', 'sulit', 1),
  ('u12', 'umum', 'mudah', 0),
  ('r1', 'remaja', 'mudah', 0),
  ('r2', 'remaja', 'mudah', 0),
  ('r3', 'remaja', 'mudah', 1),
  ('r4', 'remaja', 'sedang', 1),
  ('r5', 'remaja', 'sedang', 0),
  ('r6', 'remaja', 'sedang', 1),
  ('r7', 'remaja', 'mudah', 1),
  ('r8', 'remaja', 'sulit', 1),
  ('r9', 'remaja', 'sulit', 1),
  ('r10', 'remaja', 'sedang', 1),
  ('r11', 'remaja', 'sulit', 1),
  ('r12', 'remaja', 'mudah', 0),
  ('o1', 'orangTua', 'mudah', 1),
  ('o2', 'orangTua', 'mudah', 2),
  ('o3', 'orangTua', 'mudah', 2),
  ('o4', 'orangTua', 'sedang', 1),
  ('o5', 'orangTua', 'sedang', 0),
  ('o6', 'orangTua', 'sedang', 1),
  ('o7', 'orangTua', 'sedang', 2),
  ('o8', 'orangTua', 'sulit', 0),
  ('o9', 'orangTua', 'sulit', 0),
  ('o10', 'orangTua', 'mudah', 0),
  ('o11', 'orangTua', 'sulit', 1),
  ('o12', 'orangTua', 'sedang', 0),
  ('o13', 'orangTua', 'mudah', 2),
  ('o14', 'orangTua', 'sulit', 0),
  ('o15', 'orangTua', 'sedang', 1),
  ('o16', 'orangTua', 'mudah', 0);

-- ============================================================ Ruang & pemain
create table public.quiz_rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z2-9]{6}$'),
  host_id uuid not null references public.profiles (id) on delete cascade,
  capacity smallint not null check (capacity in (2, 4)),
  difficulty text not null check (difficulty in ('mudah', 'sedang', 'sulit')),
  category text not null check (category in ('umum', 'remaja', 'orangTua', 'campuran')),
  question_count smallint not null check (question_count between 5 and 20),
  seconds_per_question smallint not null check (seconds_per_question between 10 and 30),
  question_ids text[] not null default '{}',
  status text not null default 'lobby' check (status in ('lobby', 'question', 'reveal', 'finished')),
  current_index int not null default 0,
  phase_started_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.quiz_room_players (
  room_id uuid not null references public.quiz_rooms (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  display_name text not null,
  profile text not null default 'umum' check (profile in ('umum', 'remaja', 'orangTua')),
  joined_at timestamptz not null default now(),
  score int not null default 0,
  correct int not null default 0,
  total_answer_ms int not null default 0,
  answered_index int not null default -1, -- soal terakhir yang sudah dijawab (tanpa isi jawaban)
  last_choice smallint,                  -- jawaban pada soal terakhir yang sudah dibahas
  last_points int not null default 0,
  primary key (room_id, user_id)
);

-- Isi jawaban hanya terlihat pemiliknya; pemain lain baru melihat lewat last_choice saat pembahasan.
create table public.quiz_answers (
  room_id uuid not null references public.quiz_rooms (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  question_index int not null,
  choice smallint not null check (choice between 0 and 3),
  elapsed_ms int not null,
  correct boolean not null,
  points int not null,
  answered_at timestamptz not null default now(),
  primary key (room_id, user_id, question_index)
);

create function public.is_quiz_member(p_room uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.quiz_room_players where room_id = p_room and user_id = auth.uid()) $$;

alter table public.quiz_rooms enable row level security;
alter table public.quiz_room_players enable row level security;
alter table public.quiz_answers enable row level security;

create policy "ruang terlihat anggota" on public.quiz_rooms for select to authenticated
  using (public.is_quiz_member(id));
create policy "pemain terlihat sesama anggota" on public.quiz_room_players for select to authenticated
  using (public.is_quiz_member(room_id));
create policy "jawaban sendiri" on public.quiz_answers for select to authenticated
  using (user_id = auth.uid());
revoke all on public.quiz_rooms, public.quiz_room_players, public.quiz_answers from anon;
revoke insert, update, delete on public.quiz_rooms, public.quiz_room_players, public.quiz_answers from authenticated;

-- ============================================================ Fungsi bantu
create function public._quiz_profile(p text) returns text
language sql immutable set search_path = ''
as $$ select case when p in ('umum', 'remaja', 'orangTua') then p else 'umum' end $$;

create function public._quiz_reveal(r public.quiz_rooms) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.quiz_room_players p set
    last_choice = a.choice,
    last_points = coalesce(a.points, 0),
    score = p.score + coalesce(a.points, 0),
    correct = p.correct + case when a.correct then 1 else 0 end,
    total_answer_ms = p.total_answer_ms + coalesce(a.elapsed_ms, r.seconds_per_question * 1000)
  from public.quiz_room_players p2
  left join public.quiz_answers a
    on a.room_id = p2.room_id and a.user_id = p2.user_id and a.question_index = r.current_index
  where p.room_id = r.id and p2.room_id = p.room_id and p2.user_id = p.user_id;
  update public.quiz_rooms set status = 'reveal', phase_started_at = now() where id = r.id;
end;
$$;

-- ============================================================ RPC
create function public.quiz_create_room(
  p_capacity int, p_difficulty text, p_category text, p_count int, p_seconds int, p_profile text
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  me public.profiles;
  v_code text;
  v_id uuid;
  chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  select * into me from public.profiles where id = auth.uid();
  if me.id is null or me.role not in ('parent', 'teen') then
    raise exception 'Kuis hanya untuk peran orang tua dan remaja.' using errcode = '42501';
  end if;
  if p_capacity not in (2, 4) then raise exception 'Mode permainan harus 2 atau 4 pemain.' using errcode = 'P0001'; end if;
  if p_count not between 5 and 20 then raise exception 'Jumlah soal harus 5–20.' using errcode = 'P0001'; end if;
  if p_seconds not between 10 and 30 then raise exception 'Durasi per soal harus 10–30 detik.' using errcode = 'P0001'; end if;

  -- Ruang lama (lebih dari 1 hari) dibersihkan; satu pengguna hanya di satu ruang.
  delete from public.quiz_rooms where created_at < now() - interval '1 day';
  delete from public.quiz_rooms r where r.host_id = me.id and r.status = 'lobby';
  delete from public.quiz_room_players where user_id = me.id;

  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    end loop;
    exit when not exists (select 1 from public.quiz_rooms where code = v_code);
  end loop;

  insert into public.quiz_rooms (code, host_id, capacity, difficulty, category, question_count, seconds_per_question)
  values (v_code, me.id, p_capacity, p_difficulty, p_category, p_count, p_seconds)
  returning id into v_id;
  insert into public.quiz_room_players (room_id, user_id, display_name, profile)
  values (v_id, me.id, me.name, public._quiz_profile(p_profile));
  return v_id;
end;
$$;

create function public.quiz_join_room(p_code text, p_profile text) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  me public.profiles;
  r public.quiz_rooms;
  n int;
begin
  select * into me from public.profiles where id = auth.uid();
  if me.id is null or me.role not in ('parent', 'teen') then
    raise exception 'Kuis hanya untuk peran orang tua dan remaja.' using errcode = '42501';
  end if;
  select * into r from public.quiz_rooms where code = upper(trim(p_code)) for update;
  if r.id is null then
    raise exception 'Ruang % tidak ditemukan. Periksa kode dari host.', upper(trim(p_code)) using errcode = 'P0001';
  end if;
  if exists (select 1 from public.quiz_room_players where room_id = r.id and user_id = me.id) then
    return r.id;
  end if;
  if r.status <> 'lobby' then
    raise exception 'Permainan di ruang % sudah dimulai.', r.code using errcode = 'P0001';
  end if;
  select count(*) into n from public.quiz_room_players where room_id = r.id;
  if n >= r.capacity then
    raise exception 'Ruang % sudah penuh (% pemain).', r.code, r.capacity using errcode = 'P0001';
  end if;
  delete from public.quiz_room_players where user_id = me.id;
  insert into public.quiz_room_players (room_id, user_id, display_name, profile)
  values (r.id, me.id, me.name, public._quiz_profile(p_profile));
  return r.id;
end;
$$;

create function public.quiz_start(p_room uuid, p_question_ids text[]) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  r public.quiz_rooms;
  n int;
begin
  select * into r from public.quiz_rooms where id = p_room for update;
  if r.id is null or r.host_id <> auth.uid() then
    raise exception 'Hanya host yang dapat memulai kuis.' using errcode = '42501';
  end if;
  if r.status <> 'lobby' then return; end if;
  select count(*) into n from public.quiz_room_players where room_id = r.id;
  if n < r.capacity then
    raise exception 'Tunggu sampai ruang penuh (% / % pemain).', n, r.capacity using errcode = 'P0001';
  end if;
  if coalesce(array_length(p_question_ids, 1), 0) <> r.question_count
     or (select count(distinct q.id) from public.quiz_questions q where q.id = any (p_question_ids)) <> r.question_count then
    raise exception 'Daftar soal tidak valid.' using errcode = 'P0001';
  end if;
  update public.quiz_rooms
    set question_ids = p_question_ids, status = 'question', current_index = 0, phase_started_at = now()
    where id = r.id;
end;
$$;

create function public.quiz_answer(p_room uuid, p_index int, p_choice int) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  r public.quiz_rooms;
  el_ms int;
  dur_ms int;
  v_key smallint;
  ok boolean;
  pts int;
  n_players int;
  n_answered int;
begin
  if not public.is_quiz_member(p_room) then
    raise exception 'Anda bukan pemain di ruang ini.' using errcode = '42501';
  end if;
  select * into r from public.quiz_rooms where id = p_room for update;
  if r.status <> 'question' or r.current_index <> p_index then
    raise exception 'Waktu menjawab soal ini sudah habis.' using errcode = 'P0001';
  end if;
  dur_ms := r.seconds_per_question * 1000;
  el_ms := greatest(0, (extract(epoch from (now() - r.phase_started_at)) * 1000)::int);
  if el_ms > dur_ms + 500 then
    raise exception 'Waktu menjawab soal ini sudah habis.' using errcode = 'P0001';
  end if;
  el_ms := least(el_ms, dur_ms);
  select q.answer into v_key from public.quiz_questions q where q.id = r.question_ids[p_index + 1];
  ok := p_choice = v_key;
  -- ER-7.5: benar = 500 + bonus kecepatan hingga 500 (sama dengan pointsFor di quiz_rules.dart).
  pts := case when ok then 500 + round(500 * (dur_ms - el_ms)::numeric / dur_ms)::int else 0 end;
  insert into public.quiz_answers (room_id, user_id, question_index, choice, elapsed_ms, correct, points)
  values (p_room, auth.uid(), p_index, p_choice, el_ms, ok, pts)
  on conflict do nothing;
  if not found then return; end if;
  update public.quiz_room_players set answered_index = p_index where room_id = p_room and user_id = auth.uid();

  select count(*) into n_players from public.quiz_room_players where room_id = p_room;
  select count(*) into n_answered from public.quiz_room_players where room_id = p_room and answered_index = p_index;
  if n_answered >= n_players then
    perform public._quiz_reveal(r);
  end if;
end;
$$;

-- Memajukan fase bila waktunya tiba. Idempoten; boleh dipanggil semua pemain.
-- Mengembalikan jam server agar klien bisa menyelaraskan hitung mundur.
create function public.quiz_tick(p_room uuid) returns timestamptz
language plpgsql security definer set search_path = ''
as $$
declare
  r public.quiz_rooms;
  el numeric;
  n_players int;
  n_answered int;
begin
  if not public.is_quiz_member(p_room) then
    raise exception 'Anda bukan pemain di ruang ini.' using errcode = '42501';
  end if;
  select * into r from public.quiz_rooms where id = p_room for update;
  el := extract(epoch from (now() - r.phase_started_at));
  if r.status = 'question' then
    select count(*) into n_players from public.quiz_room_players where room_id = p_room;
    select count(*) into n_answered from public.quiz_room_players where room_id = p_room and answered_index = r.current_index;
    if el >= r.seconds_per_question or n_answered >= n_players then
      perform public._quiz_reveal(r);
    end if;
  elsif r.status = 'reveal' and el >= 3.5 then
    if r.current_index + 1 < coalesce(array_length(r.question_ids, 1), 0) then
      update public.quiz_rooms
        set status = 'question', current_index = r.current_index + 1, phase_started_at = now()
        where id = r.id;
    else
      update public.quiz_rooms set status = 'finished', phase_started_at = now() where id = r.id;
      -- Skor akhir semua pemain masuk papan skor mingguan (dihitung server).
      insert into public.quiz_scores (user_id, display_name, points, correct, total)
      select user_id, display_name, score, correct, r.question_count
      from public.quiz_room_players where room_id = r.id;
    end if;
  end if;
  return now();
end;
$$;

create function public.quiz_leave_room(p_room uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  r public.quiz_rooms;
begin
  select * into r from public.quiz_rooms where id = p_room for update;
  if r.id is null then return; end if;
  delete from public.quiz_room_players where room_id = p_room and user_id = auth.uid();
  if (r.status = 'lobby' and r.host_id = auth.uid())
     or not exists (select 1 from public.quiz_room_players where room_id = p_room) then
    delete from public.quiz_rooms where id = p_room;
  end if;
end;
$$;

revoke execute on function public.quiz_create_room(int, text, text, int, int, text) from anon, public;
revoke execute on function public.quiz_join_room(text, text) from anon, public;
revoke execute on function public.quiz_start(uuid, text[]) from anon, public;
revoke execute on function public.quiz_answer(uuid, int, int) from anon, public;
revoke execute on function public.quiz_tick(uuid) from anon, public;
revoke execute on function public.quiz_leave_room(uuid) from anon, public;
revoke execute on function public._quiz_reveal(public.quiz_rooms) from anon, authenticated, public;
grant execute on function public.quiz_create_room(int, text, text, int, int, text) to authenticated;
grant execute on function public.quiz_join_room(text, text) to authenticated;
grant execute on function public.quiz_start(uuid, text[]) to authenticated;
grant execute on function public.quiz_answer(uuid, int, int) to authenticated;
grant execute on function public.quiz_tick(uuid) to authenticated;
grant execute on function public.quiz_leave_room(uuid) to authenticated;

-- Skor kini hanya ditulis server (quiz_tick) agar tidak bisa dipalsukan aplikasi.
drop policy "pemain menyimpan skor sendiri" on public.quiz_scores;
revoke insert, update, delete on public.quiz_scores from authenticated;

-- ============================================================ Realtime
alter publication supabase_realtime add table public.quiz_rooms, public.quiz_room_players;
