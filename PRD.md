# PRD — GroWell: dari Prototype ke Fitur Live

| | |
|---|---|
| Dokumen | Product Requirements Document — fitur live GroWell |
| Versi aplikasi | v0.6 (`growell_app_v0.6/`) |
| Tanggal | 23 November 2026 |
| Pemilik | Tim GroWell (Vizion) — backend: Muhammad Farid Irham |
| Status | Fase 1–4 dikerjakan di v0.6; fase 5–6 direncanakan |

Dokumen ini mendaftar fitur GroWell yang **masih simulasi / hanya untuk pengujian** di prototype v0.5, lalu menjelaskan apa yang dibutuhkan agar fitur itu benar-benar berjalan (live) untuk pengguna sungguhan: kebutuhan fungsional, desain teknis, kriteria penerimaan, dan apa yang harus disiapkan tim (akun/kunci layanan).

---

## 1. Latar belakang

Prototype v0.5 sudah memakai Supabase sungguhan untuk data inti (akun, anak, pengukuran, catatan makan, konsultasi, video nakes, skor kuis) dengan Row Level Security. Namun beberapa fitur yang tampak di layar masih disimulasikan agar alur bisa didemokan. Sebelum GroWell dipakai orang tua, remaja, dan tenaga kesehatan sungguhan, fitur-fitur itu harus diganti dengan layanan nyata atau diberi batasan yang jelas.

## 2. Ringkasan status

| # | Fitur | Status v0.5 | Rencana | Fase |
|---|---|---|---|---|
| F1 | Email OTP (lupa password) | Lokal: kode tetap `123456`; cloud: email bawaan Supabase hanya ke anggota tim | SMTP sendiri di Supabase Auth | 1 |
| F2 | Unggah dokumen STR nakes | Simulasi (`dokumen_STR.pdf (simulasi)`) | Bucket privat `str-documents`, admin membuka dokumen asli | 1 |
| F3 | Foto makanan & foto anak | Tidak diunggah ke mana pun | Bucket privat `photos`, tersambung ke catatan | 1 |
| F4 | Akun & data demo | Tombol akun demo, rute `/demo/…`, seed `demo123` | Saklar `GROWELL_DEMO`; build rilis tanpa demo & tanpa seed | 1 |
| F5 | Kuis multiplayer | Lawan bot, kode ruang demo `GRW24A` | Ruang antar-perangkat via Supabase Realtime, skor dihitung server | 2 |
| F6 | AI pendamping gizi | Pencocokan kata kunci | LLM via NanoGPT lewat Edge Function | 3 |
| F7 | Deteksi gizi dari foto makanan | Hasil acak/simulasi | Model vision via NanoGPT → dicocokkan ke tabel pangan | 3 |
| F8 | Push notification | Hanya pengingat di dalam aplikasi | Firebase Cloud Messaging (web + Android) | 4 |
| F9 | Aplikasi Android | Belum pernah di-build | Build APK + uji di perangkat | 4 |
| F10 | Estimasi tinggi/berat dari foto anak | Proyeksi dari tren | **Tidak dijadikan fitur medis**; foto disimpan sebagai catatan | — |
| F11 | Panggilan suara/video konsultasi | Tersambung palsu setelah 3 detik | Layanan WebRTC (LiveKit/Agora/Daily) | 5 |
| F12 | Reels bawaan, suka & komentar | Sampul + progres palsu, angka contoh | Video nakes asli + tabel komentar & hitungan suka | 5 |
| F13 | Konten (artikel, soal kuis, aturan status) | Draf, belum ditinjau nakes | Ditinjau & disahkan nakes; bank soal ≥ 100 | 6 |
| F14 | Infrastruktur produksi | Supabase gratis (dijeda setelah 7 hari tidak aktif) | Paket Pro / keep-alive, backup, monitoring | 6 |

---

## 3. Fase 1 — Fondasi rilis

### F1. Email OTP lewat SMTP sendiri
**Masalah.** Email bawaan Supabase dibatasi beberapa email per jam dan hanya dikirim ke alamat anggota tim proyek, sehingga OTP lupa password tidak sampai ke pengguna sungguhan.

**Kebutuhan.**
- OTP 6 digit dikirim ke email pengguna terdaftar dalam < 1 menit.
- Pengirim memakai nama "GroWell" dan template berbahasa Indonesia (sudah ada: `supabase/templates/recovery.html`).
- Lokal tetap memakai Mailpit (http://127.0.0.1:54324) tanpa SMTP.

**Desain.** Penyedia SMTP transaksional (mis. Resend, Brevo, Mailjet — paket gratis cukup untuk tahap awal) dipasang di Supabase Dashboard → Authentication → Emails → SMTP Settings. Template `config.toml` sudah disiapkan (dikomentari) dengan `env(SMTP_PASS)` agar kata sandi tidak pernah masuk git.

**Yang perlu disiapkan tim.** Akun penyedia SMTP + domain/pengirim terverifikasi.

**Kriteria terima.** Akun baru (bukan anggota tim) menerima OTP di kotak masuk dan bisa mengganti password.

### F2. Unggah dokumen STR nakes
**Kebutuhan.**
- Saat mendaftar sebagai tenaga kesehatan, pengguna memilih berkas STR (PDF/JPG/PNG, maks. 5 MB).
- Berkas tersimpan privat; hanya pemilik dan admin yang bisa membukanya.
- Admin membuka dokumen asli (tautan sementara) sebelum menekan Verifikasi.
- Nakes yang belum mengunggah bisa mengunggah dari halaman "Menunggu verifikasi".

**Desain.** Bucket privat `str-documents`, jalur `<user_id>/str-<waktu>.<ext>`; kolom `profiles.str_document_path`; kebijakan Storage: unggah hanya ke folder sendiri, baca folder sendiri atau admin; admin membuka lewat *signed URL* 5 menit.

**Kriteria terima.** Nakes A tidak bisa membaca STR nakes B; admin bisa; pengguna anonim tidak bisa.

### F3. Foto makanan & foto anak tersimpan
**Kebutuhan.** Foto yang dipakai untuk mencatat makanan/pertumbuhan tersimpan dan bisa dilihat lagi oleh orang tua dan nakes yang memantau.

**Desain.** Bucket privat `photos`, jalur `<parent_id>/<child_id>/<food|growth>/<id>.<ext>` (maks. 8 MB, JPG/PNG/WEBP). Kolom `food_entries.photo_path` dan `measurements.photo_path`. Kebijakan: orang tua menulis/membaca folder sendiri; nakes terverifikasi & admin membaca.

**Kriteria terima.** Foto muncul kembali setelah aplikasi dimuat ulang; orang tua lain tidak bisa membukanya.

### F4. Mode rilis tanpa data demo
**Kebutuhan.** Build untuk pengguna sungguhan tidak menampilkan tombol akun demo, kode OTP contoh, rute login cepat `/demo/…`, maupun tombol "Coba tanpa foto (demo)".

**Desain.** `--dart-define=GROWELL_DEMO=false` (bawaan `true` untuk demo/kelas). Database produksi dibuat dengan `supabase db push` **tanpa** `--include-seed`. Mode lokal tanpa database selalu demo.

**Kriteria terima.** `flutter build web --dart-define=GROWELL_DEMO=false` tidak memuat tombol/rute demo.

---

## 4. Fase 2 — Kuis multiplayer antar-perangkat (F5)

**Masalah.** Kuis v0.5 sudah memiliki alur 2/4 pemain, tetapi pemain lain adalah bot, dan skor dikirim sendiri oleh aplikasi (bisa dipalsukan).

**Kebutuhan fungsional.**
1. Host (orang tua/remaja) membuat ruang 2 atau 4 pemain → mendapat kode 6 karakter.
2. Pemain lain bergabung dengan kode dari perangkat lain; lobi menampilkan pemain secara langsung.
3. Host menekan **Mulai Quiz** saat ruang penuh; semua pemain menerima soal yang sama pada waktu yang sama (ER-7.3).
4. Jawaban dinilai di server: benar = 500 + bonus kecepatan hingga 500 (ER-7.5); waktu dihitung dari jam server.
5. Setelah semua menjawab atau waktu habis, semua pemain melihat pembahasan dan papan skor yang sama.
6. Skor akhir semua pemain disimpan otomatis ke papan skor mingguan oleh server.
7. Pemain yang keluar tidak menghentikan permainan pemain lain.
8. Mode **Latihan dengan bot** tetap tersedia (tanpa internet / saat sendirian).

**Desain teknis.**
- Tabel: `quiz_questions` (kunci jawaban, tidak bisa dibaca klien), `quiz_rooms`, `quiz_room_players`, `quiz_answers` (hanya jawaban sendiri yang terbaca).
- Semua perubahan lewat fungsi RPC `SECURITY DEFINER`: `quiz_create_room`, `quiz_join_room`, `quiz_start`, `quiz_answer`, `quiz_tick`, `quiz_leave_room`.
- `quiz_tick` idempoten (dikunci `FOR UPDATE`): memindahkan fase *soal → pembahasan → soal berikutnya → selesai* bila waktunya tiba. Semua klien boleh memanggilnya; yang pertama menang.
- Klien mendengarkan perubahan `quiz_rooms` & `quiz_room_players` lewat Supabase Realtime, dengan polling cadangan 2 detik.
- Batasan yang diketahui: teks soal & kunci tetap ada di aplikasi (bank soal lokal), sehingga pemain yang membongkar aplikasi bisa mengetahui jawaban; **skor** tetap tidak bisa dipalsukan karena dinilai server.

**Kriteria terima.** Dua browser/perangkat dengan akun berbeda bisa bermain satu ruang sampai selesai; skor keduanya sama di kedua layar dan tercatat di papan skor mingguan.

---

## 5. Fase 3 — AI lewat NanoGPT (F6, F7)

**Penyedia.** NanoGPT (subscription tim), API kompatibel OpenAI:
`POST https://api.nano-gpt.com/api/subscription/v1/chat/completions`. Model bawaan `deepseek/deepseek-v4-flash-latest` (termasuk subscription, mendukung gambar & output JSON); bisa diganti lewat secret `NANOGPT_CHAT_MODEL` / `NANOGPT_VISION_MODEL`.

**Prinsip keamanan.**
- Kunci API **hanya** disimpan sebagai secret Edge Function (`NANOGPT_API_KEY`), tidak pernah di aplikasi atau git.
- Edge Function `ai` mewajibkan login; batas pemakaian per pengguna per hari (chat 40, foto 15) dicatat di tabel `ai_usage`.
- Data yang dikirim ke AI dibatasi: nama panggilan, usia (bulan), jenis kelamin, status gizi terakhir — tanpa email/NIK.
- Bila AI tidak tersedia (tanpa internet/kunci/kuota), aplikasi kembali ke jawaban berbasis aturan dan memberi tahu pengguna.

### F6. AI pendamping gizi
- Menjawab pertanyaan seputar MPASI, ASI, protein hewani, anak susah makan, pertumbuhan, gizi remaja, dengan bahasa Indonesia sederhana, ≤ 120 kata.
- Wajib menyarankan ke posyandu/puskesmas/dokter untuk tanda bahaya (demam tinggi, diare berdarah, berat turun, tidak mau makan berhari-hari) dan **tidak** memberi diagnosis/dosis obat.
- Riwayat percakapan (maks. 10 pesan terakhir) dikirim untuk konteks.

### F7. Deteksi gizi dari foto makanan
- Foto (dikompres ≤ 1024 px) dikirim ke model vision bersama daftar ID makanan GroWell.
- Model mengembalikan JSON `{items:[{food_id, grams, confidence}], note}`; server memvalidasi ID dan membatasi porsi 5–500 g.
- Orang tua **wajib** memeriksa/mengoreksi hasil sebelum disimpan; foto ikut tersimpan (F3).

### F10. Estimasi tinggi/berat dari foto anak — keputusan
Tidak dijadikan fitur ukur: akurasi dari foto biasa tidak memadai untuk keputusan stunting. Foto tetap bisa disimpan sebagai catatan, dan pengukuran harus diinput manual dari hasil timbang/ukur posyandu.

---

## 6. Fase 4 — Push notification & Android (F8, F9)

### F8. Push notification (FCM)
**Pemicu notifikasi.**
| Kejadian | Penerima |
|---|---|
| Pesan konsultasi baru | Lawan bicara |
| Catatan konsultasi / jadwal kontrol baru | Orang tua |
| Akun nakes diverifikasi admin | Nakes tersebut |
| Pengingat harian: kontrol besok, belum ukur > 30 hari | Orang tua (dijalankan cron) |

**Desain.** Tabel `push_tokens` (token per perangkat, RLS milik sendiri). Edge Function `notify` (dipanggil aplikasi setelah aksi; memeriksa bahwa pemanggil memang pengirimnya) dan `reminders` (dipanggil Supabase Cron, dilindungi `CRON_SECRET`). Pengiriman memakai FCM HTTP v1 dengan *service account*. Fitur otomatis nonaktif bila konfigurasi Firebase belum diisi — aplikasi tetap berjalan.

**Yang perlu disiapkan tim.** Proyek Firebase (gratis): aplikasi Web + Android, *Web Push certificate (VAPID key)*, dan *service account JSON* (disimpan sebagai secret, bukan di git).

### F9. Aplikasi Android
- Build APK yang terhubung ke Supabase cloud (`flutter build apk --dart-define-from-file=supabase_cloud.json`).
- Izin: internet, kamera/galeri, notifikasi (Android 13+).
- Batasan v0.6: unduh CSV/PDF di Android memakai bagikan/clipboard; uji di perangkat fisik.

---

## 7. Fase berikutnya (belum dikerjakan)

- **F11 Panggilan suara/video**: LiveKit/Agora/Daily; token dibuat Edge Function; catat durasi panggilan. Perlu biaya layanan.
- **F12 Reels & komentar**: hapus konten contoh, tabel `reel_comments`, hitungan suka dari `reel_likes`, thumbnail otomatis.
- **F13 Konten**: tinjauan nakes untuk artikel, aturan status, dan ≥ 100 soal kuis; pindahkan bank soal ke database agar bisa diperbarui tanpa rilis aplikasi.
- **F14 Produksi**: Supabase Pro (tidak dijeda, backup harian) atau keep-alive mingguan; domain + hosting web (mis. Vercel/Netlify/Cloudflare Pages); monitoring error (Sentry); kebijakan privasi & persetujuan data anak.

## 8. Risiko & mitigasi

| Risiko | Mitigasi |
|---|---|
| Saran AI keliru secara medis | Prompt sistem ketat, penolakan diagnosis, penafian di layar, rujukan ke nakes, konten ditinjau |
| Biaya/kuota AI habis | Batas harian per pengguna, model subscription, fallback berbasis aturan |
| Data anak bocor | RLS di semua tabel & bucket privat, signed URL berumur pendek, minimisasi data ke AI |
| Proyek Supabase dijeda | Paket Pro atau aktivitas rutin; dokumentasi cara *Restore* |
| Kecurangan kuis | Penilaian & waktu di server; jawaban orang lain tidak terbaca sebelum pembahasan |

## 9. Rahasia & konfigurasi (tidak pernah di-commit)

| Nama | Tempat | Untuk |
|---|---|---|
| `NANOGPT_API_KEY` | `supabase/functions/.env` (lokal), `supabase secrets set` (cloud) | F6, F7 |
| `FIREBASE_SERVICE_ACCOUNT` | secret Edge Function | F8 |
| `CRON_SECRET` | secret Edge Function + header cron | F8 pengingat |
| `SMTP_PASS` | Dashboard Supabase / env | F1 |
| Firebase web config + VAPID | `firebase.json` (lokal, gitignored) → dart-define | F8 |
| Password DB | `supabase/.cloud-secrets` | admin |
