import 'package:flutter/material.dart';

import '../core/status.dart';
import '../core/zscore.dart';

// ---------------------------------------------------------------- Palet (desain Figma GroWell)
const brandBlue = Color(0xFF2E7EFE);
const brandBlueDark = Color(0xFF1A5BF6);
const brandGreen = Color(0xFF0BC24F);
const brandRed = Color(0xFFF0305C);
const brandYellow = Color(0xFFF0B000);
const brandPink = Color(0xFFF53AA0);
const pageBg = Color(0xFFF8FAFC);
const textDark = Color(0xFF1F2937);
const textGray = Color(0xFF6B7280);
const tipsBg = Color(0xFFEEF4FF);
const tipsText = Color(0xFF1E44C8);
const warnBg = Color(0xFFFDE2B3);
const warnBorder = Color(0xFFF2A93B);

const headerGradient = LinearGradient(colors: [brandBlue, brandBlueDark], begin: Alignment.topLeft, end: Alignment.bottomRight);

Color statusColor(GrowthStatus s) => switch (s) {
      GrowthStatus.normal => brandGreen,
      GrowthStatus.waspada => brandYellow,
      GrowthStatus.kurang => brandRed,
      GrowthStatus.lebih => brandRed,
    };

/// Warna batang grafik ringkasan (legenda Figma: Normal hijau, Waspada kuning, Kurang merah muda).
Color statusChartColor(GrowthStatus s) => switch (s) {
      GrowthStatus.normal => brandGreen,
      GrowthStatus.waspada => brandYellow,
      GrowthStatus.kurang => brandPink,
      GrowthStatus.lebih => const Color(0xFF9C27B0),
    };

// ---------------------------------------------------------------- Format
const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const monthsLong = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

String fmtDate(DateTime d) => '${d.day} ${monthsShort[d.month - 1]} ${d.year}';

String two(int n) => n.toString().padLeft(2, '0');

/// dd/mm/yyyy seperti pada desain.
String fmtDmy(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// Angka dengan koma desimal (format Indonesia).
String fmtNum(double x, [int digits = 1]) => x.toStringAsFixed(digits).replaceAll('.', ',');

/// Angka tanpa desimal bila bulat (mis. 18 g, 12,5 kg).
String fmtShort(double x) => x == x.roundToDouble() ? x.toStringAsFixed(0) : fmtNum(x);

String fmtZ(double z) {
  final r = roundZ(z);
  return '${r > 0 ? '+' : ''}${r.toStringAsFixed(2).replaceAll('.', ',')}';
}

/// Menerima koma atau titik desimal.
double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

String fmtAge(int days) {
  final months = days ~/ 30.4375;
  final rem = days - (months * 30.4375).round();
  if (months == 0) return '$days hari';
  return rem > 0 ? '$months bulan $rem hari' : '$months bulan';
}

/// "6 Bulan" seperti di header Beranda.
String fmtAgeMonths(int days) {
  final m = days ~/ 30.4375;
  return m == 0 ? '$days Hari' : '$m Bulan';
}

Color levelColor(int level) => switch (level) {
      0 => const Color(0xFF16A34A),
      1 => const Color(0xFFD99A00),
      2 => const Color(0xFFEA580C),
      _ => const Color(0xFFDC2626),
    };

// ---------------------------------------------------------------- Komponen
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 120, this.iconOnly = false});
  final double height;
  final bool iconOnly;
  @override
  Widget build(BuildContext context) => Image.asset(
        iconOnly ? 'assets/logo_icon.png' : 'assets/logo_full.png',
        height: height,
        fit: BoxFit.contain,
        semanticLabel: 'Logo GroWell – Tumbuh Sehat, Tumbuh Hebat',
      );
}

/// Kartu putih membulat dengan bayangan lembut.
class GwCard extends StatelessWidget {
  const GwCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color = Colors.white, this.margin});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsets? margin;
  @override
  Widget build(BuildContext context) => Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0F2F5)),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 3))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

/// Tombol utama biru lebar (mis. "Simpan Anak", "Tambah Data Anak").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed, this.icon, this.color = brandBlue, this.foreground = Colors.white});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color foreground;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: foreground,
            elevation: 2,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          onPressed: onPressed,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 10)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );
}

/// Tombol sekunder abu-abu/outline (mis. "Batal", "Pilih Galeri").
class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label, {super.key, required this.onPressed, this.icon, this.outlined = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: outlined ? Colors.white : const Color(0xFFF1F3F6),
            foregroundColor: outlined ? brandBlue : textDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: outlined ? const BorderSide(color: brandBlue, width: 1.5) : BorderSide.none,
            ),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          onPressed: onPressed,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 10)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );
}

/// Kotak "Tips Foto Terbaik" / "Tips Nutrisi".
class TipsBox extends StatelessWidget {
  const TipsBox({super.key, required this.title, required this.items, this.bg = tipsBg, this.fg = tipsText, this.border});
  final String title;
  final List<String> items;
  final Color bg;
  final Color fg;
  final Color? border;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: border == null ? null : Border.all(color: border!, width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('•  ', style: TextStyle(color: fg)),
                Expanded(child: Text(t, style: TextStyle(color: fg, fontSize: 13.5, height: 1.3))),
              ]),
            ),
        ]),
      );
}

/// Kartu angka gizi berwarna (Protein/Karbohidrat/Lemak/Serat).
class MacroTile extends StatelessWidget {
  const MacroTile({super.key, required this.label, required this.value, required this.color, required this.bg});
  final String label;
  final String value;
  final Color color;
  final Color bg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: textGray, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}

const macroColors = {
  'Protein': (Color(0xFF16A34A), Color(0xFFEFFBF2)),
  'Karbohidrat': (Color(0xFFEA580C), Color(0xFFFFF5EC)),
  'Lemak': (Color(0xFFDC2626), Color(0xFFFEF2F2)),
  'Serat': (Color(0xFF9333EA), Color(0xFFFAF5FF)),
};

/// Label status kecil berwarna (mis. tabel Detail Pertumbuhan).
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final GrowthStatus status;
  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      GrowthStatus.normal => (const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      GrowthStatus.waspada => (const Color(0xFFA16207), const Color(0xFFFEF9C3)),
      GrowthStatus.kurang => (const Color(0xFFBE185D), const Color(0xFFFCE7F3)),
      GrowthStatus.lebih => (const Color(0xFF7E22CE), const Color(0xFFF3E8FF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.level, {super.key});
  final String label;
  final int level;
  @override
  Widget build(BuildContext context) {
    final c = levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class DraftBadge extends StatelessWidget {
  const DraftBadge({super.key, this.text = 'Draf — perlu ditinjau nakes'});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF92400E))),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: textDark))),
          ?trailing,
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: textGray)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// Kotak peringatan/info dengan warna sesuai tingkat.
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.icon, required this.title, required this.text, this.color = brandBlue, this.action});
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(color: textDark)),
              if (action != null) ...[const SizedBox(height: 8), action!],
            ]),
          ),
        ]),
      );
}

/// Catatan kuning "Catatan: …" seperti pada hasil estimasi AI.
class NoteBox extends StatelessWidget {
  const NoteBox(this.text, {super.key, this.label = 'Catatan:'});
  final String text;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEFCE8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
          TextSpan(text: text, style: const TextStyle(color: Color(0xFF92400E))),
        ])),
      );
}

/// Dialog bergaya Figma: header biru dengan judul putih dan tombol tutup.
Future<T?> showBlueDialog<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder}) {
  return showDialog<T>(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            color: brandBlue,
            padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
            child: Row(children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(c),
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
              ),
            ]),
          ),
          Flexible(child: builder(c)),
        ]),
      ),
    ),
  );
}

void showError(BuildContext context, Object e) {
  final msg = e is ArgumentError ? '${e.message}' : e is RangeError ? '${e.message}' : e.toString();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)));
}

void showInfo(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
