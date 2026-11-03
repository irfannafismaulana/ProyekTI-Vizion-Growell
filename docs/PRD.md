# Product Requirements Document (PRD) — GroWell

| Item | Keterangan |
| --- | --- |
| Produk | GroWell, aplikasi pencegahan stunting dan tumbuh kembang anak |
| Tim | Kelompok 2 / Vizion, mata kuliah Proyek TI, Program Studi Teknologi Informasi, Universitas Telkom |
| Mitra | Dinas Kesehatan Kabupaten Natuna |
| Dosen pengampu | Syifa Nurgaida Yutia, S.TR., M.T. |
| Versi dokumen | 1.0 (draf), 4 November 2026 |
| Status produk | Prototype v0.3 (lihat [README](../README.md)) |
| Acuan | SRS Vizion 23-002 GroWell, Project Charter GroWell final, Laporan Progress Proyek TI 1, [`testcase.md`](../testcase.md), [`DATABASE_SCHEMA.md`](DATABASE_SCHEMA.md) |

Bila PRD ini berbeda dengan dokumen lain, **Project Charter final** menjadi acuan utama karena merupakan kesepakatan dengan
mitra dan dosen. Perbedaan yang ditemukan dicatat di bagian [Keputusan dan hal yang perlu disamakan](#keputusan-dan-hal-yang-perlu-disamakan).

---

## Daftar isi
1. [Ringkasan](#ringkasan)
2. [Latar belakang dan masalah](#latar-belakang-dan-masalah)
3. [Tujuan dan indikator keberhasilan](#tujuan-dan-indikator-keberhasilan)
4. [Pengguna](#pengguna)
5. [Lingkup](#lingkup)
6. [Kebutuhan fungsional](#kebutuhan-fungsional)
7. [Kebutuhan non-fungsional](#kebutuhan-non-fungsional)
8. [Platform dan teknologi](#platform-dan-teknologi)
9. [Jadwal dan milestone](#jadwal-dan-milestone)
10. [Rencana pasca-MVP](#rencana-pasca-mvp)
11. [Risiko](#risiko)
12. [Asumsi dan ketergantungan](#asumsi-dan-ketergantungan)
13. [Keputusan dan hal yang perlu disamakan](#keputusan-dan-hal-yang-perlu-disamakan)

---

## Ringkasan

GroWell adalah aplikasi mobile untuk mendampingi pemantauan tumbuh kembang **baduta (anak usia 0–24 bulan)** dan
mencegah stunting. Aplikasi menghubungkan tiga kelompok pengguna, yaitu orang tua, tenaga kesehatan (nakes), dan remaja
sebagai calon orang tua, ditambah admin yang memverifikasi STR nakes.

MVP ditargetkan siap diujicobakan bersama Dinas Kesehatan Kabupaten Natuna paling lambat **16 November 2026**.
Aplikasi hanya menampilkan **indikator risiko**; keputusan medis tetap pada tenaga kesehatan.

---

## Latar belakang dan masalah

Prevalensi stunting di Indonesia masih **19,8%** (SSGI 2024), atau hampir 1 dari 5 balita. Wawancara dengan orang tua,
tenaga kesehatan, remaja, dan mahasiswa kesehatan, serta pemetaan kebutuhan bersama Dinas Kesehatan Kabupaten Natuna,
menghasilkan masalah berikut:

| Kelompok | Masalah |
| --- | --- |
| Orang tua baduta | Pemantauan tinggi dan berat badan masih manual dan tidak rutin setiap bulan; informasi gizi di internet sulit dipercaya; literasi digital terbatas; sulit berkonsultasi cepat dengan dokter atau ahli gizi |
| Tenaga kesehatan dan Dinas Kesehatan | Data tersebar di berbagai sumber pelaporan; wilayah kepulauan Natuna menyulitkan konsolidasi data dan pemantauan status anak secara cepat |
| Remaja | Belum sadar bahwa pencegahan stunting dimulai sejak masa pra-konsepsi; butuh informasi yang ringan dan praktis |

Akibatnya, risiko stunting sering terlambat terdeteksi dan intervensi ikut terlambat. GroWell menggabungkan pemantauan
berkala, pencatatan gizi, edukasi, konsultasi daring, dan rekap data status gizi dalam satu aplikasi.

---

## Tujuan dan indikator keberhasilan

Diambil dari Project Charter final.

| No. | Tujuan | Indikator keberhasilan |
| --- | --- | --- |
| 1 | Orang tua dapat memantau pertumbuhan baduta setiap bulan | Z-score BB/U, TB/U, BB/TB berselisih ≤ 0,01 dari nilai acuan; peringatan risiko stunting muncul pada 100% pengukuran dengan z-score TB/U < −2 SD; pengingat jadwal terkirim dengan deviasi ≤ 1 menit |
| 2 | Orang tua dapat mencatat asupan harian anak dan mengetahui pemenuhan kebutuhan kalorinya | Kebutuhan kalori sama dengan tabel AKG (Permenkes No. 28 Tahun 2019); minimal 3 rekomendasi makanan berprotein tinggi setiap permintaan |
| 3 | Orang tua dapat berkonsultasi daring dengan dokter/ahli gizi terverifikasi | Pesan terkirim ≤ 2 detik; 100% percobaan menjawab oleh akun non-nakes ditolak |
| 4 | Nakes dan Dinas Kesehatan memiliki rekap status gizi baduta yang terdigitalisasi | Dashboard dengan filter wilayah/posyandu tampil ≤ 5 detik untuk 1.000 data baduta; laporan dapat diekspor ke CSV dan PDF |
| 5 | Remaja dan orang tua memperoleh edukasi gizi yang terpercaya | Minimal 20 konten (artikel dan video pendek) yang ditinjau tenaga kesehatan dan dikategorikan per peran |
| 6 | Aplikasi mudah digunakan oleh pengguna dengan literasi digital terbatas | ≥ 70% responden setuju pada prinsip Error Prevention, Consistency and Standards, Help Users Recognize, Diagnose, and Recover from Errors, serta Help and Documentation (baseline 19,0–50,0%) |
| 7 | MVP siap diujicobakan bersama mitra paling lambat 16 November 2026 | 4 dari 4 test case fungsional lulus; uji coba melibatkan minimal 5 orang tua dan 2 tenaga kesehatan |

---

## Pengguna

| Peran | Siapa | Kebutuhan utama | Akses di aplikasi |
| --- | --- | --- | --- |
| Orang tua | Ibu/ayah dengan anak usia < 2 tahun | Memantau pertumbuhan, tahu apakah anak berisiko, pengingat periksa, info gizi terpercaya, konsultasi dengan dokter yang bisa dipilih | Profil anak, pertumbuhan, gizi harian, edukasi, konsultasi |
| Tenaga kesehatan | Dokter/ahli gizi/bidan dengan STR terverifikasi | Data pemantauan baduta yang terpusat, menjawab konsultasi, antarmuka sederhana | Dashboard baduta, konsultasi, catatan konsultasi, jadwal kontrol |
| Remaja | Remaja sebagai calon orang tua | Informasi gizi yang ringan dan praktis untuk jadwal yang padat | Edukasi (artikel dan reels) |
| Admin | Pengelola aplikasi | Memastikan hanya nakes asli yang bisa menjawab konsultasi | Verifikasi STR |

---

## Lingkup

### Dalam lingkup MVP
1. Uji coba di Kabupaten Natuna bersama Dinas Kesehatan Kabupaten Natuna.
2. **Modul Orang Tua** (baduta 0–24 bulan): pencatatan BB dan TB bulanan, z-score dan grafik BB/U, TB/U, BB/TB, peringatan
   risiko stunting, pengingat jadwal; pencatatan gizi harian dan kebutuhan kalori; edukasi pola asuh dan gizi/MPASI;
   konsultasi daring beserta rekap konsultasi.
3. **Modul Tenaga Kesehatan**: dashboard rekap status gizi baduta dengan filter wilayah/posyandu, ekspor laporan CSV/PDF,
   dan layanan menjawab konsultasi bagi akun dengan STR terverifikasi.
4. **Modul Remaja**: edukasi gizi dan pencegahan stunting sejak masa pra-konsepsi (artikel dan video pendek).
5. **Fungsi pendukung**: registrasi, login, pemulihan akun, kontrol akses per peran (orang tua, remaja, nakes, admin), dan
   verifikasi STR oleh admin.

### Di luar lingkup MVP
1. Penegakan diagnosis medis. Aplikasi hanya menampilkan indikator risiko.
2. Pemantauan anak di atas 24 bulan dan pengguna di luar peran di atas.
3. Mode offline dengan sinkronisasi otomatis.
4. **Kuis kesehatan multiplayer real-time** (MR-7), dikembangkan setelah MVP.
5. Publikasi ke Play Store/App Store dan penggunaan produksi skala kabupaten.
6. Integrasi atau penyatuan data dengan sistem pelaporan lain seperti e-PPGBM dan SSGI.
7. **Estimasi pertumbuhan dari foto.** Di prototype masih berupa simulasi, bukan model AI.
8. **Asisten tanya-jawab berbasis aturan.** Peran konsultasi sudah digantikan konsultasi dengan dokter ber-STR.

Butir 1–5 berasal dari charter. Butir 6 berasal dari daftar risiko charter. Butir 7 dan 8 adalah keputusan tim untuk fitur
yang ada di prototype tetapi tidak tercantum di SRS maupun charter.

---

## Kebutuhan fungsional

Kode MR dan ER merujuk ke SRS. Kolom **Status v0.3** menggambarkan kondisi repositori saat dokumen ini ditulis.

### Modul Orang Tua — pemantauan pertumbuhan (MR-1)

| ID | Kebutuhan | Kriteria penerimaan | Test case | Status v0.3 |
| --- | --- | --- | --- | --- |
| ER-1.1 | Menghitung z-score TB/U, BB/U, BB/TB baduta 0–24 bulan | Selisih ≤ 0,01 terhadap tabel acuan (WHO Anthro / Permenkes No. 2 Tahun 2020) | TC-07 | Ada, dengan uji unit |
| ER-1.2 | Menyimpan riwayat pengukuran dan menampilkan grafik tiga indikator | Grafik tampil ≤ 3 detik untuk hingga 60 data per anak | TC-12 | Ada |
| ER-1.3 | Peringatan risiko stunting otomatis | Muncul pada 100% data dengan z-score TB/U < −2 SD; tidak muncul tepat di −2 SD | TC-10, TC-11 | Ada |
| ER-1.4 | Notifikasi pengingat jadwal pemeriksaan | Deviasi ≤ 1 menit dari jadwal, juga saat aplikasi ditutup | TC-13 | Belum; butuh versi Android dan notifikasi lokal/FCM |
| – | Profil anak, batas usia 0–24 bulan | Profil tersimpan; pengukuran untuk anak > 24 bulan ditolak | TC-06, TC-09 | Ada, dijaga juga oleh trigger database |

### Modul Orang Tua — gizi harian (MR-2)

| ID | Kebutuhan | Kriteria penerimaan | Test case | Status v0.3 |
| --- | --- | --- | --- | --- |
| ER-2.1 | Mencatat makanan harian dan menampilkan statistik harian serta mingguan | Data tersimpan; statistik protein, karbohidrat, serat ter-update | TC-14 | Ada |
| ER-2.2 | Minimal 3 rekomendasi makanan berprotein tinggi sesuai usia | ≥ 3 rekomendasi setiap permintaan | TC-16 | Ada |
| ER-2.3 | Kebutuhan kalori harian sesuai AKG dan persentase pemenuhan | Nilai sama persis dengan tabel AKG | TC-15 | Ada |

### Edukasi (MR-3)

| ID | Kebutuhan | Kriteria penerimaan | Test case | Status v0.3 |
| --- | --- | --- | --- | --- |
| ER-3.1 | Minimal 20 konten edukasi, dikategorikan per usia/peran, ditinjau nakes | ≥ 20 konten berstatus sudah ditinjau | – | Sebagian; 13 konten berstatus draf, belum ditinjau nakes |
| ER-3.2 | Halaman konten tampil cepat | ≤ 3 detik pada jaringan 4G | TC-17 | Belum diukur |

### Konsultasi (MR-4)

| ID | Kebutuhan | Kriteria penerimaan | Test case | Status v0.3 |
| --- | --- | --- | --- | --- |
| ER-4.1 | Kirim dan terima pesan konsultasi | ≤ 2 detik | TC-20 | Ada (Realtime); waktu belum diukur |
| ER-4.2 | Jawaban medis hanya dari nakes terverifikasi | 100% percobaan oleh akun non-nakes dan nakes belum terverifikasi ditolak | TC-19 | Ada; dijaga RLS dan diuji pgTAP |
| ER-4.3 | Daftar dokter dengan profil dan spesialisasi, pemilihan dokter, rekap per dokter | Profil dan spesialisasi tampil; pertanyaan terkirim ke dokter yang dipilih | TC-18 | Sebagian; filter berdasarkan spesialisasi belum ada |
| – | Catatan konsultasi dan jadwal kontrol oleh nakes | Catatan bisa diunduh sebagai PDF | – | Ada |

### Modul Tenaga Kesehatan (MR-5)

| ID | Kebutuhan | Kriteria penerimaan | Test case | Status v0.3 |
| --- | --- | --- | --- | --- |
| ER-5.1 | Dashboard rekap status gizi baduta binaan dengan filter wilayah/posyandu | ≤ 5 detik untuk 1.000 data baduta | TC-21 | Ada; data posyandu masih contoh, belum dibatasi ke posyandu binaan |
| ER-5.2 | Ekspor laporan data baduta ke CSV dan PDF | Kedua file terunduh dan isinya sesuai dashboard | TC-22 | Sebagian; CSV ada, PDF dashboard belum |

### Akun dan hak akses (MR-6, ER-6.5)

| ID | Kebutuhan | Kriteria penerimaan | Test case | Status v0.3 |
| --- | --- | --- | --- | --- |
| ER-6.5 | Login/registrasi, pemulihan akun via OTP, kontrol akses per peran, verifikasi STR nakes, kata sandi ter-hash, HTTPS | Login berhasil dan gagal sesuai skenario; OTP diterima; nakes baru berstatus menunggu verifikasi; remaja tidak melihat menu pemantauan anak dan konsultasi | TC-01 s.d. TC-05 | Ada; unggah dokumen STR masih simulasi |

---

## Kebutuhan non-fungsional

| ID | Aspek | Target |
| --- | --- | --- |
| ER-6.1 | Pesan kesalahan | Menyebut penyebab dan langkah perbaikan; ≥ 70% responden setuju (baseline 19,0%) |
| ER-6.2 | Pencegahan kesalahan input | Data tidak lengkap/tidak wajar ditolak; ≥ 70% responden setuju (baseline 38,1%) |
| ER-6.3 | Bantuan dan onboarding | Mudah ditemukan; ≥ 70% responden setuju (baseline 19,0%) |
| ER-6.4 | Konsistensi tampilan | Tata letak, tombol, dan tema konsisten; ≥ 70% responden setuju (baseline 50,0%) |
| ER-6.6 | Platform dan kecepatan | Berjalan di Android dan iOS; respons < 3 detik pada operasi umum |
| – | Keamanan dan privasi data anak | RLS per peran, HTTPS, kata sandi ter-hash, data dikumpulkan seminimal mungkin, persetujuan pengguna saat registrasi |
| – | Akurasi | Status gizi mengacu pada Permenkes No. 2 Tahun 2020 dan WHO Child Growth Standards |

Target ER-6.1 sampai ER-6.4 diukur ulang dengan evaluasi heuristik Nielsen setelah desain baru selesai.

---

## Platform dan teknologi

| Tahap | Platform |
| --- | --- |
| Demo dan presentasi | Flutter web (Chrome), seperti prototype v0.3 |
| Uji coba bersama mitra | Android (berkas APK, tanpa publikasi ke Play Store). Dibutuhkan agar pengingat jadwal (ER-1.4, TC-13) bisa berjalan saat aplikasi ditutup |
| Setelah MVP | iOS |

Flutter memakai satu basis kode, sehingga versi Android tidak memerlukan penulisan ulang aplikasi.

| Bagian | Teknologi |
| --- | --- |
| Aplikasi | Flutter (Dart), Riverpod, go_router |
| Grafik dan dokumen | fl_chart, pdf |
| Backend | Supabase: PostgreSQL + RLS, Auth, Realtime; Storage dan Edge Functions direncanakan |
| Notifikasi | Notifikasi lokal dan Firebase Cloud Messaging (direncanakan untuk versi Android) |
| Pengujian | flutter_test (uji unit dan widget), pgTAP untuk RLS |
| Kolaborasi | Figma, GitHub |

Struktur database dijelaskan di [`DATABASE_SCHEMA.md`](DATABASE_SCHEMA.md).

---

## Jadwal dan milestone

Diambil dari Project Charter final.

| Tahap | Waktu | Status |
| --- | --- | --- |
| Riset awal dengan mitra | 11 Mei 2025 | Selesai |
| Fase 1: riset dan analisis kebutuhan | 1–30 September 2026 | Selesai |
| Spesifikasi kebutuhan dan perancangan sistem | 1–7 Oktober 2026 | Selesai, kecuali hasil pengujian |
| Sign-off project charter | 18 Oktober 2026 (mitra dan PM), target 23 Oktober 2026 (dosen) | |
| Fase 2: desain UI/UX | 8–28 Oktober 2026 | |
| Fase 3: front-end | 20–31 Oktober 2026 | |
| Fase 4: back-end | 20 Oktober – 12 November 2026 | Berjalan |
| Fase 5: integrasi, pengujian, evaluasi bersama mitra | 13–16 November 2026 | |
| Revisi pasca-evaluasi mitra | 17–30 November 2026 | |
| Laporan akhir dan presentasi | Desember 2026 | |

---

## Rencana pasca-MVP

| Fitur | Keterangan |
| --- | --- |
| Kuis kesehatan multiplayer real-time (MR-7, ER-7.1–7.5) | Room dengan kode 6 karakter untuk 2–30 pemain, soal serentak (selisih ≤ 1 detik), bank soal ≥ 100 soal yang ditinjau nakes, leaderboard mingguan dan lencana. Prototype sudah punya kuis satu pemain melawan bot (bank soal ±40 soal) dan tabel skor/lencana; boleh tetap ditampilkan sebagai kuis latihan, tetapi bukan syarat MVP. Test case TC-23 s.d. TC-26 ditandai pasca-MVP |
| Versi iOS | Setelah uji coba Android |
| Unggah foto dan dokumen STR ke Supabase Storage | Menggantikan simulasi unggah STR |
| Mode offline | Charter menyebutnya sebagai pengembangan lanjutan untuk wilayah dengan internet terbatas |

---

## Risiko

Diringkas dari Project Charter final.

| Risiko | Tingkat | Mitigasi |
| --- | --- | --- |
| Kebocoran/penyalahgunaan data kesehatan anak | Tinggi | RLS per peran, HTTPS, kata sandi ter-hash, data seminimal mungkin, persetujuan pengguna |
| Kesalahan perhitungan z-score | Tinggi | Tabel acuan resmi, uji unit, validasi terhadap WHO Anthro |
| Perubahan lingkup di tengah proyek | Tinggi | Disetujui PM dan dicatat sebagai revisi charter; fitur baru masuk daftar pasca-MVP |
| Jadwal antarfase rapat | Tinggi | Front-end paralel dari wireframe; kontrak API disepakati di awal |
| Belum ada dokter/ahli gizi terverifikasi untuk uji coba | Sedang | Meminta mitra menunjuk 1 dokter dan 1 ahli gizi; akun dokter uji untuk pengujian internal |
| Keterbatasan internet di wilayah kepulauan | Sedang | Aplikasi dan konten ringan; mode offline sebagai pengembangan lanjutan |
| Ekspektasi bahwa aplikasi menyatukan data e-PPGBM/SSGI | Sedang | Integrasi dinyatakan di luar lingkup dan dikomunikasikan ke mitra |
| Proyek Supabase paket gratis dijeda setelah 7 hari tidak aktif | Rendah | Cek status layanan sebelum demo/uji coba |

---

## Asumsi dan ketergantungan

- Mitra bersedia menyediakan waktu koordinasi dan peserta uji coba (minimal 5 orang tua dan 2 tenaga kesehatan).
- Pengguna memiliki ponsel dan akses internet.
- Data pengukuran diinput oleh orang tua.
- Mitra menyediakan daftar posyandu dan wilayah di Kabupaten Natuna untuk filter dashboard.
- Tenaga kesehatan meninjau konten edukasi sebelum uji coba.
- Paket gratis layanan cloud cukup untuk tahap pengembangan dan uji coba.

---

## Keputusan dan hal yang perlu disamakan

### Keputusan tim untuk PRD ini
1. **Kuis multiplayer** mengikuti charter: pasca-MVP. Kuis latihan melawan bot boleh tetap ada, tetapi bukan syarat MVP.
2. **Platform**: web untuk demo, Android (APK) untuk uji coba mitra, iOS setelah MVP.
3. **Estimasi dari foto** di luar lingkup MVP dan sebaiknya disembunyikan saat uji coba, karena hasil simulasinya tersimpan
   sebagai data pengukuran dan ikut terhitung di z-score, peringatan, dan dashboard nakes.
4. **Asisten tanya-jawab** di luar lingkup MVP. Bila tetap ditampilkan, perlu keterangan bahwa isinya informasi umum,
   bukan saran medis.

### Perbedaan antardokumen yang perlu disamakan
| Hal | Perbedaan | Usulan |
| --- | --- | --- |
| Kuis multiplayer | SRS mencantumkan MR-7 dan ER-7.x; `testcase.md` memuat TC-23 s.d. TC-26; charter menaruhnya di luar lingkup | Beri catatan "pasca-MVP" di SRS dan `testcase.md` |
| Platform | SRS dan charter: Android dan iOS; prototype: web | Ikuti tabel di bagian [Platform dan teknologi](#platform-dan-teknologi) |
| Lingkar kepala | Laporan progress menyebut lingkar kepala; SRS, charter, dan database hanya BB dan TB | Ikuti SRS dan charter |
| Edukasi remaja | Laporan progress menyebut kesehatan reproduksi; charter hanya edukasi gizi dan pencegahan stunting | Ikuti charter |
| Teknologi | SRS menyebut drift (cache lokal) dan notifikasi lokal; keduanya belum dipakai di prototype | Tentukan saat membuat versi Android |

### Pertanyaan terbuka
1. Daftar posyandu dan wilayah Natuna yang akan dipakai untuk uji coba (data di database masih contoh dari Jakarta).
2. Apakah dashboard nakes dibatasi ke posyandu binaan masing-masing nakes? Bila ya, database perlu tabel penghubung
   nakes–posyandu.
3. Siapa dokter dan ahli gizi dari mitra yang akan memakai akun nakes saat uji coba?
4. Siapa tenaga kesehatan yang meninjau konten edukasi, dan kapan?
