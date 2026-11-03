import '../core/zscore.dart';
import '../models.dart';

/// DATA CONTOH (fiktif) untuk prototype lokal. Semua akun memakai sandi `demo123`.
const demoPassword = 'demo123';

const seedUsers = <AppUser>[
  AppUser(id: 'u_rani', name: 'Rani Lestari', email: 'rani@demo.id', password: demoPassword, role: Role.parent),
  AppUser(id: 'u_fitri', name: 'Fitri Handayani', email: 'fitri@demo.id', password: demoPassword, role: Role.parent),
  AppUser(id: 'u_wulan', name: 'Wulan Sari', email: 'wulan@demo.id', password: demoPassword, role: Role.parent),
  AppUser(id: 'u_dina', name: 'Dina Ayu', email: 'dina@demo.id', password: demoPassword, role: Role.teen),
  AppUser(
      id: 'u_irfan', name: 'Dr. Irfan Nufis M, Sp.A', email: 'irfan@demo.id', password: demoPassword,
      role: Role.health, strNumber: 'STR-CONTOH-0001', verified: true,
      title: 'Dokter spesialis anak', specialty: 'Spesialis Anak', experienceYears: 8, workplace: 'RS Contoh Sehat'),
  AppUser(
      id: 'u_siti', name: 'Dr. Siti Rahmawati, Sp.PD', email: 'siti@demo.id', password: demoPassword,
      role: Role.health, strNumber: 'STR-CONTOH-0002', verified: true,
      title: 'Dokter spesialis penyakit dalam', specialty: 'Spesialis Penyakit Dalam', experienceYears: 10, workplace: 'RS Contoh Sehat'),
  AppUser(
      id: 'u_budi', name: 'Dr. Budi Santoso, Sp.OG', email: 'budi@demo.id', password: demoPassword,
      role: Role.health, strNumber: 'STR-CONTOH-0003', verified: true,
      title: 'Dokter spesialis kandungan', specialty: 'Spesialis Kandungan', experienceYears: 12, workplace: 'RS Contoh Sehat'),
  AppUser(
      id: 'u_sarah', name: 'dr. Sarah Wijaya, Sp.A', email: 'sarah@demo.id', password: demoPassword,
      role: Role.health, strNumber: 'STR-CONTOH-0004', verified: true,
      title: 'Dokter spesialis anak', specialty: 'Spesialis Anak', experienceYears: 6, workplace: 'Puskesmas Contoh'),
  AppUser(
      id: 'u_rina', name: 'Rina Kartika, S.Gz.', email: 'rina@demo.id', password: demoPassword,
      role: Role.health, strNumber: 'STR-CONTOH-0005', verified: true,
      title: 'Ahli gizi (dietisien)', specialty: 'Ahli Gizi', experienceYears: 6, workplace: 'Puskesmas Contoh'),
  AppUser(
      id: 'u_candra', name: 'dr. Candra Wijaya', email: 'candra@demo.id', password: demoPassword,
      role: Role.health, strNumber: 'STR-CONTOH-0006', verified: false,
      title: 'Dokter umum', specialty: 'Dokter Umum', experienceYears: 2, workplace: 'Klinik Contoh'),
  AppUser(id: 'u_admin', name: 'Admin GroWell', email: 'admin@demo.id', password: demoPassword, role: Role.admin),
];

class SeedChild {
  const SeedChild(this.id, this.parentId, this.name, this.sex, this.ageDaysToday, this.posyandu, this.region, this.measurements);
  final String id;
  final String parentId;
  final String name;
  final Sex sex;
  final int ageDaysToday;
  final String posyandu;
  final String region;

  /// (umur saat diukur dalam hari, berat kg, panjang cm)
  final List<(int, double, double)> measurements;
}

const seedChildren = <SeedChild>[
  // Abiyu: panjang badan makin menjauh dari median → status Kurang (risiko stunting).
  SeedChild('c_abiyu', 'u_rani', 'Abiyu', Sex.male, 198, 'Posyandu Melati', 'Kel. Kalideres',
      [(30, 3.9, 52.0), (61, 4.6, 55.0), (91, 5.3, 57.5), (122, 5.8, 59.5), (152, 6.2, 61.0), (183, 6.5, 62.3)]),
  SeedChild('c_alya', 'u_rani', 'Alya', Sex.female, 300, 'Posyandu Melati', 'Kel. Kalideres',
      [(120, 5.9, 61.0), (150, 6.4, 63.0), (180, 6.8, 64.6), (210, 7.2, 66.5), (240, 7.5, 67.8), (270, 7.8, 69.0), (290, 8.0, 70.0)]),
  SeedChild('c_rafa', 'u_fitri', 'Rafa', Sex.male, 600, 'Posyandu Melati', 'Kel. Kalideres',
      [(420, 8.9, 73.5), (480, 9.2, 75.0), (570, 9.6, 77.0)]),
  SeedChild('c_kenzo', 'u_fitri', 'Kenzo', Sex.male, 400, 'Posyandu Melati', 'Kel. Kalideres', [(390, 9.3, 74.5)]),
  SeedChild('c_citra', 'u_fitri', 'Citra', Sex.female, 200, 'Posyandu Melati', 'Kel. Kalideres', [(190, 7.0, 65.0)]),
  SeedChild('c_sekar', 'u_fitri', 'Sekar', Sex.female, 700, 'Posyandu Melati', 'Kel. Kalideres', [(690, 10.8, 83.5)]),
  SeedChild('c_nadia', 'u_wulan', 'Nadia', Sex.female, 500, 'Posyandu Mawar', 'Kel. Cilandak', [(490, 8.2, 72.0)]),
  SeedChild('c_bayu', 'u_wulan', 'Bayu', Sex.male, 650, 'Posyandu Mawar', 'Kel. Cilandak', [(640, 9.0, 75.5)]),
  SeedChild('c_dimas', 'u_wulan', 'Dimas', Sex.male, 120, 'Posyandu Mawar', 'Kel. Cilandak', [(110, 6.3, 61.5)]),
];

const posyanduList = ['Posyandu Melati', 'Posyandu Mawar'];
const regionOfPosyandu = {'Posyandu Melati': 'Kel. Kalideres', 'Posyandu Mawar': 'Kel. Cilandak'};

/// Poin leaderboard mingguan awal (pemain contoh).
const seedLeaderboard = <String, int>{
  'Dina Ayu': 2350,
  'Fitri Handayani': 1980,
  'Bot Rina': 3120,
  'Bot Adi': 1640,
};
