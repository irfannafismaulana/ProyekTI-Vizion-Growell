import '../models.dart';

/// DRAF KONTEN — ditulis untuk prototype dan WAJIB ditinjau tenaga kesehatan
/// sebelum dipublikasikan (ER-3.1).
const draftNotice = 'Draf konten prototype — belum ditinjau tenaga kesehatan.';

const articles = <Article>[
  Article(
    id: 'a1',
    title: 'Apa itu stunting? Bukan sekadar pendek',
    summary: 'Stunting adalah gagal tumbuh akibat kekurangan gizi kronis, terutama pada 1.000 hari pertama kehidupan.',
    minutes: 3,
    audience: {Role.parent, Role.teen},
    body: 'Stunting adalah kondisi gagal tumbuh pada anak akibat kekurangan gizi dalam waktu lama dan infeksi berulang, '
        'terutama pada 1.000 hari pertama kehidupan (HPK). Anak dikatakan stunting bila panjang atau tinggi badannya '
        'menurut umur berada di bawah -2 standar deviasi (SD) standar pertumbuhan WHO.\n\n'
        'Stunting bukan hanya soal tinggi badan. Kondisi ini juga dapat memengaruhi perkembangan otak, kemampuan belajar, '
        'dan kesehatan anak di masa depan. Karena itu, pengukuran panjang/tinggi badan dan berat badan secara rutin di '
        'posyandu sangat penting untuk mendeteksi masalah sejak dini.\n\n'
        'Kabar baiknya, stunting dapat dicegah: gizi yang cukup sejak masa kehamilan, ASI eksklusif, MPASI yang kaya '
        'protein hewani, imunisasi, serta sanitasi dan kebiasaan cuci tangan pakai sabun.',
  ),
  Article(
    id: 'a2',
    title: 'Mengenal 1.000 Hari Pertama Kehidupan',
    summary: 'Periode emas sejak kehamilan hingga anak berusia 2 tahun yang menentukan tumbuh kembang.',
    minutes: 3,
    audience: {Role.parent, Role.teen},
    body: '1.000 Hari Pertama Kehidupan (HPK) dihitung sejak awal kehamilan (sekitar 270 hari) hingga anak berusia '
        '2 tahun (730 hari). Pada periode ini pertumbuhan otak dan tubuh berlangsung sangat cepat.\n\n'
        'Yang bisa dilakukan: memeriksakan kehamilan secara rutin (minimal 6 kali selama kehamilan), mengonsumsi tablet '
        'tambah darah sesuai anjuran, memberikan ASI eksklusif selama 6 bulan, lalu MPASI bergizi sambil tetap menyusui '
        'hingga 2 tahun atau lebih.\n\n'
        'Bagi remaja, menjaga gizi sejak sekarang adalah investasi: kondisi gizi calon ibu sebelum hamil ikut menentukan '
        'kesehatan bayi kelak.',
  ),
  Article(
    id: 'a3',
    title: 'ASI eksklusif 6 bulan: kenapa penting?',
    summary: 'Hanya ASI sejak lahir sampai 6 bulan, tanpa makanan atau minuman lain.',
    minutes: 2,
    audience: {Role.parent},
    body: 'ASI eksklusif berarti bayi hanya diberi ASI sejak lahir hingga usia 6 bulan, tanpa tambahan makanan atau '
        'minuman lain, termasuk air putih, kecuali obat atau vitamin sesuai anjuran tenaga kesehatan.\n\n'
        'ASI mengandung zat gizi dan zat kekebalan yang sesuai kebutuhan bayi. Mulailah dengan Inisiasi Menyusu Dini '
        'sesaat setelah lahir, susui sesering bayi mau, dan konsultasikan ke tenaga kesehatan bila ada kesulitan menyusui.\n\n'
        'Setelah 6 bulan, ASI tetap dilanjutkan hingga 2 tahun atau lebih bersama MPASI.',
  ),
  Article(
    id: 'a4',
    title: 'MPASI kaya protein hewani',
    summary: 'Mulai usia 6 bulan, sertakan sumber protein hewani setiap hari.',
    minutes: 3,
    audience: {Role.parent},
    body: 'MPASI (makanan pendamping ASI) dimulai saat bayi berusia 6 bulan. Tekstur dimulai dari lumat, lalu bertahap '
        'menjadi cincang dan makanan keluarga sesuai usia.\n\n'
        'Protein hewani seperti telur, ikan, hati ayam, daging ayam, dan daging sapi sebaiknya ada setiap hari karena '
        'mengandung protein berkualitas, zat besi, dan seng yang penting untuk pertumbuhan.\n\n'
        'Lengkapi dengan sumber karbohidrat, sayur, buah, dan lemak tambahan. Jaga kebersihan saat menyiapkan makanan '
        'dan cuci tangan pakai sabun sebelum menyuapi anak.',
  ),
  Article(
    id: 'a5',
    title: 'Anemia pada remaja putri dan tablet tambah darah',
    summary: 'Remaja putri dianjurkan minum 1 tablet tambah darah setiap minggu.',
    minutes: 3,
    audience: {Role.teen},
    body: 'Anemia adalah kondisi kadar hemoglobin (Hb) dalam darah lebih rendah dari normal. Gejalanya antara lain mudah '
        'lelah, lesu, pusing, dan sulit berkonsentrasi.\n\n'
        'Remaja putri berisiko anemia karena kehilangan darah saat menstruasi. Program pemerintah menganjurkan remaja '
        'putri minum 1 tablet tambah darah (TTD) setiap minggu. Konsumsi juga makanan sumber zat besi seperti hati, '
        'daging merah, ikan, dan sayuran hijau.\n\n'
        'Mencegah anemia sejak remaja membantu menyiapkan kehamilan yang sehat dan menurunkan risiko bayi lahir stunting.',
  ),
  Article(
    id: 'a6',
    title: 'Gizi seimbang untuk remaja yang sibuk',
    summary: 'Tips praktis makan sehat di sela jadwal padat.',
    minutes: 2,
    audience: {Role.teen},
    body: 'Jadwal padat sering membuat kita melewatkan makan atau memilih makanan instan. Coba langkah sederhana ini:\n\n'
        '• Jangan lewatkan sarapan; pilih yang mengandung protein seperti telur atau tempe.\n'
        '• Gunakan prinsip "Isi Piringku": setengah piring sayur dan buah, setengahnya lagi makanan pokok dan lauk.\n'
        '• Bawa bekal atau camilan sehat seperti buah dan kacang.\n'
        '• Cukupi minum air putih dan batasi minuman manis.\n'
        '• Sempatkan aktivitas fisik minimal 30 menit sehari.',
  ),
  Article(
    id: 'a7',
    title: 'Kenapa harus rutin ke posyandu tiap bulan?',
    summary: 'Pengukuran rutin membantu mendeteksi gangguan pertumbuhan sejak dini.',
    minutes: 2,
    audience: {Role.parent},
    body: 'Di posyandu, berat badan dan panjang/tinggi badan anak diukur setiap bulan lalu dibandingkan dengan standar '
        'pertumbuhan. Dari pengukuran rutin, gangguan pertumbuhan dapat terlihat sebelum terlambat.\n\n'
        'Catat hasil pengukuran di GroWell agar grafik pertumbuhan anak terlihat dari waktu ke waktu. Bila muncul '
        'peringatan risiko stunting, segera konsultasikan dengan tenaga kesehatan.',
  ),
  Article(
    id: 'a8',
    title: 'Stunting dan gizi buruk itu berbeda',
    summary: 'Banyak yang menyamakan keduanya, padahal indikatornya berbeda.',
    minutes: 2,
    audience: {Role.parent, Role.teen},
    body: 'Stunting dilihat dari panjang/tinggi badan menurut umur (di bawah -2 SD) dan menggambarkan kekurangan gizi '
        'jangka panjang. Gizi buruk dilihat dari berat badan menurut panjang/tinggi badan (di bawah -3 SD) dan '
        'menggambarkan kekurangan gizi akut.\n\n'
        'Anak yang terlihat tidak kurus pun bisa stunting. Karena itu, panjang/tinggi badan perlu diukur, bukan hanya '
        'berat badan.',
  ),
];

/// Reels (video pendek). Prototype menampilkan sampul + teks; angka suka/komentar adalah data contoh.
const reels = <Reel>[
  Reel(
    id: 'r_mpasi',
    author: 'Dr. Irfan Nufis M, Sp.A',
    title: 'MPASI 6 Bulan Bergizi',
    caption: 'Menu MPASI 6 bulan pertama yang simpel dan bergizi untuk tumbuh kembang optimal: mulai dari tekstur lumat, '
        'selalu ada protein hewani, dan tanpa gula/garam tambahan.',
    headline: 'RESEP MPASI PERTAMA',
    subline: 'Ala Kemenkes',
    seconds: 60,
    likes: 2140,
    comments: 156,
    audience: {Role.parent},
    colors: [0xFFF5C6A5, 0xFFE8A27C],
    image: 'assets/reel_mpasi.jpg',
    articleId: 'a4',
  ),
  Reel(
    id: 'r_ukur',
    author: 'dr. Sarah Wijaya, Sp.A',
    title: 'Cara mengukur panjang badan bayi',
    caption: 'Anak di bawah 2 tahun diukur berbaring (panjang badan), bukan berdiri. Minta bantuan kader posyandu agar hasilnya tepat.',
    headline: 'CARA UKUR PANJANG BAYI',
    subline: 'Posisi berbaring',
    seconds: 45,
    likes: 980,
    comments: 64,
    audience: {Role.parent},
    colors: [0xFF7FB2FF, 0xFF2E7EFE],
    articleId: 'a7',
  ),
  Reel(
    id: 'r_mitos',
    author: 'Rina Kartika, S.Gz.',
    title: 'Mitos vs fakta stunting',
    caption: 'Stunting bukan sekadar pendek karena keturunan. Gizi kronis dan infeksi berulang pada 1.000 HPK adalah penyebab utamanya.',
    headline: 'MITOS vs FAKTA',
    subline: 'Stunting = pendek saja?',
    seconds: 50,
    likes: 1530,
    comments: 98,
    audience: {Role.parent, Role.teen},
    colors: [0xFFFFB4C8, 0xFFF0446E],
    articleId: 'a8',
  ),
  Reel(
    id: 'r_bekal',
    author: 'Rina Kartika, S.Gz.',
    title: 'Bekal sehat 5 menit untuk remaja',
    caption: 'Nasi, telur, sayur, dan buah: bekal sederhana yang memenuhi isi piringku. Gizi remaja hari ini menentukan generasi berikutnya.',
    headline: 'BEKAL SEHAT 5 MENIT',
    subline: 'Untuk remaja',
    seconds: 40,
    likes: 760,
    comments: 41,
    audience: {Role.teen},
    colors: [0xFF9BE7B0, 0xFF19B45A],
    articleId: 'a6',
  ),
  Reel(
    id: 'r_ttd',
    author: 'dr. Sarah Wijaya, Sp.A',
    title: 'Tablet tambah darah untuk remaja putri',
    caption: 'Remaja putri dianjurkan minum 1 tablet tambah darah setiap minggu untuk mencegah anemia. Cek program di sekolah/puskesmas.',
    headline: 'TABLET TAMBAH DARAH',
    subline: '1 tablet tiap minggu',
    seconds: 35,
    likes: 640,
    comments: 37,
    audience: {Role.teen},
    colors: [0xFFD6B4FF, 0xFF8E44EC],
    articleId: 'a5',
  ),
];
