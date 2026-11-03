import 'package:flutter_test/flutter_test.dart';
import 'package:growell/core/zscore.dart';

import 'who_fixtures.dart';

void main() {
  Indicator ind(String s) => switch (s) {
        'lhfa' => Indicator.heightForAge,
        'wfa' => Indicator.weightForAge,
        _ => Indicator.weightForHeight,
      };

  group('ER-1.1 / TC-01: z-score cocok dengan tabel resmi WHO (selisih ≤ 0,01)', () {
    for (final f in whoFixtures) {
      final i = ind(f['ind']! as String);
      final sex = f['sex'] == 'boys' ? Sex.male : Sex.female;
      final x = (f['x']! as num).toDouble();
      test('${f['ind']} ${f['sex']} x=$x', () {
        for (final (key, expected) in [
          ('sd3neg', -3.0),
          ('sd2neg', -2.0),
          ('sd0', 0.0),
          ('sd2', 2.0),
          ('sd3', 3.0),
        ]) {
          final value = (f[key]! as num).toDouble();
          expect(zScore(i, sex, x, value), closeTo(expected, 0.01),
              reason: '$key = $value');
        }
      });
    }
  });

  group('ER-1.3 / TC-02: ambang peringatan stunting', () {
    test('z = -2,00 tidak memicu peringatan', () {
      expect(isStuntingRisk(-2.0), isFalse);
    });
    test('z = -2,01 memicu peringatan', () {
      expect(isStuntingRisk(-2.01), isTrue);
    });
    test('TB tepat di -2 SD (anak laki-laki 12 bulan) → status normal', () {
      final lms = lmsFor(Indicator.heightForAge, Sex.male, 365);
      final z = zScore(Indicator.heightForAge, Sex.male, 365, lms.valueAt(-2));
      expect(z, closeTo(-2.0, 1e-9));
      expect(classify(Indicator.heightForAge, z).label, 'Normal');
    });
    test('TB di bawah -2 SD → pendek dan berisiko', () {
      final r = assess(
        sex: Sex.female,
        birthDate: DateTime(2025, 1, 1),
        measuredAt: DateTime(2026, 1, 1),
        weightKg: 8.0,
        heightCm: 68.0,
      );
      expect(r.stuntingRisk, isTrue);
      expect(classify(Indicator.heightForAge, r.zHeightForAge).level, greaterThanOrEqualTo(2));
    });
  });

  test('Umur di atas 24 bulan ditolak (Batasan target pemantauan)', () {
    expect(
      () => assess(
        sex: Sex.male,
        birthDate: DateTime(2023, 1, 1),
        measuredAt: DateTime(2026, 1, 1),
        weightKg: 13,
        heightCm: 92,
      ),
      throwsRangeError,
    );
  });
}
