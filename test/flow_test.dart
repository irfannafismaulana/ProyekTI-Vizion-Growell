import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growell/app.dart';
import 'package:growell/core/quiz_rules.dart';
import 'package:growell/models.dart';
import 'package:growell/state/providers.dart';
import 'package:growell/state/quiz_engine.dart';

void main() {
  testWidgets('Login demo per peran membuka menu sesuai hak akses', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: GroWellApp()));
    await tester.pumpAndSettle();
    expect(find.text('Masuk Ke Growell'), findsOneWidget);

    await tester.tap(find.text('Remaja'));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Dina 👋'), findsOneWidget);
    expect(find.text('Konsultasi'), findsNothing, reason: 'remaja tidak punya menu konsultasi');
    expect(find.text('Kuis'), findsOneWidget);
  });

  testWidgets('Nakes belum terverifikasi diarahkan ke halaman menunggu verifikasi', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: GroWellApp()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nakes belum terverifikasi'));
    await tester.tap(find.text('Nakes belum terverifikasi'));
    await tester.pumpAndSettle();
    expect(find.text('Menunggu verifikasi STR'), findsOneWidget);
  });

  testWidgets('TC-04 (simulasi lokal): satu permainan kuis penuh', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final users = c.read(usersProvider.notifier);
    final engine = c.read(quizProvider.notifier);
    final me = users.byId('u_rani');

    expect(engine.createRoom(me: me, settings: const QuizSettings(difficulty: Difficulty.mudah, category: QuizCategory.orangTua, questionCount: 5, secondsPerQuestion: 10)), isNull);
    var s = c.read(quizProvider)!;
    expect(s.code, hasLength(6));
    expect(engine.start(), isNotNull, reason: 'belum ada pemain lain, minimal 2 pemain');

    await tester.pump(const Duration(milliseconds: 1300)); // bot pertama bergabung
    expect(c.read(quizProvider)!.players.length, greaterThanOrEqualTo(2));
    expect(engine.start(), isNull);

    s = c.read(quizProvider)!;
    expect(s.phase, QuizPhase.question);
    expect(s.questions.every((q) => q.category == QuizCategory.orangTua), isTrue);

    for (var i = 0; i < 5; i++) {
      final q = c.read(quizProvider)!.current!;
      engine.answer(q.answer); // jawab benar segera
      // waktu habis atau semua menjawab → papan skor langsung dihitung
      for (var t = 0; t < 120 && c.read(quizProvider)!.phase == QuizPhase.question; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(c.read(quizProvider)!.phase, QuizPhase.reveal);
      expect(c.read(quizProvider)!.me.lastPoints, greaterThan(500), reason: 'benar + bonus kecepatan');
      await tester.pump(const Duration(milliseconds: 3600));
    }
    s = c.read(quizProvider)!;
    expect(s.phase, QuizPhase.finished);
    expect(s.me.correct, 5);
    expect(c.read(leaderboardProvider)[me.name], s.me.score);
    expect(c.read(badgesProvider)[me.id], contains('Jagoan Gizi'));
    engine.leave();
  });

  test('Pengukuran: tanggal masa depan & nilai tidak wajar ditolak (ER-6.2)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final child = c.read(childrenProvider.notifier).byId('c_alya');
    final m = c.read(measurementsProvider.notifier);
    expect(() => m.add(child: child, date: DateTime.now().add(const Duration(days: 2)), weightKg: 8, heightCm: 70), throwsArgumentError);
    expect(() => m.add(child: child, date: DateTime.now(), weightKg: 80, heightCm: 70), throwsArgumentError);
    expect(() => m.add(child: child, date: DateTime.now(), weightKg: 8, heightCm: 7), throwsArgumentError);
    expect(m.add(child: child, date: DateTime.now(), weightKg: 8.2, heightCm: 70.5).result.stuntingRisk, isFalse);
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester, {String? loginAs}) async {
    tester.view.physicalSize = const Size(440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const GroWellApp()));
    await tester.pumpAndSettle();
    if (loginAs != null) {
      c.read(sessionProvider.notifier).loginAs(loginAs);
      await tester.pumpAndSettle();
    }
    return c;
  }

  testWidgets('Beranda orang tua sesuai desain (status, jadwal kontrol, ringkasan)', (tester) async {
    await pumpApp(tester, loginAs: 'u_rani');
    expect(find.text('Halo, Abiyu'), findsOneWidget);
    expect(find.textContaining('MERAH (Kurang)'), findsOneWidget);
    expect(find.textContaining('Dokter menjadwalkan kontrol', findRichText: true), findsOneWidget);
    expect(find.text('Ringkasan Tumbuh Kembang'), findsOneWidget);
    expect(find.text('Asisten Ahli Gizi'), findsOneWidget);

    await tester.tap(find.text('Alya'));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Alya'), findsOneWidget);
    expect(find.textContaining('HIJAU (Normal)'), findsOneWidget);

    await tester.tap(find.text('Ringkasan Tumbuh Kembang'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Pertumbuhan'), findsOneWidget);
    expect(find.text('Data Detail Bulanan'), findsOneWidget);
  });

  testWidgets('Orang tua baru tanpa anak melihat Selamat Datang lalu Tambah Data Anak', (tester) async {
    final c = await pumpApp(tester);
    final u = c.read(usersProvider.notifier).register(name: 'Uji Baru', email: 'baru@demo.id', password: 'rahasia123', role: Role.parent);
    c.read(sessionProvider.notifier).loginAs(u.id);
    await tester.pumpAndSettle();
    expect(find.text('Selamat Datang!'), findsOneWidget);
    await tester.tap(find.text('Tambah Data Anak'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan Anak'), findsOneWidget);
  });

  testWidgets('Catat pertumbuhan dari foto (simulasi) menambah pengukuran', (tester) async {
    final c = await pumpApp(tester, loginAs: 'u_rani');
    final before = c.read(childMeasurementsProvider('c_abiyu')).length;
    await tester.tap(find.byTooltip('Pilih aksi'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Aksi'), findsOneWidget);
    await tester.tap(find.text('Catat Pertumbuhan Anak'));
    await tester.pumpAndSettle();
    expect(find.text('Foto Anak untuk Pemantauan'), findsOneWidget);
    await tester.tap(find.text('Coba tanpa foto (demo)'));
    await tester.pump();
    expect(find.text('Memproses dengan AI...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Pengukuran Berhasil!'), findsOneWidget);
    await tester.tap(find.text('Simpan Data'));
    await tester.pumpAndSettle();
    expect(c.read(childMeasurementsProvider('c_abiyu')).length, before + 1);
  });

  testWidgets('Foto makanan (foto contoh) → estimasi gizi → simpan ke laporan', (tester) async {
    final c = await pumpApp(tester, loginAs: 'u_rani');
    final before = c.read(foodLogProvider).where((e) => e.childId == 'c_alya').length;
    c.read(routerProvider).push('/child/c_alya/food');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto Makanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pakai foto contoh (demo)'));
    await tester.pump();
    expect(find.text('Menganalisis dengan AI'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Estimasi Gizi (Simulasi)'), findsOneWidget);
    expect(find.text('Foto tersimpan'), findsOneWidget);
    await tester.tap(find.text('Simpan & Lihat Perkembangan'));
    await tester.pumpAndSettle();
    expect(find.text('Laporan Gizi Harian Anak'), findsOneWidget);
    expect(c.read(foodLogProvider).where((e) => e.childId == 'c_alya').length, before + 4);
  });
}
