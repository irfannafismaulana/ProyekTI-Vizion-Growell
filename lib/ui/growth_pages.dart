import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/status.dart';
import '../core/zscore.dart';
import '../models.dart';
import '../state/providers.dart';
import 'common.dart';

// ---------------------------------------------------------------- Ringkasan di Beranda
/// Satu batang per bulan (pengukuran terakhir di bulan itu), warna sesuai status.
List<Measurement> monthlyMeasurements(List<Measurement> ms, {int max = 12}) {
  final byMonth = <int, Measurement>{};
  for (final m in ms) {
    byMonth[m.date.year * 12 + m.date.month] = m; // ms sudah urut tanggal → yang terakhir menang
  }
  final keys = byMonth.keys.toList()..sort();
  return [for (final k in keys.skip(math.max(0, keys.length - max))) byMonth[k]!];
}

class GrowthSummaryCard extends ConsumerWidget {
  const GrowthSummaryCard({super.key, required this.child});
  final Child child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = monthlyMeasurements(ref.watch(childMeasurementsProvider(child.id)));
    return GwCard(
      onTap: ms.isEmpty ? null : () => showGrowthDetailDialog(context, child),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text('Ringkasan Tumbuh Kembang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: textDark)),
          ),
          Text('Berat & Tinggi (Kg/cm)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
        ]),
        const SizedBox(height: 16),
        if (ms.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Belum ada data pengukuran.', textAlign: TextAlign.center, style: TextStyle(color: textGray)),
          )
        else
          SizedBox(height: 190, child: _MonthlyBars(ms: ms, onTap: () => showGrowthDetailDialog(context, child))),
        const Divider(height: 26),
        const Wrap(alignment: WrapAlignment.center, spacing: 22, runSpacing: 6, children: [
          _Dot(brandGreen, 'Normal'),
          _Dot(brandYellow, 'Waspada'),
          _Dot(brandPink, 'Kurang'),
        ]),
        if (ms.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Ketuk untuk melihat detail bulanan', textAlign: TextAlign.center, style: TextStyle(color: textGray, fontSize: 12)),
          ),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
      ]);
}

class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.ms, required this.onTap});
  final List<Measurement> ms;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final hs = ms.map((m) => m.heightCm);
    // Sumbu Y dimulai sedikit di bawah nilai terkecil agar kenaikan panjang badan terlihat.
    final minY = (hs.reduce(math.min) - 6).floorToDouble();
    final maxY = hs.reduce(math.max) + 1;
    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(monthsShort[ms[v.toInt()].date.month - 1], style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12.5)),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          // Ketukan pada batang juga membuka Detail Pertumbuhan.
          touchCallback: (event, response) {
            if (event is FlTapUpEvent) onTap();
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.white,
            tooltipBorder: const BorderSide(color: Color(0xFFD1D5DB)),
            getTooltipItem: (group, gi, rod, ri) {
              final m = ms[group.x];
              return BarTooltipItem(
                '${fmtDate(m.date)}\n${fmtNum(m.weightKg)} kg • ${fmtNum(m.heightCm)} cm\n${statusOf(m.result).status.label}',
                const TextStyle(color: textDark, fontSize: 12, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < ms.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: ms[i].heightCm,
                width: ms.length > 8 ? 16 : 26,
                color: statusChartColor(statusOf(ms[i].result).status),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Dialog "Detail Pertumbuhan"
void showGrowthDetailDialog(BuildContext context, Child child) {
  showBlueDialog<void>(context, title: 'Detail Pertumbuhan', builder: (c) => _GrowthDetail(child: child));
}

class _GrowthDetail extends ConsumerWidget {
  const _GrowthDetail({required this.child});
  final Child child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(childMeasurementsProvider(child.id));
    final ms = monthlyMeasurements(all);
    if (all.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Text('Belum ada data pengukuran.'));
    final first = all.first, last = all.last;
    Widget big(String label, String value, String delta, Color fg, Color bg) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13.5)),
              const SizedBox(height: 4),
              FittedBox(child: Text(value, style: TextStyle(color: fg, fontSize: 26, fontWeight: FontWeight.w800))),
              const SizedBox(height: 4),
              Text(delta, style: const TextStyle(color: textGray, fontSize: 12)),
            ]),
          ),
        );
    String sign(double d) => d >= 0 ? '+' : '−';
    const head = TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          big('Berat Saat Ini', '${fmtShort(last.weightKg)} kg', '${sign(last.weightKg - first.weightKg)}${fmtNum((last.weightKg - first.weightKg).abs())} kg dari awal',
              const Color(0xFF1D5BF6), const Color(0xFFEEF4FF)),
          const SizedBox(width: 12),
          big('Tinggi Saat Ini', '${fmtShort(last.heightCm)} cm', '${sign(last.heightCm - first.heightCm)}${fmtNum((last.heightCm - first.heightCm).abs())} cm dari awal',
              const Color(0xFF16A34A), const Color(0xFFEFFBF2)),
        ]),
        const SizedBox(height: 20),
        const Text('Data Detail Bulanan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: textDark)),
        const SizedBox(height: 12),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1.5)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Color(0xFFF3F4F6)),
              children: [
                Padding(padding: EdgeInsets.fromLTRB(12, 14, 4, 14), child: Text('Bulan', style: head)),
                Text('Berat\n(kg)', style: head),
                Text('Tinggi\n(cm)', style: head),
                Text('Status', style: head),
              ],
            ),
            for (var i = 0; i < ms.length; i++)
              TableRow(
                decoration: BoxDecoration(color: i.isOdd ? const Color(0xFFF9FAFB) : Colors.white),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                    child: Text('${monthsShort[ms[i].date.month - 1]} ${ms[i].date.year % 100}'),
                  ),
                  Text(fmtShort(ms[i].weightKg)),
                  Text(fmtShort(ms[i].heightCm)),
                  Align(alignment: Alignment.centerLeft, child: StatusPill(statusOf(ms[i].result).status)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 18),
        PrimaryButton('Lihat Grafik WHO & Z-score', icon: Icons.show_chart, onPressed: () {
          Navigator.pop(context);
          context.push('/child/${child.id}');
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Foto anak untuk pemantauan (simulasi AI)
void showChildPhotoDialog(BuildContext context, Child child) {
  showBlueDialog<void>(context, title: 'Foto Anak untuk Pemantauan', builder: (c) => _ChildPhotoFlow(child: child));
}

enum _PhotoStep { capture, processing, result }

class _ChildPhotoFlow extends ConsumerStatefulWidget {
  const _ChildPhotoFlow({required this.child});
  final Child child;
  @override
  ConsumerState<_ChildPhotoFlow> createState() => _ChildPhotoFlowState();
}

class _ChildPhotoFlowState extends ConsumerState<_ChildPhotoFlow> {
  _PhotoStep _step = _PhotoStep.capture;
  Uint8List? _photo;
  final _h = TextEditingController();
  final _w = TextEditingController();

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 1280);
      if (x == null) return;
      _photo = await x.readAsBytes();
      _analyze();
    } catch (e) {
      if (mounted) showError(context, ArgumentError('Kamera/galeri tidak dapat dibuka di perangkat ini.'));
    }
  }

  Future<void> _analyze() async {
    setState(() => _step = _PhotoStep.processing);
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final last = ref.read(childMeasurementsProvider(widget.child.id)).lastOrNull;
    final (h, w) = simulatePhotoEstimate(sex: widget.child.sex, ageDaysNow: widget.child.ageDays, last: last?.result);
    _h.text = fmtNum(h);
    _w.text = fmtNum(w);
    setState(() => _step = _PhotoStep.result);
  }

  void _save() {
    final h = parseNum(_h.text), w = parseNum(_w.text);
    if (h == null || w == null) return showError(context, ArgumentError('Isi tinggi dan berat badan dengan angka, contoh 62,5.'));
    try {
      final m = ref.read(measurementsProvider.notifier).add(child: widget.child, date: DateTime.now(), weightKg: w, heightCm: h, source: 'foto_simulasi');
      Navigator.pop(context);
      final s = statusOf(m.result).status;
      showInfo(context, 'Data ${widget.child.name} tersimpan. Status: ${s.label}.');
    } on RangeError {
      showError(context, ArgumentError('Umur anak di luar cakupan pemantauan 0–24 bulan.'));
    } catch (e) {
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: switch (_step) {
        _PhotoStep.capture => _capture(),
        _PhotoStep.processing => const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Column(children: [
              SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 4, color: Color(0xFF1E3A5F))),
              SizedBox(height: 40),
              Text('Memproses dengan AI...', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: textDark)),
              SizedBox(height: 12),
              Text('Menganalisis tinggi dan berat badan anak', style: TextStyle(color: Color(0xFF4B5563), fontSize: 15)),
            ]),
          ),
        _PhotoStep.result => _result(),
      },
    );
  }

  Widget _capture() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Ambil Foto Anak', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: textDark)),
        const SizedBox(height: 6),
        const Text('Pastikan anak berdiri tegak dan seluruh tubuh terlihat dalam frame',
            textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF4B5563), fontSize: 14.5)),
        const SizedBox(height: 20),
        Container(
          height: 250,
          decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(22)),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.photo_camera_outlined, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 14),
            Text('Kamera akan aktif di sini', style: TextStyle(color: Color(0xFF4B5563), fontSize: 16)),
          ]),
        ),
        const SizedBox(height: 18),
        const TipsBox(title: 'Tips Foto Terbaik:', items: [
          'Gunakan pencahayaan yang cukup',
          'Posisikan kamera setinggi dada anak',
          'Jaga jarak 1-2 meter dari anak',
          'Pastikan latar belakang polos',
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: PrimaryButton('Ambil Foto', icon: Icons.photo_camera_outlined, onPressed: () => _pick(ImageSource.camera))),
          const SizedBox(width: 12),
          Expanded(child: SecondaryButton('Pilih Galeri', icon: Icons.upload_outlined, onPressed: () => _pick(ImageSource.gallery))),
        ]),
        const SizedBox(height: 6),
        TextButton(onPressed: _analyze, child: const Text('Coba tanpa foto (demo)')),
      ]);

  Widget _result() {
    Widget metric(String label, TextEditingController c, String unit, IconData icon, Color fg, Color bg, Color iconBg) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14.5)),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  IntrinsicWidth(
                    child: TextField(
                      controller: c,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: fg, fontSize: 30, fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(unit, style: TextStyle(color: fg, fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Icon(Icons.edit, size: 16, color: fg.withValues(alpha: 0.6)),
                ]),
              ]),
            ),
            CircleAvatar(radius: 28, backgroundColor: iconBg, child: Icon(icon, color: fg, size: 28)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Center(
        child: CircleAvatar(radius: 32, backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.check, color: Color(0xFF16A34A), size: 36)),
      ),
      const SizedBox(height: 16),
      const Text('Pengukuran Berhasil!', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: textDark)),
      const SizedBox(height: 6),
      Text('Berikut hasil estimasi AI untuk\n${widget.child.name}',
          textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 15)),
      const SizedBox(height: 16),
      if (_photo != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(_photo!, height: 120, fit: BoxFit.cover)),
        ),
      metric('Tinggi Badan', _h, 'cm', Icons.arrow_upward, const Color(0xFF1D5BF6), const Color(0xFFEEF4FF), const Color(0xFFDBEAFE)),
      metric('Berat Badan', _w, 'kg', Icons.balance, const Color(0xFF16A34A), const Color(0xFFEFFBF2), const Color(0xFFDCFCE7)),
      const SizedBox(height: 4),
      const NoteBox(
        'Hasil ini adalah estimasi AI. Untuk hasil yang lebih akurat, lakukan pengukuran manual atau konsultasi dengan dokter. '
        'Prototype: belum memakai model AI — angka diproyeksikan dari tren pengukuran sebelumnya; ketuk angka untuk mengoreksi.',
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: SecondaryButton('Batal', onPressed: () => Navigator.pop(context))),
        const SizedBox(width: 12),
        Expanded(child: PrimaryButton('Simpan Data', onPressed: _save)),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- Halaman grafik WHO
class GrowthPage extends ConsumerStatefulWidget {
  const GrowthPage({super.key, required this.childId, this.readOnly = false});
  final String childId;

  /// Tenaga kesehatan melihat data anak tanpa bisa mengubahnya.
  final bool readOnly;
  @override
  ConsumerState<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends ConsumerState<GrowthPage> {
  Indicator _ind = Indicator.heightForAge;

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(childrenProvider).firstWhere((c) => c.id == widget.childId);
    final ms = ref.watch(childMeasurementsProvider(child.id));
    final last = ms.lastOrNull;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: Text('Pertumbuhan ${child.name}')),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              backgroundColor: brandBlue,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/child/${child.id}/measure'),
              icon: const Icon(Icons.add),
              label: const Text('Tambah data'),
            ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
        Text('${child.sex == Sex.female ? 'Perempuan' : 'Laki-laki'} • ${fmtAge(child.ageDays)} • lahir ${fmtDate(child.birthDate)}',
            style: const TextStyle(color: textGray)),
        Text('${child.posyandu}, ${child.region}', style: const TextStyle(color: textGray)),
        const SizedBox(height: 8),
        if (last != null) ResultSummary(result: last.result, showConsultButton: !widget.readOnly),
        const SectionTitle('Grafik pertumbuhan WHO'),
        SegmentedButton<Indicator>(
          segments: [for (final i in Indicator.values) ButtonSegment(value: i, label: Text(i.short))],
          selected: {_ind},
          onSelectionChanged: (s) => setState(() => _ind = s.first),
        ),
        const SizedBox(height: 12),
        GwCard(
          padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
          child: SizedBox(height: 260, child: GrowthChart(child: child, measurements: ms, indicator: _ind)),
        ),
        const _Legend(),
        const SectionTitle('Riwayat pengukuran'),
        if (ms.isEmpty) const Text('Belum ada data pengukuran.'),
        for (final m in ms.reversed)
          GwCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtDate(m.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('BB ${fmtNum(m.weightKg)} kg • TB ${fmtNum(m.heightCm)} cm • ${fmtAge(m.result.ageDays)}',
                      style: const TextStyle(color: textGray, fontSize: 13)),
                  Text('TB/U ${fmtZ(m.result.zHeightForAge)} • BB/U ${fmtZ(m.result.zWeightForAge)}',
                      style: const TextStyle(color: textGray, fontSize: 12)),
                ]),
              ),
              StatusPill(statusOf(m.result).status),
            ]),
          ),
      ]),
    );
  }
}

/// Ringkasan ketiga indikator + peringatan stunting (ER-1.3).
class ResultSummary extends StatelessWidget {
  const ResultSummary({super.key, required this.result, this.showConsultButton = true});
  final GrowthResult result;
  final bool showConsultButton;

  @override
  Widget build(BuildContext context) {
    Widget row(Indicator ind, double? z) {
      if (z == null) {
        return ListTile(dense: true, title: Text(ind.short), subtitle: const Text('Panjang badan di luar tabel WHO 45–110 cm'));
      }
      final c = classify(ind, z);
      return ListTile(
        dense: true,
        title: Text('${ind.short}  (z = ${fmtZ(z)})'),
        trailing: StatusChip(c.label, c.level),
      );
    }

    return Column(children: [
      if (result.stuntingRisk)
        NoticeCard(
          icon: Icons.warning_amber_rounded,
          color: brandRed,
          title: 'Peringatan risiko stunting',
          text: 'Z-score TB/U ${fmtZ(result.zHeightForAge)} berada di bawah -2 SD. Hasil ini bukan diagnosis; '
              'segera konsultasikan dengan tenaga kesehatan.',
          action: showConsultButton
              ? FilledButton.tonal(onPressed: () => context.go('/app?tab=2'), child: const Text('Konsultasi sekarang'))
              : null,
        ),
      GwCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          row(Indicator.heightForAge, result.zHeightForAge),
          row(Indicator.weightForAge, result.zWeightForAge),
          row(Indicator.weightForHeight, result.zWeightForHeight),
        ]),
      ),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 3, color: c),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(fontSize: 11)),
        ]);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 12, runSpacing: 4, alignment: WrapAlignment.center, children: [
        item(const Color(0xFFC62828), '-3 SD'),
        item(const Color(0xFFEF6C00), '-2 SD'),
        item(const Color(0xFF2E7D32), 'Median'),
        item(const Color(0xFFEF6C00).withValues(alpha: 0.5), '+2 SD'),
        item(brandBlue, 'Anak'),
      ]),
    );
  }
}


/// Grafik dengan kurva acuan WHO (dihitung dari parameter LMS) dan titik pengukuran anak.
class GrowthChart extends StatelessWidget {
  const GrowthChart({super.key, required this.child, required this.measurements, required this.indicator});
  final Child child;
  final List<Measurement> measurements;
  final Indicator indicator;

  @override
  Widget build(BuildContext context) {
    final byLength = indicator == Indicator.weightForHeight;
    // Sumbu X: umur (bulan) untuk TB/U & BB/U, panjang badan (cm) untuk BB/TB.
    double xOf(Measurement m) => byLength ? m.heightCm : m.result.ageDays / 30.4375;
    double yOf(Measurement m) => indicator == Indicator.heightForAge ? m.heightCm : m.weightKg;

    final pts = measurements.where((m) => !byLength || (m.heightCm >= minLengthCm && m.heightCm <= maxLengthCm)).toList();
    late double minX, maxX;
    if (byLength) {
      final hs = pts.map((m) => m.heightCm);
      minX = math.max(minLengthCm, (hs.isEmpty ? 60 : hs.reduce(math.min)) - 8);
      maxX = math.min(maxLengthCm, (hs.isEmpty ? 80 : hs.reduce(math.max)) + 8);
    } else {
      minX = 0;
      maxX = 24;
    }

    List<FlSpot> curve(double z) {
      final spots = <FlSpot>[];
      final step = byLength ? 0.5 : 0.5;
      for (var x = minX; x <= maxX + 1e-9; x += step) {
        final key = byLength ? x : x * 30.4375;
        spots.add(FlSpot(x, lmsFor(indicator, child.sex, key).valueAt(z)));
      }
      return spots;
    }

    LineChartBarData ref(double z, Color c, {double width = 1.5}) =>
        LineChartBarData(spots: curve(z), color: c, barWidth: width, dotData: const FlDotData(show: false), isCurved: true);

    final childLine = LineChartBarData(
      spots: [for (final m in pts) FlSpot(xOf(m), yOf(m))],
      color: brandBlue,
      barWidth: 2.5,
      dotData: const FlDotData(show: true),
    );

    final lines = [
      ref(-3, const Color(0xFFC62828)),
      ref(-2, const Color(0xFFEF6C00)),
      ref(0, const Color(0xFF2E7D32), width: 2),
      ref(2, const Color(0xFFEF6C00).withValues(alpha: 0.5)),
      childLine,
    ];
    final ys = [for (final l in lines) for (final s in l.spots) s.y];
    final minY = (ys.reduce(math.min) - 1).floorToDouble();
    final maxY = (ys.reduce(math.max) + 1).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineBarsData: lines,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(byLength ? 'Panjang/tinggi badan (cm)' : 'Umur (bulan)', style: const TextStyle(fontSize: 11)),
            sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: byLength ? 5 : 3,
                getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(indicator == Indicator.heightForAge ? 'cm' : 'kg', style: const TextStyle(fontSize: 11)),
            sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------- Input manual hasil timbang & ukur
class AddMeasurementPage extends ConsumerStatefulWidget {
  const AddMeasurementPage({super.key, required this.childId});
  final String childId;
  @override
  ConsumerState<AddMeasurementPage> createState() => _AddMeasurementPageState();
}

class _AddMeasurementPageState extends ConsumerState<AddMeasurementPage> {
  DateTime _date = DateTime.now();
  final _w = TextEditingController();
  final _h = TextEditingController();

  void _save() {
    final child = ref.read(childrenProvider.notifier).byId(widget.childId);
    final w = parseNum(_w.text), h = parseNum(_h.text);
    if (w == null || h == null) {
      return showError(context, ArgumentError('Berat dan panjang/tinggi badan wajib diisi angka, contoh 8,5 dan 72,5.'));
    }
    try {
      final m = ref.read(measurementsProvider.notifier).add(child: child, date: _date, weightKg: w, heightCm: h);
      final info = statusOf(m.result);
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Row(children: [const Expanded(child: Text('Hasil pengukuran')), StatusPill(info.status)]),
          content: SingleChildScrollView(child: ResultSummary(result: m.result, showConsultButton: false)),
          actions: [
            if (m.result.stuntingRisk)
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.go('/app?tab=2');
                },
                child: const Text('Konsultasi'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                context.pop();
              },
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
    } on RangeError {
      showError(context, ArgumentError('Umur anak pada tanggal ukur di luar cakupan pemantauan 0–24 bulan.'));
    } catch (e) {
      showError(context, e);
    }
  }

  InputDecoration _dec(String label, String hint, {String? helper}) => InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      );

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(childrenProvider).firstWhere((c) => c.id == widget.childId);
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Catat Pertumbuhan')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Isi hasil timbang dan ukur ${child.name} dari posyandu/puskesmas.', style: const TextStyle(color: textGray)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
          ),
          icon: const Icon(Icons.event),
          label: Text('Tanggal pengukuran: ${fmtDmy(_date)}'),
          onPressed: () async {
            final d = await showDatePicker(context: context, firstDate: child.birthDate, lastDate: DateTime.now(), initialDate: _date);
            if (d != null) setState(() => _date = d);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _h,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _dec('Panjang/tinggi badan (cm)', 'contoh 72,5', helper: 'Anak < 2 tahun diukur berbaring (panjang badan)'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _w,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _dec('Berat badan (kg)', 'contoh 8,5'),
        ),
        const SizedBox(height: 24),
        PrimaryButton('Simpan Data', onPressed: _save),
        const SizedBox(height: 12),
        const Text('Z-score dihitung dengan tabel WHO Child Growth Standards (Permenkes 2/2020).',
            style: TextStyle(fontSize: 12, color: textGray)),
      ]),
    );
  }
}
