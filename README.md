# GroWell

**GroWell** adalah aplikasi pendamping tumbuh kembang **baduta (anak usia 0–24 bulan)** untuk mendukung pencegahan stunting. Aplikasi menghubungkan tiga kelompok pengguna, yaitu **orang tua**, **remaja**, dan **tenaga kesehatan (nakes)**, ditambah **admin** yang memverifikasi nakes.

Versi ini adalah **prototype v0.5**:
- Tampilan mengikuti desain Figma.
- Dibuat dengan **Flutter (web)**.
- Data disimpan di **Supabase (PostgreSQL)**, baik di laptop sendiri lewat Docker maupun **online** (Supabase cloud).

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
- **Estimasi dari foto** (simulasi AI): foto makanan dan foto anak tetap tersedia di baris bawah lembar tombol +.
- **Catatan makan dan gizi**:
  - Mencatat makan pagi, siang, malam, dan selingan.
  - Merangkum asupan energi dan zat gizi per hari dan per minggu.
- **Resep MPASI** sesuai usia anak.
- **Reels edukasi**: video dari nakes (diputar sungguhan) dan konten bawaan, bisa disukai dan disimpan.
- **Konsultasi dengan nakes**:
  - Chat secara langsung (realtime).
  - Catatan konsultasi yang bisa diunduh sebagai PDF.
  - Jadwal kontrol.
- **Asisten**: tanya-jawab seputar gizi dan tumbuh kembang (berbasis aturan).

### Remaja
- Materi edukasi gizi dan pencegahan stunting, termasuk Reels video dari nakes.
- **Kuis** dengan skor, streak, lencana, podium, dan papan peringkat mingguan.

### Tenaga kesehatan (nakes)
- Dashboard baduta binaan per posyandu beserta status pertumbuhannya.
- Membalas chat, menulis catatan konsultasi, dan membuat jadwal kontrol.
- **Tab Video**: unggah video edukasi singkat (MP4/WebM/MOV, maks. 3 menit & 50 MB), pilih sasaran (orang tua/remaja), pratinjau, dan hapus.
- Akun baru harus diverifikasi STR oleh admin sebelum bisa dipakai.

### Admin
- Memverifikasi pendaftaran nakes (STR).

### Umum
- Daftar akun dan masuk.
- Lupa password dengan kode OTP lewat email.
- Hak akses per peran dijaga langsung di database (Row Level Security).

---

## Teknologi

| Bagian | Teknologi |
| --- | --- |
| Aplikasi | Flutter 3.41 (Dart 3.11), target **web/Chrome** |
| State dan navigasi | Riverpod 3, go_router |
| Grafik, PDF, video | fl_chart, pdf, video_player |
| Backend | Supabase: PostgreSQL 17, Auth, Realtime, Storage (video), Studio |
| Infrastruktur lokal | Supabase CLI di atas Docker Desktop (WSL2 di Windows) |

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
- **Proyek dijeda** bila 7 hari tidak dipakai. Buka dashboard Supabase → proyek `growell` → **Resume project** (± beberapa menit) sebelum demo.
- **Lupa password** belum bisa dipakai online: paket gratis tanpa SMTP sendiri hanya mengirim email ke anggota tim dan tidak mengizinkan template email berisi kode OTP.
- Tanggal data contoh mengikuti hari saat data dimasukkan (3 Nov 2026), jadi lama-lama terlihat "lampau".

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
flutter test                 # 112 uji aplikasi (berjalan pada mode lokal, tanpa Docker)
npx supabase test db         # 26 uji hak akses RLS di database (Supabase lokal harus berjalan)
```

---

## Struktur proyek

```
lib/
├─ main.dart              Titik masuk; menyambungkan ke Supabase bila dart-define tersedia
├─ app.dart               Routing (go_router), tema, bingkai tampilan
├─ models.dart            Model data
├─ core/                  Logika murni: z-score WHO, status gizi, aturan kuis, perhitungan nutrisi
├─ data/                  Data statis: tabel WHO, bahan makanan, resep, bank soal kuis, konten edukasi, data contoh
├─ state/
│  ├─ providers.dart      State aplikasi (Riverpod); perubahan langsung tampil lalu ditulis ke database
│  ├─ backend.dart        Akses Supabase: Auth, muat data, tulis data, Realtime
│  └─ quiz_engine.dart    Jalannya kuis
├─ ui/                    Halaman per fitur (auth, beranda, pertumbuhan, gizi, edukasi/Reels, video nakes, kuis, konsultasi, nakes, admin, asisten)
└─ util/                  Unduh berkas (PDF) di web
assets/                   Logo dan gambar
supabase/
├─ config.toml            Konfigurasi Supabase (lokal; bagian Auth juga dipakai untuk cloud)
├─ migrations/            Skema: 14 tabel, 1 view, trigger validasi, fungsi bantu, kebijakan RLS per peran, Realtime,
│                         bucket Storage `edu-videos` (video nakes)
├─ seed.sql               Data contoh (11 akun demo, 9 anak, pengukuran, catatan makan, chat)
├─ templates/             Email OTP reset password (Bahasa Indonesia)
└─ tests/database/        Uji RLS (pgTAP)
test/                     Uji Flutter (unit + widget)
supabase_local.json       URL + kunci publik Supabase lokal
supabase_cloud.json       URL + kunci publik Supabase online (contoh: supabase_cloud.example.json)
demo.ps1                  Skrip demo sekali jalan (Windows): lokal, -Reset, atau -Cloud
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
3. Buat `supabase_cloud.json` berisi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` milik proyek cloud. *Publishable key* memang untuk aplikasi (aman dibagikan, dilindungi RLS). **Jangan pernah commit** *secret key* / *service role key* / password database.
4. Jalankan `demo.ps1 -Cloud`.

Catatan paket gratis Supabase: database 500 MB, Storage 1 GB (± 20 video 50 MB), proyek dijeda otomatis bila tidak dipakai 7 hari (aktifkan lagi dari dashboard), dan email bawaan hanya untuk alamat anggota tim dengan batas beberapa email per jam — untuk OTP ke pengguna sungguhan, pasang SMTP sendiri.

---

## Belum termasuk

- Kuis antar-perangkat masih melawan bot; skor dan lencana sudah tersimpan di database.
- Foto makanan/anak belum diunggah ke Supabase Storage (video nakes sudah).
- Video nakes belum punya thumbnail otomatis, komentar, dan jumlah suka dari semua pengguna.
- Estimasi pertumbuhan dari foto masih simulasi, belum memakai model AI sungguhan.
- Push notification (FCM).
