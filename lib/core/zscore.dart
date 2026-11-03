import 'dart:math' as math;

import '../data/who_lms.dart';

/// Jenis kelamin anak, dipakai untuk memilih tabel WHO.
enum Sex { male, female }

/// Indikator antropometri yang dipakai GroWell (ER-1.1).
enum Indicator {
  /// Tinggi/panjang badan menurut umur (dasar penentuan stunting).
  heightForAge,

  /// Berat badan menurut umur.
  weightForAge,

  /// Berat badan menurut tinggi/panjang badan.
  weightForHeight,
}

extension IndicatorLabel on Indicator {
  String get short => switch (this) {
        Indicator.heightForAge => 'TB/U',
        Indicator.weightForAge => 'BB/U',
        Indicator.weightForHeight => 'BB/TB',
      };
}

/// Cakupan pemantauan sesuai Batasan SRS: baduta 0–24 bulan.
const int maxAgeDays = 731;
const double minLengthCm = 45.0;
const double maxLengthCm = 110.0;

class Lms {
  const Lms(this.l, this.m, this.s);
  final double l;
  final double m;
  final double s;

  /// Nilai pengukuran pada z tertentu (kebalikan rumus LMS).
  double valueAt(double z) =>
      l == 0 ? m * math.exp(s * z) : m * math.pow(1 + l * s * z, 1 / l);
}

Lms _row(List<double> t, int i) => Lms(t[i * 3], t[i * 3 + 1], t[i * 3 + 2]);

List<double> _table(Indicator ind, Sex sex) => switch ((ind, sex)) {
      (Indicator.heightForAge, Sex.male) => whoLhfaBoys,
      (Indicator.heightForAge, Sex.female) => whoLhfaGirls,
      (Indicator.weightForAge, Sex.male) => whoWfaBoys,
      (Indicator.weightForAge, Sex.female) => whoWfaGirls,
      (Indicator.weightForHeight, Sex.male) => whoWflBoys,
      (Indicator.weightForHeight, Sex.female) => whoWflGirls,
    };

/// Parameter LMS untuk umur (hari) atau panjang badan (cm).
/// Umur memakai tabel harian WHO; panjang badan diinterpolasi linear antar 0,1 cm.
Lms lmsFor(Indicator ind, Sex sex, double x) {
  final t = _table(ind, sex);
  final n = t.length ~/ 3;
  if (ind == Indicator.weightForHeight) {
    final pos = (x - minLengthCm) * 10;
    if (pos < 0 || pos > n - 1) {
      throw RangeError('Panjang badan $x cm di luar tabel WHO (45–110 cm)');
    }
    final i = pos.floor();
    final f = pos - i;
    if (f < 1e-9 || i >= n - 1) return _row(t, i);
    final a = _row(t, i), b = _row(t, i + 1);
    double lerp(double p, double q) => p + (q - p) * f;
    return Lms(lerp(a.l, b.l), lerp(a.m, b.m), lerp(a.s, b.s));
  }
  final day = x.round();
  if (day < 0 || day >= n) {
    throw RangeError('Umur $day hari di luar cakupan 0–$maxAgeDays hari');
  }
  return _row(t, day);
}

/// Z-score metode LMS WHO. Untuk indikator berbasis berat (BB/U, BB/TB),
/// nilai di luar ±3 SD memakai koreksi WHO (restricted application of LMS).
double zScore(Indicator ind, Sex sex, double x, double value) {
  final p = lmsFor(ind, sex, x);
  final z = p.l == 0
      ? math.log(value / p.m) / p.s
      : (math.pow(value / p.m, p.l) - 1) / (p.l * p.s);
  if (ind == Indicator.heightForAge || z.abs() <= 3) return z;
  if (z > 3) {
    final sd3 = p.valueAt(3), sd23 = sd3 - p.valueAt(2);
    return 3 + (value - sd3) / sd23;
  }
  final sd3neg = p.valueAt(-3), sd23neg = p.valueAt(-2) - sd3neg;
  return -3 + (value - sd3neg) / sd23neg;
}

/// Klasifikasi status gizi menurut Permenkes No. 2 Tahun 2020.
class Classification {
  const Classification(this.label, this.level);
  final String label;

  /// 0 = normal, 1 = perlu perhatian, 2 = berisiko, 3 = berat.
  final int level;
}

/// Z-score dilaporkan 2 desimal (seperti WHO Anthro) agar nilai batas seperti
/// -2,00 tidak bergeser akibat galat floating point.
double roundZ(double z) => (z * 100).roundToDouble() / 100;

Classification classify(Indicator ind, double rawZ) {
  final z = roundZ(rawZ);
  switch (ind) {
    case Indicator.heightForAge:
      if (z < -3) return const Classification('Sangat pendek (severely stunted)', 3);
      if (z < -2) return const Classification('Pendek (stunted)', 2);
      if (z <= 3) return const Classification('Normal', 0);
      return const Classification('Tinggi', 1);
    case Indicator.weightForAge:
      if (z < -3) return const Classification('Berat badan sangat kurang', 3);
      if (z < -2) return const Classification('Berat badan kurang', 2);
      if (z <= 1) return const Classification('Berat badan normal', 0);
      return const Classification('Risiko berat badan lebih', 1);
    case Indicator.weightForHeight:
      if (z < -3) return const Classification('Gizi buruk', 3);
      if (z < -2) return const Classification('Gizi kurang', 2);
      if (z <= 1) return const Classification('Gizi baik (normal)', 0);
      if (z <= 2) return const Classification('Berisiko gizi lebih', 1);
      if (z <= 3) return const Classification('Gizi lebih', 2);
      return const Classification('Obesitas', 3);
  }
}

/// ER-1.3: peringatan risiko stunting bila z-score TB/U < -2 SD.
/// Tepat -2,00 tidak memicu peringatan (sesuai TC-02 langkah 3).
bool isStuntingRisk(double heightForAgeZ) => roundZ(heightForAgeZ) < -2;

/// Umur dalam hari penuh antara tanggal lahir dan tanggal ukur.
int ageInDays(DateTime birth, DateTime measured) {
  final b = DateTime.utc(birth.year, birth.month, birth.day);
  final m = DateTime.utc(measured.year, measured.month, measured.day);
  return m.difference(b).inDays;
}

/// Hasil lengkap satu pengukuran.
class GrowthResult {
  const GrowthResult({
    required this.ageDays,
    required this.zHeightForAge,
    required this.zWeightForAge,
    required this.zWeightForHeight,
  });

  final int ageDays;
  final double zHeightForAge;
  final double zWeightForAge;

  /// Null bila panjang badan di luar tabel BB/TB WHO (45–110 cm).
  final double? zWeightForHeight;

  bool get stuntingRisk => isStuntingRisk(zHeightForAge);
}

/// Hitung ketiga indikator. Melempar [RangeError] bila umur di luar 0–24 bulan.
GrowthResult assess({
  required Sex sex,
  required DateTime birthDate,
  required DateTime measuredAt,
  required double weightKg,
  required double heightCm,
}) {
  final days = ageInDays(birthDate, measuredAt);
  if (days < 0 || days > maxAgeDays) {
    throw RangeError('Umur anak di luar cakupan pemantauan 0–24 bulan');
  }
  final d = days.toDouble();
  double? wfh;
  if (heightCm >= minLengthCm && heightCm <= maxLengthCm) {
    wfh = zScore(Indicator.weightForHeight, sex, heightCm, weightKg);
  }
  return GrowthResult(
    ageDays: days,
    zHeightForAge: zScore(Indicator.heightForAge, sex, d, heightCm),
    zWeightForAge: zScore(Indicator.weightForAge, sex, d, weightKg),
    zWeightForHeight: wfh,
  );
}
