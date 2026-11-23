import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growell/app.dart';
import 'package:growell/models.dart';
import 'package:growell/state/providers.dart';

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

  group('Tombol + orang tua: input manual', () {
    testWidgets('lembar + berisi makanan anak dan tinggi/berat badan', (tester) async {
      await pumpApp(tester, loginAs: 'u_rani');
      await tester.tap(find.byTooltip('Catat manual'));
      await tester.pumpAndSettle();
      expect(find.text('Makanan Anak'), findsOneWidget);
      expect(find.text('Tinggi & Berat Badan'), findsOneWidget);

      await tester.tap(find.text('Tinggi & Berat Badan'));
      await tester.pumpAndSettle();
      expect(find.text('Catat Pertumbuhan Anak'), findsOneWidget, reason: 'v0.5: dialog sesuai desain update');
    });

    testWidgets('catat makanan manual: pilih menu, ubah porsi, simpan ke laporan', (tester) async {
      final c = await pumpApp(tester, loginAs: 'u_rani');
      await tester.tap(find.text('Alya'));
      await tester.pumpAndSettle();
      final before = c.read(foodLogProvider).where((e) => e.childId == 'c_alya').length;

      await tester.tap(find.byTooltip('Catat manual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Makanan Anak'));
      await tester.pumpAndSettle();
      expect(find.text('Catat Makanan'), findsOneWidget);

      await tester.tap(find.text('Bubur nasi'));
      await tester.tap(find.text('Telur ayam rebus'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '25'), '30');
      await tester.tap(find.text('Selingan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('kkal'), findsWidgets);

      await tester.tap(find.text('Simpan Catatan Makan'));
      await tester.pumpAndSettle();
      expect(find.text('Laporan Gizi Harian Anak'), findsOneWidget);
      final added = c.read(foodLogProvider).where((e) => e.childId == 'c_alya').skip(before).toList();
      expect(added.map((e) => (e.foodId, e.grams, e.meal)), containsAll([('bubur', 50.0, Meal.selingan), ('telur', 30.0, Meal.selingan)]));
    });

    testWidgets('pencarian makanan di daftar pangan', (tester) async {
      final c = await pumpApp(tester, loginAs: 'u_rani');
      c.read(routerProvider).push('/child/c_alya/food/manual');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cari makanan lain'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Cari, mis. telur, ikan, pisang'), 'salmon');
      await tester.pumpAndSettle();
      expect(find.text('Telur ayam rebus'), findsOneWidget, reason: 'chip menu cepat di halaman tetap ada');
      await tester.tap(find.text('Ikan salmon (kukus)'));
      await tester.pumpAndSettle();
      expect(find.text('Ikan salmon (kukus)'), findsOneWidget);
    });
  });

  group('Video edukasi nakes', () {
    final bytes = Uint8List.fromList(List.filled(1024, 1));

    test('validasi judul, sasaran, ukuran dan durasi', () {
      String? v({String title = 'MPASI hati ayam', Set<Role> a = const {Role.parent}, int size = 1000, int s = 30}) =>
          EduVideosNotifier.validate(title: title, audience: a, sizeBytes: size, seconds: s);
      expect(v(), isNull);
      expect(v(title: 'ab'), isNotNull);
      expect(v(a: const {}), isNotNull);
      expect(v(a: const {Role.health}), isNotNull);
      expect(v(size: 50 * 1024 * 1024 + 1), contains('50 MB'));
      expect(v(s: 181), contains('3 menit'));
    });

    test('hanya nakes terverifikasi yang boleh mengunggah; video terbaru tampil paling depan', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final users = c.read(usersProvider.notifier);
      final videos = c.read(eduVideosProvider.notifier);
      Future<Reel> up(String userId, String title) => videos.upload(
            actor: users.byId(userId),
            title: title,
            caption: 'Contoh',
            audience: {Role.parent},
            bytes: bytes,
            mime: 'video/mp4',
            extension: 'mp4',
            seconds: 42,
            localUrl: 'blob:demo',
          );

      await expectLater(up('u_dina', 'Video remaja'), throwsA(isA<AccessDenied>()));
      await expectLater(up('u_candra', 'Belum terverifikasi'), throwsA(isA<AccessDenied>()));
      await up('u_sarah', 'Video pertama');
      final second = await up('u_sarah', 'Video kedua');
      expect(c.read(eduVideosProvider).map((v) => v.title), ['Video kedua', 'Video pertama']);
      expect(second.isVideo, isTrue);
      expect(second.audience, {Role.parent});

      expect(() => videos.remove(actor: users.byId('u_irfan'), id: second.id), throwsA(isA<AccessDenied>()));
      videos.remove(actor: users.byId('u_sarah'), id: second.id);
      expect(c.read(eduVideosProvider).map((v) => v.title), ['Video pertama']);
    });

    testWidgets('nakes punya tab Video dengan tombol unggah', (tester) async {
      await pumpApp(tester, loginAs: 'u_sarah');
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      expect(find.text('Video Edukasi'), findsOneWidget);
      expect(find.text('Belum ada video. Unggah video edukasi pertama Anda.'), findsOneWidget);
      await tester.tap(find.text('Unggah Video'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih Video'), findsOneWidget);
      expect(find.text('Orang tua'), findsOneWidget);
      expect(find.text('Remaja'), findsOneWidget);
    });

    testWidgets('video unggahan tampil di Reels sesuai sasaran', (tester) async {
      final c = await pumpApp(tester, loginAs: 'u_dina');
      await c.read(eduVideosProvider.notifier).upload(
            actor: c.read(usersProvider.notifier).byId('u_sarah'),
            title: 'Gizi remaja putri',
            caption: 'Tablet tambah darah',
            audience: {Role.teen},
            bytes: bytes,
            mime: 'video/mp4',
            extension: 'mp4',
            seconds: 30,
            localUrl: 'blob:demo',
          );
      await tester.tap(find.text('Reels'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Gizi remaja putri'), findsOneWidget);
      expect(find.text('Video nakes'), findsOneWidget);
    });
  });
}
