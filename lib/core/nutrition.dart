import '../data/foods.dart';
import '../models.dart';

/// Angka Kecukupan Gizi per hari, Permenkes No. 28 Tahun 2019.
/// Untuk bayi dan anak 1–3 tahun AKG tidak dibedakan menurut jenis kelamin.
class Akg {
  const Akg(this.group, this.kcal, this.protein, this.carb, this.fat, this.fiber);
  final String group;
  final double kcal;
  final double protein;
  final double carb;
  final double fat;
  final double fiber;
}

const akgInfant0to5 = Akg('Bayi 0–5 bulan', 550, 9, 59, 31, 0);
const akgInfant6to11 = Akg('Bayi 6–11 bulan', 800, 15, 105, 35, 11);
const akgToddler1to3 = Akg('Anak 1–3 tahun', 1350, 20, 215, 45, 19);

Akg akgForAgeMonths(double months) {
  if (months < 6) return akgInfant0to5;
  if (months < 12) return akgInfant6to11;
  return akgToddler1to3;
}

/// Bayi < 6 bulan diarahkan ke edukasi ASI eksklusif, bukan pencatatan makanan.
bool needsExclusiveBreastfeeding(double ageMonths) => ageMonths < 6;

class NutrientTotal {
  const NutrientTotal({this.kcal = 0, this.protein = 0, this.carb = 0, this.fat = 0, this.fiber = 0});
  final double kcal;
  final double protein;
  final double carb;
  final double fat;
  final double fiber;

  NutrientTotal operator +(NutrientTotal o) => NutrientTotal(
        kcal: kcal + o.kcal,
        protein: protein + o.protein,
        carb: carb + o.carb,
        fat: fat + o.fat,
        fiber: fiber + o.fiber,
      );
}

NutrientTotal nutrientsOf(FoodEntry e) {
  final f = foodById(e.foodId);
  final k = e.grams / 100;
  return NutrientTotal(
    kcal: f.kcal * k,
    protein: f.protein * k,
    carb: f.carb * k,
    fat: f.fat * k,
    fiber: f.fiber * k,
  );
}

NutrientTotal totalOf(Iterable<FoodEntry> entries) =>
    entries.fold(const NutrientTotal(), (a, e) => a + nutrientsOf(e));

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// ER-2.2: minimal 3 rekomendasi makanan berprotein tinggi; protein hewani
/// didahulukan karena paling berkaitan dengan pencegahan stunting.
List<Food> proteinRecommendations({int count = 3, Set<String> exclude = const {}}) {
  final list = foods.where((f) => f.highProtein && !exclude.contains(f.id)).toList()
    ..sort((a, b) {
      if (a.animalProtein != b.animalProtein) return a.animalProtein ? -1 : 1;
      return b.protein.compareTo(a.protein);
    });
  return list.take(count).toList();
}

/// Perkiraan kebutuhan energi dari MPASI untuk anak yang masih menyusu
/// (WHO/PAHO, Guiding Principles for Complementary Feeding of the Breastfed Child, 2003):
/// 6–8 bulan ±200 kkal, 9–11 bulan ±300 kkal, 12–23 bulan ±550 kkal per hari.
/// Sisanya dipenuhi ASI, yang tidak dicatat di aplikasi. Null bila < 6 bulan.
double? mpasiEnergyTarget(double ageMonths) {
  if (ageMonths < 6) return null;
  if (ageMonths < 9) return 200;
  if (ageMonths < 12) return 300;
  return 550;
}
