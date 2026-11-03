import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growell/app.dart';
import 'package:growell/ui/display_frame.dart';

void main() {
  group('Skala tampilan layar besar', () {
    test('layar vertikal 1200×1920 diperbesar ±2,4× (bingkai ±88% lebar layar)', () {
      final s = autoScale(const Size(1200, 1920));
      expect(s, closeTo(2.4, 0.01));
      expect(phoneWidth * s / 1200, greaterThan(0.85));
      expect(1920 / s, greaterThanOrEqualTo(800), reason: 'tinggi logis cukup agar dialog muat utuh');
    });
    test('HP dan laptop (horizontal) tidak diubah', () {
      expect(autoScale(const Size(430, 900)), 1);
      expect(autoScale(const Size(1920, 1080)), 1);
      expect(autoScale(const Size(1366, 768)), 1);
    });
  });

  testWidgets('UI memenuhi layar 1200×1920 dan ketukan tetap tepat sasaran', (tester) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: GroWellApp()));
    await tester.pumpAndSettle();

    final button = tester.getRect(find.text('Masuk').last);
    final panelTitle = tester.getRect(find.text('Masuk Ke Growell'));
    expect(panelTitle.center.dx, closeTo(600, 2), reason: 'tetap di tengah layar');
    expect(tester.getRect(find.byType(DisplayFrame)).width, 1200);
    expect(button.height, greaterThan(30), reason: 'teks diperbesar ±2,7×');

    await tester.ensureVisible(find.text('Remaja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remaja'));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Dina 👋'), findsOneWidget);
  });
}
