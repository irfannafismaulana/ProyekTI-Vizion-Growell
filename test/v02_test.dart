import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growell/core/nutrition.dart';
import 'package:growell/core/status.dart';
import 'package:growell/core/zscore.dart';
import 'package:growell/data/recipes.dart';
import 'package:growell/models.dart';
import 'package:growell/state/providers.dart';
import 'package:growell/ui/assistant_page.dart';

GrowthResult _r(double h, double w, double? wh) =>
    GrowthResult(ageDays: 200, zHeightForAge: h, zWeightForAge: w, zWeightForHeight: wh);

void main() {
  group('Status warna Beranda (Normal/Waspada/Kurang)', () {
    test('batas -2 SD sama dengan peringatan stunting (TC-02)', () {
      expect(statusOf(_r(-2.0, 0, 0)).status, GrowthStatus.waspada, reason: '-2,00 belum Kurang');
      expect(statusOf(_r(-2.01, 0, 0)).status, GrowthStatus.kurang);
      expect(statusOf(_r(-2.004, 0, 0)).status, GrowthStatus.waspada, reason: 'dibulatkan ke -2,00');
    });
    test('indikator mana pun < -2 SD → Kurang, dengan alasan', () {
      final s = statusOf(_r(0, -2.5, 0));
      expect(s.status, GrowthStatus.kurang);
      expect(s.reasons.single, contains('berat badan'));
      expect(statusOf(_r(0, 0, -2.2)).status, GrowthStatus.kurang);
    });
    test('-2 s.d. -1 SD → Waspada; normal di atasnya', () {
      expect(statusOf(_r(-1.5, 0, 0)).status, GrowthStatus.waspada);
      expect(statusOf(_r(-1.0, -0.5, 0.5)).status, GrowthStatus.normal);
    });
    test('BB/TB > +1 berisiko gizi lebih (Waspada), > +2 gizi lebih', () {
      expect(statusOf(_r(0, 0, 1.5)).status, GrowthStatus.waspada);
      expect(statusOf(_r(0, 0, 2.5)).status, GrowthStatus.lebih);
    });
    test('BB/TB tidak tersedia (di luar 45–110 cm) tidak membuat error', () {
      expect(statusOf(_r(0, 0, null)).status, GrowthStatus.normal);
    });
  });

  group('Data contoh Abiyu (persona desain)', () {
    test('status terakhir Kurang (risiko stunting), sebelumnya Waspada', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ms = c.read(childMeasurementsProvider('c_abiyu'));
      expect(ms, hasLength(6));
      expect(statusOf(ms.first.result).status, GrowthStatus.waspada);
      expect(statusOf(ms.last.result).status, GrowthStatus.kurang);
      expect(ms.last.result.stuntingRisk, isTrue);
      expect(c.read(nextAppointmentProvider('c_abiyu')), isNotNull, reason: 'banner jadwal kontrol');
    });
  });

  group('Simulasi estimasi dari foto', () {
    test('mempertahankan z-score terakhir pada umur sekarang', () {
      final birth = DateTime(2025, 1, 1);
      final last = assess(sex: Sex.male, birthDate: birth, measuredAt: DateTime(2025, 6, 1), weightKg: 6.5, heightCm: 62.3);
      final (h, w) = simulatePhotoEstimate(sex: Sex.male, ageDaysNow: 200, last: last);
      final now = assess(sex: Sex.male, birthDate: birth, measuredAt: birth.add(const Duration(days: 200)), weightKg: w, heightCm: h);
      expect(now.zHeightForAge, closeTo(last.zHeightForAge, 0.05));
      expect(now.zWeightForAge, closeTo(last.zWeightForAge, 0.1));
    });
    test('tanpa riwayat → median WHO', () {
      final (h, w) = simulatePhotoEstimate(sex: Sex.female, ageDaysNow: 0);
      expect(h, closeTo(49.1, 0.1));
      expect(w, closeTo(3.2, 0.1));
    });
  });

  group('Resep', () {
    test('gizi dihitung dari bahan, bukan diketik', () {
      final r = recipeById('bubur_ayam_kacang_hijau');
      final n = recipeNutrients(r);
      expect(n.kcal, greaterThan(100));
      expect(n.protein, greaterThan(8));
    });
    test('setiap resep MPASI memuat protein hewani kecuali selingan buah', () {
      for (final r in recipes.where((r) => r.id != 'puree_pisang_alpukat')) {
        expect(r.ingredients.any((i) => const {'telur', 'hati', 'ayam', 'ikan', 'salmon', 'susu'}.contains(i.$1)), isTrue, reason: r.name);
      }
    });
    test('filter usia: < 6 bulan kosong, 6 bulan hanya tekstur lumat, susu sapi ≥ 12 bulan', () {
      expect(recipesForAge(5.9), isEmpty);
      final six = recipesForAge(6.5);
      expect(six, isNotEmpty);
      expect(six.every((r) => r.minMonths <= 6), isTrue);
      expect(recipesForAge(10).any((r) => r.ingredients.any((i) => i.$1 == 'susu')), isFalse);
      expect(recipesForAge(13).any((r) => r.id == 'puding_susu_buah'), isTrue);
    });
    test('target energi MPASI (WHO) per kelompok umur', () {
      expect(mpasiEnergyTarget(5), isNull);
      expect(mpasiEnergyTarget(7), 200);
      expect(mpasiEnergyTarget(10), 300);
      expect(mpasiEnergyTarget(18), 550);
    });
  });

  group('Catatan konsultasi & jadwal kontrol (ER-4.2)', () {
    late ProviderContainer c;
    late UsersNotifier users;
    setUp(() {
      c = ProviderContainer();
      users = c.read(usersProvider.notifier);
    });
    tearDown(() => c.dispose());

    ConsultNote write(String actor) => c.read(consultNotesProvider.notifier).add(
          actor: users.byId(actor),
          threadId: 't_seed',
          childId: 'c_abiyu',
          title: 'Kontrol',
          keterangan: 'k',
          diagnosis: 'd',
          anjuran: 'a',
          catatan: 'c',
        );

    test('dokter yang menangani boleh menulis catatan', () {
      final n = write('u_sarah');
      expect(n.parentId, 'u_rani');
      expect(c.read(consultNotesProvider), hasLength(2));
    });
    test('dokter lain, nakes belum terverifikasi, dan orang tua ditolak', () {
      expect(() => write('u_irfan'), throwsA(isA<AccessDenied>()));
      expect(() => write('u_candra'), throwsA(isA<AccessDenied>()));
      expect(() => write('u_rani'), throwsA(isA<AccessDenied>()));
    });
    test('jadwal kontrol hanya oleh nakes terverifikasi, tidak di masa lalu', () {
      final ap = c.read(appointmentsProvider.notifier);
      final next = DateTime.now().add(const Duration(days: 2));
      expect(() => ap.schedule(actor: users.byId('u_rani'), childId: 'c_abiyu', date: next), throwsA(isA<AccessDenied>()));
      expect(() => ap.schedule(actor: users.byId('u_sarah'), childId: 'c_abiyu', date: DateTime(2020)), throwsArgumentError);
      ap.schedule(actor: users.byId('u_sarah'), childId: 'c_abiyu', date: next);
      expect(c.read(nextAppointmentProvider('c_abiyu'))!.date, next, reason: 'jadwal terdekat menggantikan yang 5 hari lagi');
    });
  });

  group('Gizi harian', () {
    test('menyimpan beberapa makanan sekaligus; porsi tidak wajar ditolak', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final log = c.read(foodLogProvider.notifier);
      final before = c.read(foodLogProvider).length;
      final d = DateTime.now();
      FoodEntry e(double g) => FoodEntry(id: newId('f'), childId: 'c_abiyu', date: d, meal: Meal.siang, foodId: 'telur', grams: g);
      expect(() => log.addAll([e(30), e(0)]), throwsArgumentError);
      expect(c.read(foodLogProvider).length, before, reason: 'tidak ada yang tersimpan sebagian');
      log.addAll([e(30), e(20)]);
      expect(c.read(foodLogProvider).length, before + 2);
    });
  });

  group('Asisten gizi (simulasi)', () {
    test('gejala darurat diarahkan ke tenaga kesehatan', () {
      final r = answerQuestion('anak saya demam tinggi dan kejang');
      expect(r.text, contains('IGD'));
      expect(r.route, '/app?tab=2');
    });
    test('pertanyaan MPASI untuk bayi < 6 bulan menyarankan ASI saja', () {
      final c = Child(id: 'x', parentId: 'p', name: 'Bayi', sex: Sex.male,
          birthDate: DateTime.now().subtract(const Duration(days: 100)), posyandu: '-', region: '-');
      expect(answerQuestion('menu mpasi apa?', child: c).text, contains('belum 6 bulan'));
    });
  });
}
