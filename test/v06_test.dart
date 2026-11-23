import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growell/app.dart';
import 'package:growell/config.dart';
import 'package:growell/core/status.dart';
import 'package:growell/core/zscore.dart' show Sex;
import 'package:growell/data/quiz_bank.dart';
import 'package:growell/models.dart';
import 'package:growell/state/ai.dart';
import 'package:growell/state/providers.dart';
import 'package:growell/util/files.dart';

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

  group('F5 kuis live: kunci jawaban server', () {
    test('quiz_questions di migrasi sama persis dengan bank soal aplikasi', () {
      final sql = File('supabase/migrations/20261123000002_kuis_live.sql').readAsStringSync();
      final rows = RegExp(r"\('(\w+)', '(\w+)', '(\w+)', (\d)\)").allMatches(sql).toList();
      final server = {for (final m in rows) m.group(1)!: (m.group(2)!, m.group(3)!, int.parse(m.group(4)!))};
      expect(server.length, quizBank.length, reason: 'setiap soal aplikasi harus punya kunci di server');
      for (final q in quizBank) {
        expect(server[q.id], (q.category.name, q.difficulty.name, q.answer), reason: 'soal ${q.id}');
      }
    });
  });

  group('F2 dokumen STR', () {
    test('validasi berkas STR', () {
      expect(validateStrFile('str.pdf', 1000), isNull);
      expect(validateStrFile('STR.JPG', 1000), isNull);
      expect(validateStrFile('str.png', 1000), isNull);
      expect(validateStrFile('str.exe', 1000), contains('PDF'));
      expect(validateStrFile('str.pdf', strMaxBytes + 1), contains('5 MB'));
      expect(validateStrFile('str.pdf', 0), isNotNull);
    });

    testWidgets('nakes mendaftar dengan dokumen STR → admin melihat tautan dokumen', (tester) async {
      final c = await pumpApp(tester);
      final err = await c.read(sessionProvider.notifier).register(
            name: 'dr. Uji',
            email: 'uji@demo.id',
            password: 'rahasia123',
            role: Role.health,
            strNumber: '1234567890',
            title: 'Dokter umum',
            strFile: PickedBytes(bytes: Uint8List.fromList([1, 2, 3]), name: 'str_uji.pdf', mime: 'application/pdf'),
          );
      expect(err, isNull);
      final me = c.read(currentUserProvider)!;
      expect(me.strDocumentPath, 'lokal/str_uji.pdf');
      await tester.pumpAndSettle();
      expect(find.text('Dokumen STR sudah diunggah'), findsOneWidget);

      await c.read(sessionProvider.notifier).logout();
      c.read(sessionProvider.notifier).loginAs('u_admin');
      await tester.pumpAndSettle();
      c.read(routerProvider).push('/admin');
      await tester.pumpAndSettle();
      expect(find.text('dr. Uji'), findsOneWidget);
      expect(find.text('Lihat dokumen STR'), findsOneWidget);
    });

    test('hanya nakes yang boleh mengunggah STR', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final users = c.read(usersProvider.notifier);
      final f = PickedBytes(bytes: Uint8List.fromList([1]), name: 'a.pdf', mime: 'application/pdf');
      await expectLater(users.uploadStrDocument(me: users.byId('u_rani'), file: f), throwsA(isA<AccessDenied>()));
      await users.uploadStrDocument(me: users.byId('u_candra'), file: f);
      expect(users.byId('u_candra').strDocumentPath, 'lokal/a.pdf');
    });
  });

  group('F4 mode demo', () {
    test('mode lokal selalu menampilkan fitur demo', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(demoBuild, isTrue, reason: 'bawaan tanpa --dart-define=GROWELL_DEMO=false');
      expect(c.read(showDemoProvider), isTrue);
    });

    testWidgets('halaman masuk menampilkan akun demo pada build demo', (tester) async {
      await pumpApp(tester);
      expect(find.text('Akun demo (prototype – data contoh):'), findsOneWidget);
    });
  });

  group('F6/F7 AI', () {
    test('data anak yang dikirim ke AI hanya data minimum', () {
      final child = Child(
        id: 'c1',
        parentId: 'u1',
        name: 'Abiyu',
        sex: Sex.male,
        birthDate: DateTime.now().subtract(const Duration(days: 200)),
        posyandu: 'Posyandu Melati',
        region: 'Kel. Kalideres',
      );
      final j = AiClient.childJson(child, GrowthStatus.waspada);
      expect(j.keys.toSet(), {'name', 'age_months', 'sex', 'status'});
      expect(j['sex'], 'male');
      expect(j.toString(), isNot(contains('Posyandu')));
    });

    testWidgets('mode lokal: asisten memakai jawaban berbasis aturan', (tester) async {
      final c = await pumpApp(tester, loginAs: 'u_rani');
      c.read(routerProvider).push('/assistant');
      await tester.pumpAndSettle();
      expect(find.text('Mode lokal • berbasis aturan'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'menu mpasi');
      await tester.tap(find.byTooltip('Kirim'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Contoh menu'), findsOneWidget);
    });
  });
}
