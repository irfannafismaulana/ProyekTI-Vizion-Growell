import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growell/core/nutrition.dart';
import 'package:growell/core/quiz_rules.dart';
import 'package:growell/data/quiz_bank.dart';
import 'package:growell/models.dart';
import 'package:growell/state/providers.dart';

void main() {
  group('ER-4.2 / TC-03: pembatasan jawaban medis', () {
    late ProviderContainer c;
    late UsersNotifier users;
    setUp(() {
      c = ProviderContainer();
      users = c.read(usersProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('orang tua bertanya, dokter terverifikasi menjawab', () {
      final consult = c.read(consultProvider.notifier);
      final t = consult.openThread(parent: users.byId('u_rani'), doctorId: 'u_budi');
      consult.send(sender: users.byId('u_rani'), threadId: t.id, text: 'Halo dok');
      consult.send(sender: users.byId('u_budi'), threadId: t.id, text: 'Halo bu');
      expect(c.read(consultProvider).firstWhere((x) => x.id == t.id).messages, hasLength(2));
    });

    test('akun non-nakes (remaja) ditolak saat menjawab', () {
      final consult = c.read(consultProvider.notifier);
      expect(() => consult.send(sender: users.byId('u_dina'), threadId: 't_seed', text: 'Jawaban'), throwsA(isA<AccessDenied>()));
    });

    test('nakes yang STR-nya belum diverifikasi ditolak', () {
      final consult = c.read(consultProvider.notifier);
      expect(() => consult.send(sender: users.byId('u_candra'), threadId: 't_seed', text: 'Jawaban'), throwsA(isA<AccessDenied>()));
    });

    test('dokter lain (bukan yang dipilih) ditolak', () {
      final consult = c.read(consultProvider.notifier);
      expect(() => consult.send(sender: users.byId('u_irfan'), threadId: 't_seed', text: 'Jawaban'), throwsA(isA<AccessDenied>()));
    });

    test('hanya admin yang dapat memverifikasi STR', () {
      expect(() => users.verifyHealthWorker(actor: users.byId('u_rani'), userId: 'u_candra'), throwsA(isA<AccessDenied>()));
      users.verifyHealthWorker(actor: users.byId('u_admin'), userId: 'u_candra');
      expect(users.byId('u_candra').verified, isTrue);
    });
  });

  group('Kuis (ER-7.1, 7.2, 7.5)', () {
    test('kode room 6 karakter', () {
      final code = generateRoomCode(math.Random(1));
      expect(code, hasLength(6));
    });
    test('validasi pengaturan room master', () {
      expect(const QuizSettings(questionCount: 4).validate(), isNotNull);
      expect(const QuizSettings(secondsPerQuestion: 31).validate(), isNotNull);
      expect(const QuizSettings().validate(), isNull);
    });
    test('poin: benar = 500 + bonus kecepatan, salah = 0', () {
      expect(pointsFor(correct: true, secondsLeft: 20, duration: 20), 1000);
      expect(pointsFor(correct: true, secondsLeft: 0, duration: 20), 500);
      expect(pointsFor(correct: false, secondsLeft: 20, duration: 20), 0);
    });
    test('soal sesuai kategori & kesulitan room (100% soal)', () {
      final qs = selectQuestions(
        bank: quizBank,
        settings: const QuizSettings(difficulty: Difficulty.mudah, category: QuizCategory.remaja, questionCount: 5),
        playerProfiles: const [QuizCategory.remaja],
        rng: math.Random(2),
      );
      expect(qs, hasLength(5));
      expect(qs.every((q) => q.category == QuizCategory.remaja && q.difficulty == Difficulty.mudah), isTrue);
    });
  });

  group('Gizi (ER-2.2, ER-2.3)', () {
    test('AKG sesuai kelompok umur Permenkes 28/2019', () {
      expect(akgForAgeMonths(3).kcal, 550);
      expect(akgForAgeMonths(8).kcal, 800);
      expect(akgForAgeMonths(18).kcal, 1350);
    });
    test('minimal 3 rekomendasi protein tinggi, protein hewani didahulukan', () {
      final r = proteinRecommendations();
      expect(r, hasLength(3));
      expect(r.every((f) => f.highProtein && f.animalProtein), isTrue);
    });
    test('bayi < 6 bulan diarahkan ke ASI eksklusif', () {
      expect(needsExclusiveBreastfeeding(5.9), isTrue);
      expect(needsExclusiveBreastfeeding(6.0), isFalse);
    });
  });
}
