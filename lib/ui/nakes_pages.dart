import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/zscore.dart';
import '../data/seed.dart';
import '../models.dart';
import '../state/providers.dart';
import '../util/download.dart';
import 'common.dart';

class _Row {
  const _Row(this.child, this.last);
  final Child child;
  final Measurement? last;
  Classification? get cls => last == null ? null : classify(Indicator.heightForAge, last!.result.zHeightForAge);
}

/// Dashboard monitoring baduta binaan (submodul 6, ER-5.1, ER-5.2).
class NakesDashboard extends ConsumerStatefulWidget {
  const NakesDashboard({super.key});
  @override
  ConsumerState<NakesDashboard> createState() => _NakesDashboardState();
}

class _NakesDashboardState extends ConsumerState<NakesDashboard> {
  String _posyandu = 'Semua';

  String _csv(List<_Row> rows) {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('Nama anak,Jenis kelamin,Umur (bulan),Posyandu,Wilayah,Tanggal ukur,BB (kg),TB (cm),Z TB/U,Status TB/U,Z BB/U,Z BB/TB\n');
    for (final r in rows) {
      final m = r.last;
      b.writeln([
        q(r.child.name),
        r.child.sex == Sex.female ? 'P' : 'L',
        (r.child.ageDays / 30.4375).toStringAsFixed(1),
        q(r.child.posyandu),
        q(r.child.region),
        m == null ? '' : m.date.toIso8601String().substring(0, 10),
        m?.weightKg.toString() ?? '',
        m?.heightCm.toString() ?? '',
        m == null ? '' : roundZ(m.result.zHeightForAge).toString(),
        q(r.cls?.label ?? 'Belum diukur'),
        m == null ? '' : roundZ(m.result.zWeightForAge).toString(),
        m?.result.zWeightForHeight == null ? '' : roundZ(m!.result.zWeightForHeight!).toString(),
      ].join(','));
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final sw = Stopwatch()..start();
    final children = ref.watch(childrenProvider).where((c) => _posyandu == 'Semua' || c.posyandu == _posyandu).toList();
    final rows = [for (final c in children) _Row(c, ref.watch(childMeasurementsProvider(c.id)).lastOrNull)]
      ..sort((a, b) => (b.cls?.level ?? -1).compareTo(a.cls?.level ?? -1));
    int count(bool Function(_Row) f) => rows.where(f).length;
    final severe = count((r) => r.last != null && roundZ(r.last!.result.zHeightForAge) < -3);
    final stunted = count((r) => r.last != null && r.last!.result.stuntingRisk) - severe;
    final none = count((r) => r.last == null);
    final normal = rows.length - severe - stunted - none;
    sw.stop();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard baduta binaan'),
        actions: [
          IconButton(
            tooltip: 'Ekspor CSV',
            icon: const Icon(Icons.download),
            onPressed: () async {
              final csv = _csv(rows);
              final name = 'laporan_baduta_${_posyandu.replaceAll(' ', '_').toLowerCase()}.csv';
              if (downloadTextFile(name, csv)) {
                showInfo(context, 'Laporan $name diunduh (${rows.length} baris).');
              } else {
                await Clipboard.setData(ClipboardData(text: csv));
                if (context.mounted) showInfo(context, 'Unduhan belum didukung di platform ini; CSV disalin ke clipboard.');
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          initialValue: _posyandu,
          decoration: const InputDecoration(labelText: 'Filter wilayah / posyandu'),
          items: [
            const DropdownMenuItem(value: 'Semua', child: Text('Semua posyandu')),
            for (final p in posyanduList) DropdownMenuItem(value: p, child: Text('$p (${regionOfPosyandu[p]})')),
          ],
          onChanged: (v) => setState(() => _posyandu = v!),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _Stat('Normal', normal, levelColor(0)),
          _Stat('Pendek', stunted, levelColor(2)),
          _Stat('Sangat pendek', severe, levelColor(3)),
          _Stat('Belum diukur', none, Colors.grey),
        ]),
        const SizedBox(height: 4),
        Text('Status berdasarkan pengukuran TB/U terakhir • ${rows.length} baduta • dimuat dalam ${sw.elapsedMilliseconds} ms',
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SectionTitle('Daftar baduta (berisiko di atas)'),
        for (final r in rows)
          Card(
            child: ListTile(
              onTap: () => context.push('/nakes/child/${r.child.id}'),
              leading: Icon(Icons.child_care, color: r.cls == null ? Colors.grey : levelColor(r.cls!.level)),
              title: Text(r.child.name),
              subtitle: Text('${fmtAge(r.child.ageDays)} • ${r.child.posyandu}'
                  '${r.last == null ? '' : '\nTerakhir ${fmtDate(r.last!.date)} • TB/U ${fmtZ(r.last!.result.zHeightForAge)}'}'),
              isThreeLine: r.last != null,
              trailing: r.cls == null ? const StatusChip('Belum diukur', 1) : StatusChip(r.cls!.label.split(' (').first, r.cls!.level),
            ),
          ),
        const SizedBox(height: 8),
        const Text('Data anak fiktif. Pada tahap Supabase, daftar dibatasi ke posyandu binaan tenaga kesehatan.', style: TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          color: color.withValues(alpha: 0.08),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(children: [
              Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
            ]),
          ),
        ),
      );
}
