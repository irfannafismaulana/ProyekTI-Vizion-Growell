import 'dart:math' as math;

import '../models.dart';

class QuizSettings {
  const QuizSettings({
    this.difficulty = Difficulty.sedang,
    this.category = QuizCategory.campuran,
    this.questionCount = 5,
    this.secondsPerQuestion = 20,
  });

  final Difficulty difficulty;
  final QuizCategory category;

  /// ER-7.2: 5–20 soal, 10–30 detik per soal.
  final int questionCount;
  final int secondsPerQuestion;

  String? validate() {
    if (questionCount < 5 || questionCount > 20) return 'Jumlah soal harus 5–20.';
    if (secondsPerQuestion < 10 || secondsPerQuestion > 30) return 'Durasi per soal harus 10–30 detik.';
    return null;
  }
}

/// ER-7.5: benar = 500 poin dasar + bonus kecepatan hingga 500; salah/tidak menjawab = 0.
int pointsFor({required bool correct, required double secondsLeft, required int duration}) {
  if (!correct) return 0;
  final ratio = (secondsLeft / duration).clamp(0.0, 1.0);
  return 500 + (500 * ratio).round();
}

/// Kode room 6 karakter tanpa huruf/angka yang mudah tertukar (ER-7.1).
String generateRoomCode(math.Random rng) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
}

/// Memilih soal sesuai pengaturan room master (ER-7.2). Pada room campuran,
/// kategori diambil bergiliran dari profil pemain yang hadir.
List<Question> selectQuestions({
  required List<Question> bank,
  required QuizSettings settings,
  required List<QuizCategory> playerProfiles,
  required math.Random rng,
}) {
  final cats = settings.category == QuizCategory.campuran
      ? ({...playerProfiles.where((c) => c != QuizCategory.campuran), QuizCategory.umum}).toList()
      : [settings.category];
  final pools = {
    for (final c in cats)
      c: bank.where((q) => q.category == c && q.difficulty == settings.difficulty).toList()..shuffle(rng),
  };
  final chosen = <Question>[];
  var i = 0;
  while (chosen.length < settings.questionCount && pools.values.any((p) => p.isNotEmpty)) {
    final pool = pools[cats[i % cats.length]]!;
    if (pool.isNotEmpty) chosen.add(pool.removeLast());
    i++;
  }
  if (chosen.length < settings.questionCount) {
    // Bank soal draf belum 100 soal: lengkapi dari tingkat kesulitan lain pada kategori yang sama.
    final extra = bank.where((q) => cats.contains(q.category) && !chosen.contains(q)).toList()..shuffle(rng);
    chosen.addAll(extra.take(settings.questionCount - chosen.length));
  }
  return chosen;
}
