import '../models.dart';

/// DRAF — nilai gizi per 100 g adalah perkiraan dari tabel komposisi pangan
/// umum dan harus diverifikasi dengan Tabel Komposisi Pangan Indonesia (TKPI)
/// sebelum dipakai di luar prototype.
const foods = <Food>[
  Food(id: 'nasi', name: 'Nasi putih', group: 'Karbohidrat', kcal: 180, protein: 3.0, carb: 39.8, fat: 0.3, fiber: 0.2),
  Food(id: 'bubur', name: 'Bubur nasi', group: 'Karbohidrat', kcal: 72, protein: 1.2, carb: 15.8, fat: 0.2, fiber: 0.1),
  Food(id: 'kentang', name: 'Kentang rebus', group: 'Karbohidrat', kcal: 83, protein: 2.0, carb: 19.0, fat: 0.1, fiber: 1.8),
  Food(id: 'ubi', name: 'Ubi jalar kukus', group: 'Karbohidrat', kcal: 86, protein: 1.6, carb: 20.1, fat: 0.1, fiber: 3.0),
  Food(id: 'oat', name: 'Oatmeal (dimasak)', group: 'Karbohidrat', kcal: 71, protein: 2.5, carb: 12.0, fat: 1.5, fiber: 1.7),
  Food(id: 'telur', name: 'Telur ayam rebus', group: 'Protein hewani', kcal: 155, protein: 12.6, carb: 1.1, fat: 10.6, fiber: 0, animalProtein: true),
  Food(id: 'hati', name: 'Hati ayam (dimasak)', group: 'Protein hewani', kcal: 167, protein: 24.5, carb: 0.9, fat: 6.5, fiber: 0, animalProtein: true),
  Food(id: 'ayam', name: 'Daging ayam tanpa kulit (rebus)', group: 'Protein hewani', kcal: 165, protein: 31.0, carb: 0, fat: 3.6, fiber: 0, animalProtein: true),
  Food(id: 'sapi', name: 'Daging sapi (rebus)', group: 'Protein hewani', kcal: 217, protein: 26.0, carb: 0, fat: 12.0, fiber: 0, animalProtein: true),
  Food(id: 'ikan', name: 'Ikan kembung (kukus)', group: 'Protein hewani', kcal: 112, protein: 21.0, carb: 0, fat: 3.4, fiber: 0, animalProtein: true),
  Food(id: 'lele', name: 'Ikan lele (kukus)', group: 'Protein hewani', kcal: 105, protein: 18.0, carb: 0, fat: 3.5, fiber: 0, animalProtein: true),
  Food(id: 'salmon', name: 'Ikan salmon (kukus)', group: 'Protein hewani', kcal: 206, protein: 22.0, carb: 0, fat: 12.4, fiber: 0, animalProtein: true),
  Food(id: 'udang', name: 'Udang rebus', group: 'Protein hewani', kcal: 99, protein: 24.0, carb: 0.2, fat: 0.3, fiber: 0, animalProtein: true),
  Food(id: 'tempe', name: 'Tempe kukus', group: 'Protein nabati', kcal: 201, protein: 20.8, carb: 13.5, fat: 8.8, fiber: 1.4),
  Food(id: 'tahu', name: 'Tahu kukus', group: 'Protein nabati', kcal: 80, protein: 10.9, carb: 0.8, fat: 4.7, fiber: 0.1),
  Food(id: 'kachijau', name: 'Kacang hijau rebus', group: 'Protein nabati', kcal: 105, protein: 7.0, carb: 19.0, fat: 0.4, fiber: 7.6),
  Food(id: 'bayam', name: 'Bayam rebus', group: 'Sayur', kcal: 23, protein: 3.0, carb: 3.8, fat: 0.3, fiber: 2.4),
  Food(id: 'wortel', name: 'Wortel rebus', group: 'Sayur', kcal: 35, protein: 0.8, carb: 8.2, fat: 0.2, fiber: 3.0),
  Food(id: 'brokoli', name: 'Brokoli rebus', group: 'Sayur', kcal: 35, protein: 2.4, carb: 7.2, fat: 0.4, fiber: 3.3),
  Food(id: 'labu', name: 'Labu kuning kukus', group: 'Sayur', kcal: 20, protein: 0.7, carb: 4.9, fat: 0.1, fiber: 1.1),
  Food(id: 'timun', name: 'Mentimun', group: 'Sayur', kcal: 15, protein: 0.7, carb: 3.6, fat: 0.1, fiber: 0.5),
  Food(id: 'tomat', name: 'Tomat', group: 'Sayur', kcal: 18, protein: 0.9, carb: 3.9, fat: 0.2, fiber: 1.2),
  Food(id: 'pisang', name: 'Pisang', group: 'Buah', kcal: 89, protein: 1.1, carb: 22.8, fat: 0.3, fiber: 2.6),
  Food(id: 'pepaya', name: 'Pepaya', group: 'Buah', kcal: 43, protein: 0.5, carb: 10.8, fat: 0.3, fiber: 1.7),
  Food(id: 'alpukat', name: 'Alpukat', group: 'Buah', kcal: 160, protein: 2.0, carb: 8.5, fat: 14.7, fiber: 6.7),
  Food(id: 'jeruk', name: 'Jeruk', group: 'Buah', kcal: 47, protein: 0.9, carb: 11.8, fat: 0.1, fiber: 2.4),
  Food(id: 'asi', name: 'ASI (per 100 ml)', group: 'Susu & olahan', kcal: 70, protein: 1.0, carb: 6.9, fat: 4.4, fiber: 0, animalProtein: true),
  Food(id: 'susu', name: 'Susu sapi UHT full cream', group: 'Susu & olahan', kcal: 61, protein: 3.2, carb: 4.8, fat: 3.3, fiber: 0, animalProtein: true),
  Food(id: 'yogurt', name: 'Yogurt plain', group: 'Susu & olahan', kcal: 61, protein: 3.5, carb: 4.7, fat: 3.3, fiber: 0, animalProtein: true),
  Food(id: 'minyak', name: 'Minyak sayur / santan (lemak tambahan MPASI)', group: 'Lemak tambahan', kcal: 884, protein: 0, carb: 0, fat: 100, fiber: 0),
];

Food foodById(String id) => foods.firstWhere((f) => f.id == id);
