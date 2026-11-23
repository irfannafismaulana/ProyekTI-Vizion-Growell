# GroWell

**GroWell** adalah aplikasi pendamping tumbuh kembang **baduta (anak usia 0–24 bulan)** untuk mendukung pencegahan stunting. Aplikasi menghubungkan tiga kelompok pengguna, yaitu **orang tua**, **remaja**, dan **tenaga kesehatan (nakes)**, ditambah **admin** yang memverifikasi nakes.

Versi ini adalah **v0.6**:
- Tampilan mengikuti desain Figma.
- Dibuat dengan **Flutter** (web + Android).
- Data disimpan di **Supabase (PostgreSQL)**, baik di laptop sendiri lewat Docker maupun **online** (Supabase cloud).

Daftar fitur yang masih simulasi dan rencana menjadikannya live ada di **[PRD.md](PRD.md)**.

**Baru di v0.6** (fitur live, lihat PRD fase 1–4):
- **Kuis antar-perangkat sungguhan**: host membuat ruang 2/4 pemain, teman bergabung dengan kode dari HP/laptop lain. Soal, waktu, dan nilai diatur **server** (Supabase Realtime + fungsi database), sehingga skor tidak bisa dipalsukan. Mode **Latihan dengan bot** tetap ada.
- **AI lewat NanoGPT**: *Asisten Ahli Gizi* menjawab dengan model bahasa, dan **foto makanan** dikenali model vision lalu dicocokkan ke tabel pangan. Kunci API hanya ada di server (Edge Function `ai`), dengan kuota harian per pengguna.
- **Dokumen STR asli**: nakes mengunggah PDF/JPG STR saat daftar; admin membuka dokumen aslinya sebelum verifikasi.
- **Foto tersimpan**: foto makanan & foto anak disimpan di Storage privat.
- **Push notification (Firebase)**: pesan konsultasi, catatan, jadwal kontrol, verifikasi STR, dan pengingat harian. Aktif setelah konfigurasi Firebase diisi.
- **Mode rilis** (`-Release` / `GROWELL_DEMO=false`): tanpa tombol akun demo dan fitur simulasi.
- **Build Android (APK)**.

**Baru di v0.5** (mengikuti desain di folder `update svg`):
- **Kuis multiplayer bertema biru**: pilih mode **2 pemain** (duel) atau **4 pemain** (battle), lobi dengan status "Siap", kartu skor tiap pemain saat bermain, dan layar **Hasil Pertandingan** (pemenang + peringkat).
- **Catat Pertumbuhan Anak** berupa dialog: tanggal, tinggi (40–120 cm), berat (1–30 kg), tombol Simpan aktif bila isian valid, lalu ringkasan "Data Berhasil Disimpan!" (status, perubahan dari pengukuran sebelumnya, *Ubah Data*, *Lihat Detail*).
- Perbaikan: layar error merah setelah menekan **Selesai/Kembali** di akhir kuis.

**Baru di v0.4:**
- Tombol **+** orang tua sekarang untuk **input manual**: makanan anak (pilih menu + porsi) atau tinggi & berat badan.
- Tenaga kesehatan bisa **mengunggah video edukasi singkat** (maks. 3 menit, 50 MB) yang tampil di tab **Reels** orang tua/remaja.
- **Tampilan kuis baru**: hitung mundur melingkar, jawaban berwarna, streak 🔥, papan skor beranimasi, podium, dan konfeti.
- Bisa dijalankan dengan **database online** (`demo.ps1 -Cloud`).

---

## Daftar isi
1. [Fitur utama](#fitur-utama)
2. [Teknologi](#teknologi)
3. [Prasyarat](#prasyarat)
4. [Cara menjalankan](#cara-menjalankan)
5. [Akun demo](#akun-demo)
6. [Alamat lokal](#alamat-lokal)
7. [Tampilan di layar besar](#tampilan-di-layar-besar)
8. [Pengujian](#pengujian)
9. [Struktur proyek](#struktur-proyek)
10. [Masalah umum](#masalah-umum)
11. [Pindah ke Supabase cloud](#pindah-ke-supabase-cloud)
12. [Belum termasuk](#belum-termasuk)

---

## Fitur utama

### Orang tua
- **Profil anak**: satu akun bisa mencatat beberapa anak.
- **Pemantauan pertumbuhan**:
  - Mencatat berat dan panjang/tinggi badan.
  - Menghitung z-score berdasarkan standar WHO dan menampilkan status Normal / Waspada / Kurang / Lebih.
  - Menampilkan grafik pertumbuhan dan riwayat pengukuran.
- **Tombol + (input manual)**:
  - *Makanan Anak*: pilih tanggal & waktu makan, ketuk menu (atau cari), atur porsi dalam gram; total kalori/protein/karbo/lemak langsung terhitung.
  - *Tinggi & Berat Badan*: isi hasil timbang & ukur, dengan pengukuran terakhir sebagai acuan.
- **Foto makanan (AI)**: foto dikenali model vision (NanoGPT) → daftar makanan + porsi yang bisa dikoreksi → disimpan beserta fotonya.
- **Foto anak**: foto disimpan sebagai catatan; angka tinggi/berat **bukan** hasil ukur (tidak akurat dari foto biasa) dan harus diganti hasil timbang posyandu.
- **Catatan makan dan gizi**:
  - Mencatat makan pagi, siang, malam, dan selingan.
  - Merangkum asupan energi dan zat gizi per hari dan per minggu.
- **Resep MPASI** sesuai usia anak.
- **Reels edukasi**: video dari nakes (diputar sungguhan) dan konten bawaan, bisa disukai dan disimpan.
- **Konsultasi dengan nakes**:
  - Chat secara langsung (realtime).
  - Catatan konsultasi yang bisa diunduh sebagai PDF.
  - Jadwal kontrol.
- **Asisten Ahli Gizi (AI)**: tanya-jawab seputar gizi dan tumbuh kembang memakai model bahasa (NanoGPT), memakai usia & status anak. Bila AI tidak tersedia, kembali ke jawaban berbasis aturan.
- **Push notification**: balasan konsultasi, catatan, jadwal kontrol, pengingat kontrol besok & pengingat menimbang.

### Remaja
- Materi edukasi gizi dan pencegahan stunting, termasuk Reels video dari nakes.
- **Kuis antar-perangkat** 2/4 pemain dengan kode ruang, nilai dihitung server, lencana, dan papan peringkat mingguan.

### Tenaga kesehatan (nakes)
- Dashboard baduta binaan per posyandu beserta status pertumbuhannya.
- Membalas chat, menulis catatan konsultasi, dan membuat jadwal kontrol.
- **Tab Video**: unggah video edukasi singkat (MP4/WebM/MOV, maks. 3 menit & 50 MB), pilih sasaran (orang tua/remaja), pratinjau, dan hapus.
- Akun baru mengunggah dokumen STR dan harus diverifikasi admin sebelum bisa dipakai.

### Admin
- Memverifikasi pendaftaran nakes: membuka dokumen STR asli (tautan sementara 5 menit) lalu menekan Verifikasi.

### Umum
- Daftar akun dan masuk.
- Lupa password dengan kode OTP lewat email.
- Hak akses per peran dijaga langsung di database (Row Level Security).

---

## Teknologi

| Bagian | Teknologi |
| --- | --- |
| Aplikasi | Flutter 3.41 (Dart 3.11), target **web/Chrome** dan **Android** |
| State dan navigasi | Riverpod 3, go_router |
| Grafik, PDF, video | fl_chart, pdf, video_player |
| Backend | Supabase: PostgreSQL 17, Auth, Realtime, Storage (video, foto, STR), Edge Functions (Deno), Studio |
| AI | NanoGPT (API kompatibel OpenAI), model bawaan `deepseek/deepseek-v4-flash-latest` |
| Push notification | Firebase Cloud Messaging (HTTP v1) |
| Infrastruktur lokal | Supabase CLI 2.122 di atas Docker Desktop (WSL2 di Windows) |

---

## Prasyarat

| Perangkat lunak | Kegunaan | Unduh |
| --- | --- | --- |
| **Git** | Mengambil kode | https://git-scm.com |
| **Flutter SDK 3.41+** | Menjalankan aplikasi | https://docs.flutter.dev/get-started/install |
| **Google Chrome** | Tempat aplikasi tampil | https://www.google.com/chrome |
| **Node.js LTS (20+)** | Menjalankan Supabase CLI lewat `npx` | https://nodejs.org |
| **Docker Desktop** | Menjalankan database Supabase | https://www.docker.com/products/docker-desktop |

Catatan:
- **Windows:** saat memasang Docker Desktop, pilih **WSL 2 backend**. Bila diminta, jalankan `wsl --install` di PowerShell sebagai Administrator, lalu restart.
- **Docker dan Node.js tidak wajib** bila hanya ingin melihat tampilan (lihat [Mode cepat](#mode-a--mode-cepat-tanpa-database)).

Cek instalasi:
```bash
flutter doctor        # baris "Chrome" harus bercentang
node --version
docker info           # harus berjalan tanpa error (Docker Desktop sudah dibuka)
```

---

## Cara menjalankan

### 1. Ambil kode dan pasang dependensi
```bash
git clone https://github.com/irfannafismaulana/ProyekTI-Vizion-Growell.git
cd ProyekTI-Vizion-Growell
flutter pub get
```

### Mode A — Mode cepat (tanpa database)

Pilih mode ini untuk mencoba tampilan saja. Data contoh disimpan di memori dan **hilang saat halaman dimuat ulang**.
```bash
flutter run -d chrome
```

### Mode B — Dengan database Supabase lokal (disarankan untuk demo)

Data tersimpan permanen, chat antar-akun berjalan realtime, dan email OTP bisa dicoba.

**Windows (sekali jalan):**
```powershell
# Buka Docker Desktop terlebih dahulu dan tunggu sampai statusnya "running"
powershell -ExecutionPolicy Bypass -File demo.ps1          # pakai data yang sudah ada
powershell -ExecutionPolicy Bypass -File demo.ps1 -Reset   # kembalikan ke data contoh awal
```

**Manual (Windows, macOS, Linux):**
```bash
npx supabase start          # pertama kali: mengunduh image Docker ±2–3 GB, butuh beberapa menit
flutter run -d chrome --web-port 8093 --dart-define-from-file=supabase_local.json
```

Aplikasi terbuka di Chrome pada **http://localhost:8093**. Mode yang sedang aktif (lokal/Supabase) tertulis di halaman login, di bawah tombol akun demo.

Perintah lain:
```bash
npx supabase db reset       # hapus semua data, buat ulang skema + data contoh
npx supabase stop           # matikan database (data tetap tersimpan)
```

> Port 8093 wajib dipakai pada Mode B karena alamat ini terdaftar di konfigurasi Auth (`supabase/config.toml`).

Bila memperbarui dari versi lama, `demo.ps1` otomatis menerapkan migrasi baru (`npx supabase migration up --local`) tanpa menghapus data.

### Mode C — Dengan database Supabase online (tanpa Docker)

Semua anggota tim memakai **database yang sama** lewat internet; cukup Flutter + Chrome.

1. Pastikan file `supabase_cloud.json` ada (isi URL + *publishable key* proyek Supabase; contoh format di `supabase_cloud.example.json`).
2. Jalankan:
   ```powershell
   powershell -ExecutionPolicy Bypass -File demo.ps1 -Cloud
   # atau manual:
   flutter run -d chrome --web-port 8093 --dart-define-from-file=supabase_cloud.json
   ```

Halaman login menampilkan alamat database yang sedang dipakai (`…supabase.co` berarti online).

Proyek online GroWell: `growell` (ref `zreumtxexbpufxdfdmpw`, region Singapura), sudah berisi skema, bucket video, dan data contoh yang sama dengan lokal (akun demo, password `demo123`).

Perbedaan dengan lokal:
- **Proyek dijeda** bila 7 hari tidak dipakai. Buka https://supabase.com/dashboard → proyek `growell` → **Restore project** (± 2–5 menit) sebelum demo. Proyek gratis yang dijeda > 90 hari tidak bisa dipulihkan dari dashboard.
- **Lupa password** online butuh SMTP sendiri (PRD F1): paket gratis tanpa SMTP hanya mengirim email ke anggota tim.
- Fitur v0.6 (kuis live, AI, STR, foto, push) perlu migrasi + Edge Function dikirim ke cloud dulu — lihat [Pindah ke Supabase cloud](#pindah-ke-supabase-cloud).
- Tanggal data contoh mengikuti hari saat data dimasukkan (3 Nov 2026), jadi lama-lama terlihat "lampau".

### Mode rilis (tanpa fitur demo)
Tambahkan `-Release` (atau `--dart-define=GROWELL_DEMO=false` pada `flutter run/build`): tombol akun demo, kode OTP contoh, rute `/demo/…`, dan tombol "foto contoh / tanpa foto (demo)" disembunyikan. Database produksi dibuat **tanpa** `--include-seed`.

### AI (NanoGPT) — opsional
1. Salin `supabase/functions/.env.example` menjadi `supabase/functions/.env` lalu isi `NANOGPT_API_KEY` (dari https://nano-gpt.com/api). File ini diabaikan git.
2. Lokal: jalankan ulang `demo.ps1` (Supabase lokal membaca `.env` saat dinyalakan; bila sudah berjalan, `npx supabase@2.122.1 stop` lalu jalankan lagi).
3. Cloud: `npx supabase@2.122.1 secrets set --env-file supabase/functions/.env` lalu `npx supabase@2.122.1 functions deploy`.

Tanpa kunci, asisten & foto makanan tetap berjalan dengan jawaban berbasis aturan/simulasi dan menampilkan pemberitahuan.

### Push notification (Firebase) — opsional
1. Buat proyek di https://console.firebase.google.com (gratis) → tambahkan aplikasi **Web** dan **Android** (package `id.growell.growell`).
2. Project settings → Cloud Messaging → **Web Push certificates** → buat *key pair* (VAPID).
3. Salin `firebase_config.example.json` menjadi `firebase_config.json` dan isi nilainya (apiKey, projectId, senderId, appId web/android, VAPID). File ini diabaikan git; `demo.ps1` memakainya otomatis.
4. Project settings → Service accounts → **Generate new private key** → isi JSON itu (satu baris) ke `FIREBASE_SERVICE_ACCOUNT` di `supabase/functions/.env`. **Jangan di-commit.**
5. Pengingat harian (cloud): isi `CRON_SECRET` (string acak) di `.env`, deploy, lalu Dashboard Supabase → Integrations → **Cron** → job harian `0 0 * * *` (07.00 WIB) *HTTP request* POST ke `https://<ref>.supabase.co/functions/v1/reminders` dengan header `x-cron-secret: <CRON_SECRET>`.

### Build Android (APK)
Butuh Android SDK + JDK 17 (`flutter doctor` baris *Android toolchain* bercentang).
```powershell
flutter build apk --release --dart-define-from-file=supabase_cloud.json --dart-define=GROWELL_DEMO=false
# hasil: build\app\outputs\flutter-apk\app-release.apk
```
APK memakai database **online** (HP tidak bisa menjangkau `127.0.0.1` laptop). Tambahkan `--dart-define-from-file=firebase_config.json` untuk push notification. Build ini masih ditandatangani kunci *debug*; untuk Play Store buat *keystore* rilis sendiri.

---

## Akun demo

Password semua akun: **`demo123`**.

| Peran | Email | Isi data |
| --- | --- | --- |
| Orang tua | `rani@demo.id` | Abiyu (6 bln, perlu perhatian) & Alya (9 bln, normal), catatan makan, 2 percakapan, catatan konsultasi, jadwal kontrol |
| Orang tua | `fitri@demo.id` | Rafa, Kenzo, Citra, Sekar |
| Orang tua | `wulan@demo.id` | Nadia, Bayu, Dimas |
| Remaja | `dina@demo.id` | Skor kuis minggu ini |
| Nakes | `sarah@demo.id` | Dokter Abiyu (chat, catatan, jadwal) |
| Nakes | `irfan@demo.id` | Chat dengan Rani |
| Nakes | `siti@demo.id`, `budi@demo.id`, `rina@demo.id` | Sudah terverifikasi, belum ada percakapan |
| Nakes (belum terverifikasi) | `candra@demo.id` | Menunggu verifikasi STR |
| Admin | `admin@demo.id` | Verifikasi STR nakes |

Cara masuk:
- Isi email dan password di halaman login, atau klik tombol akun demo.
- Untuk mencoba chat realtime, buka dua jendela Chrome: satu masuk sebagai `rani@demo.id`, satu lagi sebagai `sarah@demo.id`.

Mencoba fitur akun:
- **Akun baru** bisa dibuat lewat halaman *Daftar*. Di lokal tidak perlu konfirmasi email.
- **Lupa password**: kode OTP dikirim ke kotak masuk lokal Mailpit (http://127.0.0.1:54324). Pada Mode A, kodenya `123456`.

Tanggal pada data contoh menyesuaikan tanggal hari ini (WIB), jadi grafik dan jadwal selalu terlihat baru.

---

## Alamat lokal

Alamat berikut hanya berlaku pada Mode B.

| Layanan | Alamat | Kegunaan |
| --- | --- | --- |
| Aplikasi | http://localhost:8093 | Demo |
| Supabase Studio | http://127.0.0.1:54323 | Melihat/mengedit tabel, SQL editor, daftar pengguna |
| Mailpit | http://127.0.0.1:54324 | Kotak masuk email lokal (kode OTP) |
| API | http://127.0.0.1:54321 | Dipakai aplikasi |
| Edge Functions | http://127.0.0.1:54321/functions/v1/ai, `/notify`, `/reminders` | AI & push (dipanggil aplikasi) |
| PostgreSQL | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` | Koneksi langsung (DBeaver/pgAdmin) |

Kunci di `supabase_local.json` adalah kunci demo bawaan Supabase CLI untuk lokal, **bukan rahasia**.

---

## Tampilan di layar besar

Aplikasi didesain untuk layar HP (lebar 440 px).
- **Monitor vertikal** (misalnya 1200×1920): seluruh UI otomatis diperbesar ±2,4× agar memenuhi layar.
- **HP dan laptop**: tampilan tidak berubah.

Skala bisa diatur manual lewat parameter `zoom`. Letakkan parameter ini **sebelum** tanda `#` di URL:

| URL | Hasil |
| --- | --- |
| `http://localhost:8093/` | Otomatis (disarankan) |
| `http://localhost:8093/?zoom=150` | Diperbesar 150% (nilai 50–400) |
| `http://localhost:8093/?zoom=100` | Ukuran asli |

Untuk pameran, tekan **F11** di Chrome agar tampil layar penuh.

---

## Pengujian

```bash
flutter analyze              # analisis kode
flutter test                 # 120 uji aplikasi (berjalan pada mode lokal, tanpa Docker)
npx supabase test db         # 45 uji hak akses RLS + kuis live di database (Supabase lokal harus berjalan)
```

---

## Struktur proyek

```
lib/
├─ main.dart              Titik masuk; menyambungkan ke Supabase bila dart-define tersedia
├─ app.dart               Routing (go_router), tema, bingkai tampilan
├─ config.dart            Saklar build demo/rilis (GROWELL_DEMO)
├─ models.dart            Model data
├─ core/                  Logika murni: z-score WHO, status gizi, aturan kuis, perhitungan nutrisi
├─ data/                  Data statis: tabel WHO, bahan makanan, resep, bank soal kuis, konten edukasi, data contoh
├─ state/
│  ├─ providers.dart      State aplikasi (Riverpod); perubahan langsung tampil lalu ditulis ke database
│  ├─ backend.dart        Akses Supabase: Auth, muat data, tulis data, Storage, Realtime
│  ├─ quiz_engine.dart    Jalannya kuis (live lewat server, atau lawan bot)
│  ├─ quiz_live.dart      RPC & Realtime kuis antar-perangkat
│  ├─ ai.dart             Klien Edge Function AI (chat & foto makanan)
│  └─ push.dart           Pendaftaran push notification (Firebase)
├─ ui/                    Halaman per fitur (auth, beranda, pertumbuhan, gizi, edukasi/Reels, video nakes, kuis, konsultasi, nakes, admin, asisten)
└─ util/                  Unduh berkas (PDF) di web, pemilih berkas (STR)
assets/                   Logo dan gambar
web/firebase-messaging-sw.js  Service worker push notification web
supabase/
├─ config.toml            Konfigurasi Supabase (lokal; bagian Auth juga dipakai untuk cloud)
├─ migrations/            Skema: tabel, view, trigger validasi, fungsi bantu, kebijakan RLS per peran, Realtime,
│                         bucket Storage (`edu-videos`, `photos`, `str-documents`), kuis live (RPC `quiz_*`)
├─ functions/             Edge Functions (Deno): ai (NanoGPT), notify & reminders (FCM); .env.example
├─ seed.sql               Data contoh (11 akun demo, 9 anak, pengukuran, catatan makan, chat)
├─ templates/             Email OTP reset password (Bahasa Indonesia)
└─ tests/database/        Uji RLS (pgTAP)
test/                     Uji Flutter (unit + widget)
supabase_local.json       URL + kunci publik Supabase lokal
supabase_cloud.json       URL + kunci publik Supabase online (contoh: supabase_cloud.example.json)
firebase_config.json      Konfigurasi Firebase (opsional, tidak di-commit; contoh: firebase_config.example.json)
demo.ps1                  Skrip demo sekali jalan (Windows): lokal, -Reset, -Cloud, -Release
PRD.md                    Fitur yang masih simulasi & rencana menjadikannya live
```

---

## Masalah umum

| Gejala | Solusi |
| --- | --- |
| `docker info` error / "Docker Desktop belum berjalan" | Buka Docker Desktop dan tunggu sampai *running*. Di Windows, pastikan WSL 2 terpasang (`wsl --status`). |
| `npx supabase start` gagal karena port terpakai | Proyek Supabase lain mungkin masih berjalan. Jalankan `npx supabase stop --all`, lalu ulangi. |
| PowerShell menolak menjalankan `demo.ps1` | Jalankan dengan `powershell -ExecutionPolicy Bypass -File demo.ps1`. |
| Login gagal di Mode B | Pastikan Supabase berjalan (`npx supabase status`). Bila data rusak, jalankan `npx supabase db reset`. |
| `flutter run` tidak menemukan Chrome | Jalankan `flutter doctor` dan pasang Chrome. Atau set variabel `CHROME_EXECUTABLE` ke lokasi Chrome. |
| Error versi paket saat `flutter pub get` | Pastikan Flutter ≥ 3.41 (`flutter upgrade`). |
| Video nakes tidak bisa diputar / durasi tidak terbaca | Gunakan MP4 (H.264). Video HEVC dari sebagian iPhone belum didukung Chrome; ubah ke H.264 dulu. |
| Unggah video ditolak | Pastikan akun nakes sudah terverifikasi, durasi ≤ 3 menit, dan ukuran ≤ 50 MB. |
| Asisten/foto makanan menampilkan "AI belum dikonfigurasi" | Isi `NANOGPT_API_KEY` di `supabase/functions/.env`, lalu nyalakan ulang Supabase (lokal) atau `secrets set` + `functions deploy` (cloud). |
| "Batas harian AI tercapai" | Kuota per pengguna: 40 chat & 15 foto per hari (ubah lewat `AI_CHAT_DAILY_LIMIT` / `AI_PHOTO_DAILY_LIMIT`). |
| Gabung ruang kuis: "Ruang … tidak ditemukan" | Pastikan kedua perangkat memakai database yang sama (keduanya `-Cloud`, atau keduanya lokal di laptop yang sama) dan kuis belum dimulai. |
| Tidak ada push notification | Isi `firebase_config.json` & `FIREBASE_SERVICE_ACCOUNT`, izinkan notifikasi di browser/HP, lalu masuk ulang. |

---

## Pindah ke Supabase cloud

Langkah membuat/memperbarui proyek online (sekali saja, oleh pemilik akun Supabase):

1. Buat proyek di https://supabase.com (region Singapura). Catat *Project ref*, URL, dan *publishable key*.
2. Kirim skema ke cloud:
   ```bash
   npx supabase login
   npx supabase link --project-ref <ref>
   npx supabase db push --include-seed  # skema + RLS + bucket video + data contoh
   npx supabase config push             # pengaturan Auth (tanpa konfirmasi email, template OTP)
   ```
   Perubahan skema berikutnya cukup `npx supabase db push` (hanya migrasi baru yang dikirim).
   Edge Function v0.6: `npx supabase secrets set --env-file supabase/functions/.env` lalu `npx supabase functions deploy`.
3. Buat `supabase_cloud.json` berisi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` milik proyek cloud. *Publishable key* memang untuk aplikasi (aman dibagikan, dilindungi RLS). **Jangan pernah commit** *secret key* / *service role key* / password database.
4. Jalankan `demo.ps1 -Cloud`.

Catatan paket gratis Supabase: database 500 MB, Storage 1 GB (± 20 video 50 MB), proyek dijeda otomatis bila tidak dipakai 7 hari (aktifkan lagi dari dashboard), dan email bawaan hanya untuk alamat anggota tim dengan batas beberapa email per jam — untuk OTP ke pengguna sungguhan, pasang SMTP sendiri.

---

## Belum termasuk

Rincian dan rencananya ada di [PRD.md](PRD.md) (fase 5–6):
- Panggilan suara/video konsultasi masih simulasi (perlu layanan WebRTC).
- Reels bawaan masih konten contoh; video nakes belum punya thumbnail otomatis, komentar, dan jumlah suka dari semua pengguna.
- Estimasi tinggi/berat dari foto anak sengaja tidak dijadikan fitur ukur (tidak akurat secara medis).
- Konten (artikel, aturan status, bank soal 40 soal) masih draf dan perlu ditinjau nakes.
- Build iOS belum dicoba; APK masih ditandatangani kunci debug.
