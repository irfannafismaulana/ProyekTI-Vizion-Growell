import 'package:flutter/material.dart';

/// Lebar desain layar HP (Figma: frame 440 px).
const phoneWidth = 440.0;

/// Tinggi logis minimum agar tata letak HP tidak terlalu pendek saat diperbesar.
const _minLogicalHeight = 800.0;

/// Skala tampilan dari parameter URL `?zoom=` (sebelum tanda #):
/// - kosong / `auto`: layar besar vertikal (mis. 1200×1920) diperbesar otomatis hingga penuh;
/// - angka persen, mis. `135` atau `150`: diperbesar sebesar itu di layar apa pun;
/// - `100` / `off`: ukuran asli (bingkai HP 440 px).
double? zoomFromUrl() {
  final z = Uri.base.queryParameters['zoom']?.trim().toLowerCase();
  if (z == null || z.isEmpty || z == 'auto') return null;
  if (z == 'off') return 1;
  final pct = double.tryParse(z.replaceAll('%', ''));
  return pct == null || pct < 50 || pct > 400 ? null : pct / 100;
}

/// Skala otomatis: hanya untuk layar vertikal yang jauh lebih lebar dari HP.
/// Bingkai HP dibuat memenuhi lebar layar, dibatasi tinggi logis minimum.
double autoScale(Size screen) {
  final portrait = screen.height > screen.width;
  if (!portrait || screen.width < 700) return 1;
  final s = [screen.width / phoneWidth, screen.height / _minLogicalHeight].reduce((a, b) => a < b ? a : b);
  return s < 1.15 ? 1 : s;
}

/// Bingkai aplikasi: kolom selebar HP di tengah; pada layar besar seluruh UI
/// (termasuk dialog & lembar bawah) diperbesar proporsional agar memenuhi layar.
class DisplayFrame extends StatelessWidget {
  const DisplayFrame({super.key, required this.child, this.zoom});
  final Widget child;

  /// Skala manual (dari URL); null = otomatis.
  final double? zoom;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = zoom ?? autoScale(mq.size);
    Widget frame(Widget c) => ColoredBox(
          color: const Color(0xFFDCE6F5),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: phoneWidth),
              child: Material(elevation: 4, child: c),
            ),
          ),
        );
    if (scale == 1) return frame(child);

    // Ukuran logis yang dilihat aplikasi; FittedBox memperbesar hasilnya ke layar.
    final logical = Size(mq.size.width / scale, mq.size.height / scale);
    return ColoredBox(
      color: const Color(0xFFDCE6F5),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox.fromSize(
          size: logical,
          child: MediaQuery(
            data: mq.copyWith(
              size: logical,
              padding: mq.padding / scale,
              viewPadding: mq.viewPadding / scale,
              viewInsets: mq.viewInsets / scale,
            ),
            child: frame(child),
          ),
        ),
      ),
    );
  }
}
