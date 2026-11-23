import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growell/app.dart';
import 'package:growell/core/quiz_rules.dart';
import 'package:growell/state/providers.dart';
import 'package:growell/state/quiz_engine.dart';

void main() {
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

  group('Dialog Catat Pertumbuhan Anak', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Catat manual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tinggi & Berat Badan'));
      await tester.pumpAndSettle();
    }

    FilledButton saveButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.ancestor(of: find.text('Simpan Data'), matching: find.byType(FilledButton)));

    testWidgets('Simpan aktif setelah isian valid; ringkasan; Ubah Data mengganti hasil', (tester) async {
      final c = await pumpApp(tester, loginAs: 'u_rani');
      final before = c.read(childMeasurementsProvider('c_abiyu')).length;
      await openDialog(tester);
      expect(find.text('Catat Pertumbuhan Anak'), findsOneWidget);
      expect(find.text('Tanggal Pengukuran'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull, reason: 'Simpan nonaktif sebelum diisi');

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '250');
      await tester.enterText(fields.at(1), '7,2');
      await tester.pump();
      expect(find.text('Di luar rentang 40 – 120 cm'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);

      await tester.enterText(fields.at(0), '64,5');
      await tester.pump();
      expect(find.text('Rentang yang dapat diisi: 40 – 120 cm'), findsOneWidget);
      await tester.tap(find.text('Simpan Data'));
      await tester.pumpAndSettle();

      expect(find.text('Data Berhasil Disimpan!'), findsOneWidget);
      expect(find.text('64,5 cm'), findsOneWidget);
      expect(find.text('7,2 kg'), findsOneWidget);
      expect(find.textContaining('Perubahan dari'), findsOneWidget);
      expect(c.read(childMeasurementsProvider('c_abiyu')).length, before + 1);

      await tester.tap(find.text('Ubah Data'));
      await tester.pumpAndSettle();
      expect(c.read(childMeasurementsProvider('c_abiyu')).length, before, reason: 'hasil sebelumnya dihapus saat diubah');
      await tester.enterText(find.byType(TextField).at(1), '7,4');
      await tester.pump();
      await tester.tap(find.text('Simpan Data'));
      await tester.pumpAndSettle();
      expect(find.text('7,4 kg'), findsOneWidget);
      final ms = c.read(childMeasurementsProvider('c_abiyu'));
      expect(ms.length, before + 1);
      expect(ms.where((m) => m.weightKg == 7.4 && m.heightCm == 64.5), hasLength(1));

      await tester.tap(find.text('Lihat Detail'));
      await tester.pumpAndSettle();
      expect(find.text('Pertumbuhan Abiyu'), findsOneWidget);
    });
  });

  group('Kuis biru (desain update)', () {
    test('mode 2 pemain hanya mengisi 1 lawan; mode 4 pemain 3 lawan', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final me = c.read(usersProvider.notifier).byId('u_dina');
      final engine = c.read(quizProvider.notifier);
      const settings = QuizSettings(questionCount: 10, secondsPerQuestion: 15);
      expect(engine.createRoom(me: me, settings: settings, capacity: 3), isNotNull);
      expect(engine.createRoom(me: me, settings: settings, capacity: 2), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 4000));
      expect(c.read(quizProvider)!.players, hasLength(2));
      expect(c.read(quizProvider)!.isFull, isTrue);
      expect(engine.createRoom(me: me, settings: settings, capacity: 4), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 4000));
      expect(c.read(quizProvider)!.players, hasLength(4));
      engine.leave();
    });

    Future<ProviderContainer> playToEnd(WidgetTester tester, {required int capacity}) async {
      final c = await pumpApp(tester, loginAs: 'u_dina');
      await tester.tap(find.text('Kuis'));
      await tester.pumpAndSettle();
      expect(find.text('Ayo tantang temanmu!'), findsOneWidget);
      await tester.tap(find.text('$capacity Pemain'));
      await tester.pump();
      await tester.tap(find.text('Pengaturan ruang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mudah'));
      await tester.pump();
      await tester.tap(find.text('Buat Ruang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Ruang Permainan'), findsOneWidget);
      expect(find.text('KODE RUANG'), findsOneWidget);
      await tester.pump(Duration(milliseconds: 1250 * capacity));
      expect(find.text('Siap ✓'), findsNWidgets(capacity));
      await tester.tap(find.text('Mulai Quiz'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final total = c.read(quizProvider)!.questions.length;
      expect(total, 10, reason: 'bawaan desain: 10 soal');
      for (var i = 0; i < total; i++) {
        final s = c.read(quizProvider)!;
        expect(find.text('Quiz berlangsung'), findsOneWidget);
        expect(find.text('${(i + 1).toString().padLeft(2, '0')} / 10'), findsOneWidget);
        await tester.tap(find.text(s.current!.options[s.current!.answer]));
        for (var t = 0; t < 200 && c.read(quizProvider)!.phase == QuizPhase.question; t++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.textContaining('Benar! +'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 3600));
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Permainan selesai!'), findsOneWidget);
      expect(find.text('PEMENANG'), findsOneWidget);
      expect(find.text('Peringkat pemain'), findsOneWidget);
      return c;
    }

    testWidgets('alur 4 pemain sampai hasil; tombol Kembali tidak memunculkan error', (tester) async {
      final c = await playToEnd(tester, capacity: 4);
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.read(quizProvider), isNull, reason: 'state kuis dibersihkan setelah keluar');
      expect(find.text('Ayo tantang temanmu!'), findsOneWidget);
    });

    testWidgets('alur 2 pemain; Main Lagi kembali ke pilih mode tanpa error', (tester) async {
      final c = await playToEnd(tester, capacity: 2);
      await tester.tap(find.text('Main Lagi'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.read(quizProvider), isNull);
      expect(find.text('Ayo tantang temanmu!'), findsWidgets);
    });

    testWidgets('keluar di tengah permainan lewat konfirmasi menghentikan kuis', (tester) async {
      final c = await pumpApp(tester, loginAs: 'u_rani');
      c.read(routerProvider).push('/quiz');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat Ruang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.tap(find.text('Mulai Quiz'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.read(quizProvider)!.phase, QuizPhase.question);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari kuis?'), findsOneWidget);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.read(quizProvider), isNull);
      expect(find.text('Ayo tantang temanmu!'), findsOneWidget);
    });
  });
}
