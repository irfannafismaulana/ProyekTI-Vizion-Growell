import '../core/nutrition.dart';
import '../models.dart';
import 'foods.dart';

/// DRAF RESEP — ditulis untuk prototype, WAJIB ditinjau ahli gizi/tenaga kesehatan.
/// Prinsip yang dipakai: tekstur bertahap sesuai usia, protein hewani di setiap
/// menu, tambahan lemak untuk kepadatan energi, tanpa gula/garam tambahan < 12 bulan,
/// susu sapi bukan untuk bayi < 12 bulan.
const recipes = <Recipe>[
  Recipe(
    id: 'bubur_hati',
    name: 'Bubur Hati Ayam Wortel',
    description: 'MPASI pertama yang kaya zat besi dari hati ayam',
    minutes: 25,
    servings: 2,
    difficulty: 'Mudah',
    minMonths: 6,
    maxMonths: 8,
    ingredients: [('bubur', 100), ('hati', 15), ('wortel', 15), ('minyak', 3)],
    seasonings: ['Air kaldu ayam tanpa garam', 'Sedikit bawang putih'],
    steps: [
      'Rebus hati ayam dan wortel sampai matang dan empuk.',
      'Masak bubur nasi dengan air kaldu sampai sangat lembut.',
      'Haluskan hati, wortel, dan bubur lalu saring hingga lumat.',
      'Tambahkan minyak/santan, aduk rata, sajikan hangat.',
    ],
    texture: 'Lumat dan disaring halus (6–8 bulan)',
    vitamins: 'A, B12, zat besi',
  ),
  Recipe(
    id: 'puree_labu_ikan',
    name: 'Puree Labu Ikan Kembung',
    description: 'Ikan lokal murah dengan protein dan omega-3',
    minutes: 20,
    servings: 2,
    difficulty: 'Mudah',
    minMonths: 6,
    maxMonths: 8,
    ingredients: [('bubur', 60), ('labu', 40), ('ikan', 20), ('minyak', 2)],
    seasonings: ['Daun salam'],
    steps: [
      'Kukus labu kuning dan ikan kembung sampai matang.',
      'Buang semua duri ikan dengan teliti.',
      'Haluskan labu, ikan, dan bubur nasi sampai lumat.',
      'Tambahkan minyak, aduk rata.',
    ],
    texture: 'Lumat dan disaring halus (6–8 bulan)',
    vitamins: 'A, D, omega-3',
  ),
  Recipe(
    id: 'bubur_telur_bayam',
    name: 'Bubur Telur Bayam Lumat',
    description: 'Telur: protein hewani paling mudah didapat',
    minutes: 15,
    servings: 1,
    difficulty: 'Mudah',
    minMonths: 6,
    maxMonths: 8,
    ingredients: [('bubur', 100), ('telur', 25), ('bayam', 15), ('minyak', 2)],
    seasonings: ['Air matang'],
    steps: [
      'Rebus telur sampai matang sempurna (kuning telur tidak lagi cair).',
      'Rebus bayam sebentar, lalu cincang.',
      'Haluskan telur, bayam, dan bubur nasi sampai lumat; tambahkan minyak.',
    ],
    texture: 'Lumat dan disaring halus (6–8 bulan)',
    vitamins: 'A, B12, folat',
  ),
  Recipe(
    id: 'puree_pisang_alpukat',
    name: 'Puree Pisang Alpukat (Selingan)',
    description: 'Selingan padat energi dan lemak baik',
    minutes: 5,
    servings: 1,
    difficulty: 'Mudah',
    minMonths: 6,
    maxMonths: 11,
    ingredients: [('alpukat', 30), ('pisang', 30)],
    seasonings: ['Tanpa gula tambahan'],
    steps: [
      'Kerok daging alpukat dan pisang matang.',
      'Haluskan dengan garpu sampai lembut; encerkan dengan ASI bila perlu.',
    ],
    texture: 'Lumat (6–8 bulan), boleh sedikit kasar (9–11 bulan)',
    vitamins: 'B6, E, kalium',
  ),
  Recipe(
    id: 'bubur_ayam_kacang_hijau',
    name: 'Bubur Ayam Kacang Hijau',
    description: 'Bubur bergizi tinggi dengan protein dari ayam dan kacang hijau',
    minutes: 30,
    servings: 2,
    difficulty: 'Mudah',
    minMonths: 9,
    maxMonths: 24,
    ingredients: [('bubur', 120), ('ayam', 25), ('kachijau', 20), ('wortel', 15), ('minyak', 3)],
    seasonings: ['Bawang merah', 'Bawang putih', 'Air kaldu ayam'],
    steps: [
      'Rendam kacang hijau 2 jam, lalu rebus sampai empuk.',
      'Rebus ayam, lalu suwir/cincang halus.',
      'Masak bubur bersama kacang hijau, ayam, dan wortel parut sampai kental.',
      'Tambahkan minyak, aduk, sajikan hangat.',
    ],
    texture: 'Cincang halus (9–11 bulan), lebih kasar setelah 12 bulan',
    vitamins: 'A, B6, zat besi',
  ),
  Recipe(
    id: 'sup_telur_bayam',
    name: 'Sup Telur Bayam',
    description: 'Sup hangat kaya zat besi dan vitamin',
    minutes: 20,
    servings: 1,
    difficulty: 'Mudah',
    minMonths: 9,
    maxMonths: 24,
    ingredients: [('nasi', 60), ('telur', 50), ('bayam', 25), ('wortel', 15)],
    seasonings: ['Bawang putih', 'Air kaldu'],
    steps: [
      'Didihkan kaldu bersama wortel potong kecil.',
      'Masukkan bayam, lalu kocok telur dan tuang perlahan sambil diaduk.',
      'Masak sampai telur matang sempurna.',
      'Sajikan dengan nasi lembek.',
    ],
    texture: 'Sayur dicincang kecil, nasi lembek',
    vitamins: 'A, folat, zat besi',
  ),
  Recipe(
    id: 'nasi_tim_salmon',
    name: 'Nasi Tim Ikan Salmon',
    description: 'Nasi tim dengan ikan kaya omega-3',
    minutes: 40,
    servings: 2,
    difficulty: 'Sedang',
    minMonths: 9,
    maxMonths: 24,
    ingredients: [('nasi', 70), ('salmon', 30), ('brokoli', 20)],
    seasonings: ['Bawang bombay', 'Jahe sedikit'],
    steps: [
      'Campur nasi, air, dan bawang bombay cincang di mangkuk tahan panas.',
      'Letakkan salmon di atasnya, kukus 30 menit.',
      'Tambahkan brokoli cincang 10 menit terakhir.',
      'Suwir salmon, pastikan tidak ada duri, aduk rata.',
    ],
    texture: 'Cincang halus (9–11 bulan), lebih kasar setelah 12 bulan',
    vitamins: 'D, B12, omega-3',
  ),
  Recipe(
    id: 'telur_dadar_sayur',
    name: 'Telur Dadar Sayur Lembut',
    description: 'Finger food untuk melatih anak makan sendiri',
    minutes: 15,
    servings: 1,
    difficulty: 'Mudah',
    minMonths: 9,
    maxMonths: 24,
    ingredients: [('telur', 55), ('wortel', 15), ('tomat', 10), ('minyak', 3)],
    seasonings: ['Daun bawang'],
    steps: [
      'Kocok telur dengan wortel parut dan tomat cincang.',
      'Dadar dengan api kecil sampai matang merata.',
      'Potong memanjang seukuran jari anak.',
    ],
    texture: 'Potongan lunak seukuran jari',
    vitamins: 'A, B12, kolin',
  ),
  Recipe(
    id: 'nasi_tim_hati_tempe',
    name: 'Nasi Tim Hati Ayam & Tempe',
    description: 'Gabungan protein hewani dan nabati yang terjangkau',
    minutes: 35,
    servings: 2,
    difficulty: 'Sedang',
    minMonths: 12,
    maxMonths: 24,
    ingredients: [('nasi', 80), ('hati', 20), ('tempe', 20), ('bayam', 20), ('minyak', 3)],
    seasonings: ['Bawang merah', 'Bawang putih', 'Garam secukupnya (≥ 12 bulan, sedikit)'],
    steps: [
      'Tumis bawang dengan sedikit minyak.',
      'Masukkan hati ayam dan tempe potong dadu kecil, masak sampai matang.',
      'Kukus bersama nasi dan bayam sampai lembut.',
    ],
    texture: 'Makanan keluarga, dipotong kecil',
    vitamins: 'A, B12, zat besi',
  ),
  Recipe(
    id: 'puding_susu_buah',
    name: 'Puding Susu Buah',
    description: 'Dessert sehat dengan kalsium tinggi',
    minutes: 20,
    servings: 2,
    difficulty: 'Mudah',
    minMonths: 12,
    maxMonths: 24,
    ingredients: [('susu', 100), ('pisang', 30), ('pepaya', 30)],
    seasonings: ['Agar-agar tawar', 'Tanpa gula tambahan'],
    steps: [
      'Larutkan agar-agar dalam susu, masak sambil diaduk sampai mendidih.',
      'Tuang ke cetakan, biarkan setengah dingin.',
      'Tambahkan potongan pisang dan pepaya, dinginkan sampai set.',
    ],
    texture: 'Lembut, buah dipotong kecil',
    vitamins: 'A, C, kalsium',
  ),
];

Recipe recipeById(String id) => recipes.firstWhere((r) => r.id == id);

/// Kandungan gizi satu porsi, dihitung dari bahan memakai tabel pangan.
NutrientTotal recipeNutrients(Recipe r) => r.ingredients.fold(
      const NutrientTotal(),
      (a, i) {
        final f = foodById(i.$1);
        final k = i.$2 / 100;
        return a + NutrientTotal(kcal: f.kcal * k, protein: f.protein * k, carb: f.carb * k, fat: f.fat * k, fiber: f.fiber * k);
      },
    );

/// Resep yang teksturnya sesuai usia anak. Bayi < 6 bulan: kosong (ASI eksklusif).
List<Recipe> recipesForAge(double ageMonths) {
  if (needsExclusiveBreastfeeding(ageMonths)) return const [];
  final m = ageMonths.floor();
  return recipes.where((r) => m >= r.minMonths && m <= r.maxMonths).toList();
}
