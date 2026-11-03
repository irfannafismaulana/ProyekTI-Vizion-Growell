# Test Case — GroWell

Dokumen ini berisi test case berdasarkan skenario penggunaan nyata aplikasi GroWell. Acuan kebutuhan: **SRS Vizion 23-002 GroWell** (kode ER pada kolom Fitur merujuk ke SRS tersebut).

## Informasi Pengujian

| Item | Keterangan |
|---|---|
| Penguji | Azka Dhaffinanda Rahman |
| Tanggal pengujian | 28 November 2026 - 3 November 2026 |
| Versi aplikasi / build | 1.0 |
| Perangkat & OS | PC Windows|
| Browser (jika web) | Chrome |
| Jaringan | Local |

## Petunjuk Pengisian

- Kolom **Hasil Aktual** dan **Status** diisi **setelah** pengujian dijalankan, bukan sebelumnya.
- Untuk test case yang memiliki batas waktu, tulis angka yang terukur (contoh: `tampil 2,1 detik`), bukan hanya "sesuai".
- Status:
  - **PASS** — hasil aktual sesuai hasil yang diharapkan
  - **FAIL** — hasil aktual tidak sesuai; catat detailnya di bagian *Catatan Temuan*
  - **N/A** — tidak dapat diuji (fitur belum tersedia, data/perangkat tidak ada); tulis alasannya di Hasil Aktual

## Persiapan Data Uji

| Kebutuhan | Keterangan |
|---|---|
| Akun orang tua | 1 akun terdaftar dengan minimal 1 profil anak usia 12 bulan |
| Akun remaja | 1 akun terdaftar |
| Akun nakes terverifikasi | 1 akun dokter/bidan dengan STR sudah diverifikasi |
| Akun nakes belum terverifikasi | 1 akun nakes dengan STR belum diverifikasi |
| Data z-score acuan | 5 data (usia, jenis kelamin, BB, TB) beserta nilai acuan dari WHO Anthro / Permenkes No. 2 Tahun 2020 |
| Data dashboard | ± 1.000 data baduta (untuk uji performa dashboard) |
| Perangkat kuis | 3 HP (1 room master, 2 pemain) + perekam layar |

---

## A. Autentikasi & Hak Akses

| ID | Fitur | Skenario / Langkah Uji | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|
| TC-01 | Login (ER-6.5) | Orang tua membuka aplikasi, memasukkan email dan password yang terdaftar, lalu tekan Masuk | Berhasil masuk ke Beranda dengan menu orang tua (pemantauan, gizi, edukasi, konsultasi, kuis) | | |
| TC-02 | Login gagal (ER-6.1) | Memasukkan email terdaftar dengan password salah | Login ditolak; pesan menyebutkan penyebab (password salah) dan langkah perbaikan (coba lagi / lupa password) | | |
| TC-03 | Lupa password (ER-6.5) | Tekan "Lupa Password", masukkan email, buka link/OTP, buat password baru, lalu login | Kode OTP/link diterima, password berhasil diganti, login dengan password baru berhasil | | |
| TC-04 | Registrasi nakes (ER-6.5) | Bidan registrasi sebagai tenaga kesehatan dan mengunggah STR | Akun dibuat dengan status "Menunggu verifikasi"; menu konsultasi dan dashboard belum bisa diakses | | |
| TC-05 | Hak akses remaja | Login sebagai remaja, cari menu pemantauan anak dan konsultasi | Hanya menu Artikel, Reels, dan Kuis yang tersedia; menu pemantauan dan konsultasi tidak muncul | | |

## B. Pemantauan Pertumbuhan

| ID | Fitur | Skenario / Langkah Uji | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|
| TC-06 | Tambah profil anak | Orang tua menambah profil: nama, tanggal lahir (12 bulan lalu), laki-laki | Profil tersimpan dan usia tampil 12 bulan | | |
| TC-07 | Hitung z-score (ER-1.1) | Input BB dan TB anak sesuai 5 data uji, lalu bandingkan dengan nilai acuan WHO Anthro | Z-score TB/U, BB/U, BB/TB tampil dengan selisih ≤ 0,01 dari acuan | | |
| TC-08 | Validasi input (ER-6.2) | Input BB = 0 kg, TB = 200 cm, atau field dikosongkan | Data ditolak, field yang salah ditandai, dan muncul pesan rentang nilai yang wajar | | |
| TC-09 | Batas usia baduta | Input pengukuran untuk anak berusia 30 bulan | Sistem tidak memproses dan menampilkan pesan bahwa anak di luar cakupan 0–24 bulan | | |
| TC-10 | Peringatan stunting (ER-1.3) | Input TB anak laki-laki 12 bulan = 70 cm (di bawah -2 SD) | Muncul peringatan risiko stunting dan saran konsultasi ke dokter | | |
| TC-11 | Batas -2 SD (ER-1.3) | Input TB tepat pada nilai -2 SD tabel acuan, lalu TB median (75,7 cm) | Tidak ada peringatan; status normal | | |
| TC-12 | Grafik pertumbuhan (ER-1.2) | Buka grafik anak yang memiliki banyak riwayat pengukuran (uji sampai 60 data) | Grafik BB/U, TB/U, BB/TB tampil lengkap dalam ≤ 3 detik | | |
| TC-13 | Pengingat jadwal (ER-1.4) | Atur pengingat posyandu 5 menit ke depan, lalu tutup aplikasi | Notifikasi muncul dengan selisih ≤ 1 menit dari jadwal | | |

## C. Gizi & Nutrisi

| ID | Fitur | Skenario / Langkah Uji | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|
| TC-14 | Catat makanan (ER-2.1) | Catat sarapan bubur ayam, makan siang nasi + telur, lalu buka statistik | Makanan tersimpan; statistik harian dan mingguan (protein, karbo, serat) ter-update | | |
| TC-15 | Kebutuhan kalori (ER-2.3) | Buka halaman kalori untuk anak 12 bulan | Kebutuhan energi sama persis dengan tabel AKG; persentase pemenuhan sesuai asupan tercatat | | |
| TC-16 | Rekomendasi makanan (ER-2.2) | Tekan "Rekomendasi Makanan" untuk anak tersebut | Muncul minimal 3 makanan berprotein tinggi yang sesuai usia anak | | |

## D. Edukasi

| ID | Fitur | Skenario / Langkah Uji | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|
| TC-17 | Edukasi (ER-3.2) | Buka satu artikel dan satu video Reels memakai jaringan 4G | Konten tampil dalam ≤ 3 detik | | |

## E. Konsultasi

| ID | Fitur | Skenario / Langkah Uji | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|
| TC-18 | Pilih dokter (ER-4.3) | Orang tua membuka daftar dokter, filter spesialis anak, pilih dokter, kirim pertanyaan | Profil dan spesialisasi dokter tampil; pertanyaan terkirim ke dokter yang dipilih | | |
| TC-19 | Batas kewenangan medis (ER-4.2) | Akun non-nakes dan akun nakes yang STR-nya belum diverifikasi mencoba menjawab konsultasi | Kedua aksi ditolak dengan pesan akses tidak diizinkan | | |
| TC-20 | Jawaban dokter (ER-4.1) | Dokter terverifikasi menjawab pertanyaan, lalu cek di HP orang tua | Jawaban diterima ≤ 2 detik dan tersimpan di rekap konsultasi dokter tersebut | | |

## F. Dashboard Nakes

| ID | Fitur | Skenario / Langkah Uji | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|
| TC-21 | Dashboard nakes (ER-5.1) | Nakes membuka dashboard dan filter per posyandu (dengan 1.000 data baduta) | Rekap status gizi tampil sesuai filter dalam ≤ 5 detik | | |
| TC-22 | Ekspor laporan (ER-5.2) | Nakes ekspor laporan ke CSV dan PDF, lalu buka kedua file | Kedua file terunduh, bisa dibuka, dan isinya sesuai data di dashboard | | |

## G. Kuis Multiplayer

| ID | Fitur | Skenario / Langkah Uji | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|
| TC-23 | Buat room kuis (ER-7.1) | Remaja membuat room: Sedang, kategori Remaja, 5 soal, 20 detik | Room terbentuk dengan kode unik 6 karakter | | |
| TC-24 | Gabung room gagal (ER-7.1) | Pemain memasukkan kode room salah, lalu pemain ke-31 mencoba masuk ke room penuh | Kedua percobaan ditolak dengan pesan yang jelas | | |
| TC-25 | Sinkronisasi kuis (ER-7.2, ER-7.3) | 3 HP (1 room master, 2 pemain) memulai kuis; layar direkam bersamaan | Soal tampil serentak (selisih ≤ 1 detik) dan sesuai pengaturan room; skor ter-update ≤ 2 detik setelah waktu habis | | |
| TC-26 | Leaderboard & badge (ER-7.5) | Selesaikan kuis, lalu buka leaderboard mingguan dan profil | Poin dihitung dari ketepatan dan kecepatan; leaderboard dan badge ter-update ≤ 5 detik | | |

---

## Rekap Hasil

| Modul | Jumlah TC | PASS | FAIL | N/A |
|---|---|---|---|---|
| A. Autentikasi & Hak Akses | 5 | | | |
| B. Pemantauan Pertumbuhan | 8 | | | |
| C. Gizi & Nutrisi | 3 | | | |
| D. Edukasi | 1 | | | |
| E. Konsultasi | 3 | | | |
| F. Dashboard Nakes | 2 | | | |
| G. Kuis Multiplayer | 4 | | | |
| **Total** | **26** | | | |

## Catatan Temuan

Isi untuk setiap test case berstatus FAIL.

| ID TC | Deskripsi Temuan | Tingkat Keparahan (Tinggi/Sedang/Rendah) | Bukti (screenshot/rekaman) | Tindak Lanjut |
|---|---|---|---|---|
| | | | | |
