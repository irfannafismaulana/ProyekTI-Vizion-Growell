import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/nutrition.dart';
import '../core/status.dart';
import '../data/foods.dart';
import '../data/recipes.dart';
import '../models.dart';
import '../state/providers.dart';
import '../util/download.dart';
import 'common.dart';

/// Gram ditampilkan bulat bila ≥ 10, satu desimal bila kecil.
String fmtG(double x) => x >= 10 ? x.round().toString() : fmtNum(x);

Meal mealForNow([DateTime? t]) {
  final h = (t ?? DateTime.now()).hour;
  if (h < 10) return Meal.pagi;
  if (h < 15) return Meal.siang;
  if (h < 18) return Meal.selingan;
  return Meal.malam;
}

/// Pemberitahuan untuk bayi < 6 bulan (ER-2.3).
class ExclusiveBreastfeedingNotice extends StatelessWidget {
  const ExclusiveBreastfeedingNotice({super.key, required this.child});
  final Child child;
  @override
  Widget build(BuildContext context) => NoticeCard(
        icon: Icons.child_friendly,
        color: brandBlue,
        title: 'ASI eksklusif sampai 6 bulan',
        text: '${child.name} berusia ${fmtAge(child.ageDays)}. Sampai usia 6 bulan bayi cukup diberi ASI saja, '
            'tanpa makanan atau minuman lain. Pencatatan makanan dimulai saat MPASI (6 bulan).',
        action: FilledButton.tonal(onPressed: () => context.push('/article/a3'), child: const Text('Baca: ASI eksklusif 6 bulan')),
      );
}

// ================================================================ Gizi Harian Anak (foto makanan)
class _Item {
  _Item(this.foodId, this.grams);
  String foodId;
  double grams;
}

enum _FoodStep { idle, analyzing, result }

class FoodPhotoPage extends ConsumerStatefulWidget {
  const FoodPhotoPage({super.key, required this.childId});
  final String childId;
  @override
  ConsumerState<FoodPhotoPage> createState() => _FoodPhotoPageState();
}

class _FoodPhotoPageState extends ConsumerState<FoodPhotoPage> {
  _FoodStep _step = _FoodStep.idle;
  Uint8List? _photo;
  bool _sample = false;
  DateTime? _time;
  List<_Item> _items = [];
  Meal _meal = mealForNow();

  Child get _child => ref.read(childrenProvider.notifier).byId(widget.childId);

  ImageProvider? get _image => _photo != null ? MemoryImage(_photo!) : (_sample ? const AssetImage('assets/food_sample.jpg') : null);

  Future<void> _choose() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Kamera'), onTap: () => Navigator.pop(c, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Galeri'), onTap: () => Navigator.pop(c, 'gallery')),
          ListTile(leading: const Icon(Icons.image_outlined), title: const Text('Pakai foto contoh (demo)'), onTap: () => Navigator.pop(c, 'sample')),
        ]),
      ),
    );
    if (source == null) return;
    if (source == 'sample') {
      _photo = null;
      _sample = true;
    } else {
      try {
        final x = await ImagePicker().pickImage(source: source == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1280);
        if (x == null) return;
        _photo = await x.readAsBytes();
        _sample = false;
      } catch (_) {
        if (mounted) showError(context, ArgumentError('Kamera/galeri tidak dapat dibuka di perangkat ini.'));
        return;
      }
    }
    await _analyze();
  }

  /// SIMULASI deteksi: prototype belum memakai model AI pengenal makanan.
  Future<void> _analyze() async {
    setState(() => _step = _FoodStep.analyzing);
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final m = _child.ageMonths;
    _items = _sample
        ? [_Item('nasi', 60), _Item('telur', 50), _Item('timun', 20), _Item('wortel', 10)]
        : m < 9
            ? [_Item('bubur', 100), _Item('telur', 20), _Item('wortel', 15)]
            : m < 12
                ? [_Item('nasi', 60), _Item('ayam', 20), _Item('bayam', 20)]
                : [_Item('nasi', 80), _Item('ikan', 30), _Item('brokoli', 25)];
    _time = DateTime.now();
    _meal = mealForNow(_time);
    setState(() => _step = _FoodStep.result);
  }

  void _reset() => setState(() {
        _step = _FoodStep.idle;
        _photo = null;
        _sample = false;
        _items = [];
      });

  NutrientTotal get _total => _items.fold(const NutrientTotal(), (a, i) {
        final f = foodById(i.foodId);
        final k = i.grams / 100;
        return a + NutrientTotal(kcal: f.kcal * k, protein: f.protein * k, carb: f.carb * k, fat: f.fat * k, fiber: f.fiber * k);
      });

  void _save() {
    if (_items.isEmpty) return showError(context, ArgumentError('Belum ada makanan. Tambahkan minimal satu makanan.'));
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    try {
      ref.read(foodLogProvider.notifier).addAll([
        for (final i in _items)
          FoodEntry(id: newId('f'), childId: widget.childId, date: day, meal: _meal, foodId: i.foodId, grams: i.grams),
      ]);
      showInfo(context, 'Makanan ${_meal.label.toLowerCase()} tersimpan.');
      context.pushReplacement('/child/${widget.childId}/nutrition');
    } catch (e) {
      showError(context, e);
    }
  }

  Future<void> _addFood() async {
    final id = await pickFood(context);
    if (id != null) setState(() => _items.add(_Item(id, 30)));
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(childrenProvider).firstWhere((c) => c.id == widget.childId);
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Gizi Harian Anak')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 40), children: [
        if (needsExclusiveBreastfeeding(child.ageMonths))
          ExclusiveBreastfeedingNotice(child: child)
        else ...[
          const Text('Foto Makanan Anak', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
          const SizedBox(height: 16),
          _frame(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: PrimaryButton('Foto Makanan', icon: Icons.photo_camera_outlined, onPressed: _step == _FoodStep.analyzing ? null : _choose)),
            const SizedBox(width: 12),
            SizedBox(
              width: 54,
              height: 54,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _reset,
                child: const Icon(Icons.sync, color: Color(0xFF374151), size: 28),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (_step != _FoodStep.result)
            const TipsBox(title: 'Tips Foto Terbaik:', items: [
              'Gunakan pencahayaan yang cukup dan hindari bayangan berlebih',
              'Posisikan kamera tegak lurus dari atas atau sedikit miring',
              'Jaga jarak ± 30–50 cm dari makanan agar detail terlihat jelas',
              'Pastikan makanan terlihat utuh dan tidak terpotong',
              'Gunakan latar belakang polos bila memungkinkan',
              'Hindari filter, flash berlebihan, atau efek kamera',
            ])
          else
            ..._resultSection(),
        ],
      ]),
    );
  }

  Widget _frame() {
    final img = _image;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: _step == _FoodStep.idle ? Border.all(color: brandBlue, width: 1.5) : null,
          color: const Color(0xFF6B7280),
          image: DecorationImage(
            image: img ?? const AssetImage('assets/food_sample.jpg'),
            fit: BoxFit.cover,
            colorFilter: _step == _FoodStep.result ? null : const ColorFilter.mode(Color(0x99000000), BlendMode.darken),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _step == _FoodStep.idle ? _choose : null,
            child: switch (_step) {
              _FoodStep.idle => const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.photo_camera_outlined, color: brandBlue, size: 56),
                  SizedBox(height: 10),
                  Text('Ambil Foto Makanan', style: TextStyle(color: brandBlue, fontSize: 20, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('AI akan mengestimasi nutrisi otomatis', style: TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              _FoodStep.analyzing => const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(alignment: Alignment.center, children: [
                      CircleAvatar(radius: 42, backgroundColor: Color(0xFF4A9BFF), child: Icon(Icons.computer, color: Colors.white, size: 40)),
                      SizedBox(width: 84, height: 84, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                    ]),
                  ),
                  SizedBox(height: 18),
                  Text('Menganalisis dengan AI', style: TextStyle(color: Colors.white, fontSize: 20)),
                  SizedBox(height: 6),
                  Text('Mendeteksi kandungan gizi', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
              _FoodStep.result => Stack(children: [
                  const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircleAvatar(radius: 34, backgroundColor: Colors.white, child: Icon(Icons.check, color: Color(0xFF16A34A), size: 40)),
                      SizedBox(height: 8),
                      Text('Foto tersimpan',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 6)])),
                    ]),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xCC333333), borderRadius: BorderRadius.circular(20)),
                        child: Text('Timestamp: ${_stamp(_time!)}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ),
                  ),
                ]),
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _resultSection() {
    final t = _total;
    Widget row(String k, String v, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F3F5)))),
          child: Row(children: [
            Expanded(child: Text(k, style: const TextStyle(fontSize: 16, color: Color(0xFF374151)))),
            Text(v, style: const TextStyle(fontSize: 16, color: textDark)),
          ]),
        );
    return [
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 12),
        child: Text('Estimasi Gizi (Simulasi)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
      ),
      GwCard(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          row('Karbohidrat', '${fmtG(t.carb)} g'),
          row('Protein', '${fmtG(t.protein)} g'),
          row('Lemak', '${fmtG(t.fat)} g'),
          row('Serat', '${fmtG(t.fiber)} g'),
          row('Kalori', '${t.kcal.round()} kcal', last: true),
          const SizedBox(height: 8),
          const Text(
            'Catatan: Deteksi ini adalah simulasi. Diperlukan integrasi dengan model AI untuk hasil yang akurat. '
            'Periksa daftar makanan di bawah dan koreksi bila tidak sesuai.',
            style: TextStyle(fontStyle: FontStyle.italic, color: textGray, fontSize: 13),
          ),
        ]),
      ),
      const SectionTitle('Makanan terdeteksi'),
      GwCard(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Column(children: [
          for (final i in _items)
            Row(children: [
              Expanded(child: Text(foodById(i.foodId).name, style: const TextStyle(fontSize: 14.5))),
              IconButton(
                tooltip: 'Kurangi',
                onPressed: i.grams > 5 ? () => setState(() => i.grams -= 5) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(width: 52, child: Text('${fmtShort(i.grams)} g', textAlign: TextAlign.center)),
              IconButton(tooltip: 'Tambah', onPressed: () => setState(() => i.grams += 5), icon: const Icon(Icons.add_circle_outline)),
              IconButton(
                tooltip: 'Hapus',
                onPressed: () => setState(() => _items.remove(i)),
                icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
              ),
            ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _addFood, icon: const Icon(Icons.add), label: const Text('Tambah makanan')),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        for (final m in Meal.values)
          ChoiceChip(label: Text(m.label), selected: _meal == m, onSelected: (_) => setState(() => _meal = m)),
      ]),
      const SizedBox(height: 18),
      PrimaryButton('Simpan & Lihat Perkembangan', onPressed: _save),
      const SizedBox(height: 12),
      SecondaryButton('Bagikan sebagai Postingan', icon: Icons.share_outlined, outlined: true, onPressed: () {
        if (_items.isEmpty) return;
        showPostPreview(context, image: _image!, time: _time!, total: _total);
      }),
    ];
  }
}

String _stamp(DateTime t) => '${t.year}-${two(t.month)}-${two(t.day)} ${fmtTime(t)}';

/// Pilih jenis makanan dari tabel pangan.
Future<String?> pickFood(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (c, scroll) => ListView(controller: scroll, children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('Pilih makanan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        for (final g in {for (final f in foods) f.group}) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text(g, style: const TextStyle(color: textGray, fontWeight: FontWeight.w600))),
          for (final f in foods.where((f) => f.group == g))
            ListTile(
              dense: true,
              title: Text(f.name),
              subtitle: Text('${f.kcal.round()} kkal • protein ${fmtNum(f.protein)} g per 100 g'),
              onTap: () => Navigator.pop(c, f.id),
            ),
        ],
      ]),
    ),
  );
}

// ================================================================ Preview Postingan
void showPostPreview(BuildContext context, {required ImageProvider image, required DateTime time, required NutrientTotal total}) {
  final key = GlobalKey();
  String two2(double x) => x.toStringAsFixed(2).replaceAll('.', ',');
  final lines = [
    'Karbohidrat: ${two2(total.carb)} g',
    'Protein: ${two2(total.protein)} g',
    'Lemak: ${two2(total.fat)} g',
    'Serat: ${two2(total.fiber)} g',
    'Kalori: ${two2(total.kcal)} kcal',
  ];
  showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(children: [
                const Expanded(child: Text('Preview Postingan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                IconButton(tooltip: 'Tutup', onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close, size: 28)),
              ]),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: key,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Stack(fit: StackFit.expand, children: [
                        Image(image: image, fit: BoxFit.cover),
                        Positioned(
                          right: 6,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xDD333333), borderRadius: BorderRadius.circular(20)),
                            child: Text(_stamp(time), style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                          ),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Analisis Gizi Makanan', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        for (final l in lines)
                          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(l, style: const TextStyle(color: Color(0xFF374151)))),
                        const Divider(height: 24),
                        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          AppLogo(height: 26, iconOnly: true),
                          SizedBox(width: 8),
                          Text('Generated by Growell', style: TextStyle(color: textGray)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(children: [
                PrimaryButton('Download Gambar', icon: Icons.download_outlined, color: const Color(0xFF1E88E5), onPressed: () async {
                  final ro = key.currentContext?.findRenderObject();
                  if (ro is! RenderRepaintBoundary) return;
                  final img = await ro.toImage(pixelRatio: 2);
                  final data = await img.toByteData(format: ui.ImageByteFormat.png);
                  if (data == null) return;
                  final ok = downloadBytes('growell_gizi_${_stamp(time).replaceAll(RegExp('[^0-9]'), '')}.png', data.buffer.asUint8List(),
                      mime: 'image/png');
                  if (c.mounted) showInfo(c, ok ? 'Gambar diunduh.' : 'Unduhan belum didukung di perangkat ini.');
                }),
                const SizedBox(height: 10),
                SecondaryButton('Bagikan ke Media Sosial', icon: Icons.share_outlined, outlined: true, onPressed: () async {
                  final ok = await shareText('Analisis Gizi Makanan', 'Analisis Gizi Makanan (${_stamp(time)})\n${lines.join('\n')}\nGenerated by Growell');
                  if (c.mounted) showInfo(c, ok ? 'Siap dibagikan (teks disalin bila menu berbagi tidak tersedia).' : 'Berbagi belum didukung.');
                }),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ================================================================ Laporan Gizi Harian Anak
const _dayShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

class NutritionPage extends ConsumerStatefulWidget {
  const NutritionPage({super.key, required this.childId});
  final String childId;
  @override
  ConsumerState<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends ConsumerState<NutritionPage> {
  bool _monthly = false;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(childrenProvider).firstWhere((c) => c.id == widget.childId);
    final log = ref.watch(foodLogProvider).where((e) => e.childId == child.id).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    NutrientTotal dayTotal(DateTime d) => totalOf(log.where((e) => sameDay(e.date, d)));
    final todayEntries = log.where((e) => sameDay(e.date, today)).toList();
    final t = totalOf(todayEntries);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Laporan Gizi Harian Anak')),
      floatingActionButton: needsExclusiveBreastfeeding(child.ageMonths)
          ? null
          : FloatingActionButton(
              tooltip: 'Catat makanan',
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              onPressed: () => context.push('/child/${child.id}/food'),
              child: const Icon(Icons.add, size: 32),
            ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 100), children: [
        if (needsExclusiveBreastfeeding(child.ageMonths))
          ExclusiveBreastfeedingNotice(child: child)
        else ...[
          GwCard(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ringkasan Hari Ini • ${child.name}', style: const TextStyle(color: textGray)),
              const SizedBox(height: 4),
              Text('Kalori: ${t.kcal.round()} kcal', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black)),
            ]),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.1,
            children: [
              for (final (k, v) in [('Protein', t.protein), ('Karbohidrat', t.carb), ('Lemak', t.fat), ('Serat', t.fiber)])
                MacroTile(label: k, value: '${fmtG(v)} g', color: macroColors[k]!.$1, bg: macroColors[k]!.$2),
            ],
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _TabButton('Tren 7 Hari', !_monthly, () => setState(() => _monthly = false))),
            const SizedBox(width: 12),
            Expanded(child: _TabButton('Tren Bulanan', _monthly, () => setState(() => _monthly = true))),
          ]),
          const SizedBox(height: 16),
          GwCard(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: _monthly ? _monthlyChart(log) : _weeklyChart(today, dayTotal),
          ),
          const SizedBox(height: 6),
          _AdequacyCard(child: child, today: t),
          const SectionTitle('Catatan makan hari ini'),
          if (todayEntries.isEmpty)
            const Text('Belum ada catatan hari ini. Tekan + untuk memotret makanan.', style: TextStyle(color: textGray))
          else
            for (final m in Meal.values)
              if (todayEntries.any((e) => e.meal == m))
                GwCard(
                  padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    for (final e in todayEntries.where((e) => e.meal == m))
                      Row(children: [
                        Expanded(child: Text('${foodById(e.foodId).name} • ${fmtShort(e.grams)} g')),
                        Text('${nutrientsOf(e).kcal.round()} kkal', style: const TextStyle(color: textGray)),
                        IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => ref.read(foodLogProvider.notifier).remove(e.id),
                        ),
                      ]),
                  ]),
                ),
        ],
      ]),
    );
  }

  Widget _weeklyChart(DateTime today, NutrientTotal Function(DateTime) dayTotal) {
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final totals = [for (final d in days) dayTotal(d)];
    return _TrendChart(
      title: 'Tren 7 hari',
      labels: [for (final d in days) _dayShort[d.weekday - 1]],
      totals: totals,
    );
  }

  Widget _monthlyChart(List<FoodEntry> log) {
    // Rata-rata asupan harian per minggu dalam bulan terpilih (M1 = tanggal 1–7, dst.), hanya hari yang punya catatan.
    final weeks = <NutrientTotal>[];
    final labels = <String>[];
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    for (var w = 0; w * 7 < daysInMonth; w++) {
      final days = [
        for (var d = w * 7 + 1; d <= math.min(daysInMonth, w * 7 + 7); d++) DateTime(_month.year, _month.month, d),
      ];
      final withData = days.where((d) => log.any((e) => sameDay(e.date, d))).toList();
      final sum = withData.fold(const NutrientTotal(), (a, d) => a + totalOf(log.where((e) => sameDay(e.date, d))));
      final n = math.max(1, withData.length);
      weeks.add(NutrientTotal(kcal: sum.kcal / n, protein: sum.protein / n, carb: sum.carb / n, fat: sum.fat / n, fiber: sum.fiber / n));
      labels.add('M${w + 1}');
    }
    final now = DateTime.now();
    final canNext = _month.isBefore(DateTime(now.year, now.month));
    return _TrendChart(
      title: 'Tren ${monthsLong[_month.month - 1]} ${_month.year}',
      labels: labels,
      totals: weeks,
      onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
      onNext: canNext ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null,
      monthly: true,
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: selected ? const Color(0xFF2E7EFE) : Colors.transparent,
            foregroundColor: selected ? Colors.white : const Color(0xFF4B5563),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 16),
          ),
          onPressed: onTap,
          child: Text(label),
        ),
      );
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.title, required this.labels, required this.totals, this.onPrev, this.onNext, this.monthly = false});
  final String title;
  final List<String> labels;
  final List<NutrientTotal> totals;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool monthly;

  static const _carb = Color(0xFF2E7EFE);
  static const _prot = Color(0xFF10B981);
  static const _fib = Color(0xFFF59E0B);
  static const _fat = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final withData = totals.where((t) => t.kcal > 0).toList();
    double avg(double Function(NutrientTotal) f) => withData.isEmpty ? 0 : withData.map(f).reduce((a, b) => a + b) / withData.length;
    Widget legend(Color c, String name, double v) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 3), child: CircleAvatar(radius: 7, backgroundColor: c)),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 15)),
              Text('Rata-rata: ${fmtG(v)}g', style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12.5)),
            ]),
          ),
        ]);
    LineChartBarData line(double Function(NutrientTotal) f, Color c, {bool area = false}) => LineChartBarData(
          spots: [for (var i = 0; i < totals.length; i++) FlSpot(i.toDouble(), f(totals[i]))],
          color: c,
          barWidth: 2.5,
          isCurved: true,
          preventCurveOverShooting: true,
          dotData: FlDotData(show: !area),
          belowBarData: area
              ? BarAreaData(
                  show: true,
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.withValues(alpha: 0.18), c.withValues(alpha: 0.02)]),
                )
              : BarAreaData(show: false),
        );
    final maxV = totals.fold<double>(0, (m, t) => math.max(m, math.max(t.carb, math.max(t.protein, math.max(t.fat, t.fiber)))));
    final maxY = maxV <= 0 ? 10.0 : (maxV * 1.2 / 5).ceil() * 5.0;
    const names = ['Karbohidrat', 'Protein', 'Serat', 'Lemak'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (monthly)
        Row(children: [
          IconButton(tooltip: 'Bulan sebelumnya', onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          IconButton(tooltip: 'Bulan berikutnya', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ])
      else
        Padding(padding: const EdgeInsets.only(left: 6), child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(children: [
          Row(children: [Expanded(child: legend(_carb, 'Karbo', avg((t) => t.carb))), Expanded(child: legend(_prot, 'Protein', avg((t) => t.protein)))]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: legend(_fib, 'Serat', avg((t) => t.fiber))), Expanded(child: legend(_fat, 'Lemak', avg((t) => t.fat)))]),
        ]),
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 230,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            minX: 0,
            maxX: (totals.length - 1).toDouble(),
            lineBarsData: [
              line((t) => t.carb, _carb, area: true),
              line((t) => t.protein, _prot),
              line((t) => t.fiber, _fib),
              line((t) => t.fat, _fat),
            ],
            borderData: FlBorderData(show: false),
            gridData: FlGridData(drawVerticalLine: false, horizontalInterval: maxY / 4, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE5E7EB), strokeWidth: 1)),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: maxY / 4,
                  getTitlesWidget: (v, m) => Text(v.round().toString(), style: const TextStyle(color: textGray, fontSize: 12)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 26,
                  getTitlesWidget: (v, m) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[v.toInt()], style: const TextStyle(color: textGray, fontSize: 12.5)),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFFFDFDFD),
                tooltipBorder: const BorderSide(color: Color(0xFFD1D5DB)),
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${s.barIndex == 0 ? '${labels[s.x.toInt()]}\n' : ''}${names[s.barIndex]}: ${fmtG(s.y)}g',
                      TextStyle(color: [_carb, _prot, _fib, _fat][s.barIndex], fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: tipsBg, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.info_outline, color: brandBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Cara Membaca Grafik ${monthly ? 'Bulanan' : '7 Hari'}', style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Text(
            monthly
                ? 'Setiap titik (M1–M5) adalah rata-rata asupan harian pada minggu itu, dihitung dari hari yang memiliki catatan. '
                    'Ketuk grafik untuk melihat angka tiap zat gizi.'
                : 'Setiap titik adalah total asupan satu hari dari catatan makan. Hari tanpa catatan bernilai 0. '
                    'Ketuk grafik untuk melihat angka tiap zat gizi.',
            style: const TextStyle(color: Color(0xFF374151), fontSize: 13),
          ),
        ]),
      ),
    ]);
  }
}

/// Kecukupan energi/protein hari ini (ER-2.1/ER-2.2) dan rekomendasi protein hewani.
class _AdequacyCard extends StatelessWidget {
  const _AdequacyCard({required this.child, required this.today});
  final Child child;
  final NutrientTotal today;
  @override
  Widget build(BuildContext context) {
    final akg = akgForAgeMonths(child.ageMonths);
    final mpasi = mpasiEnergyTarget(child.ageMonths);
    final recs = proteinRecommendations();
    Widget bar(String label, double v, double target, String unit) {
      final r = target <= 0 ? 0.0 : (v / target).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label)),
            Text('${v.round()} / ${target.round()} $unit', style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: r,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              color: r >= 1 ? brandGreen : brandBlue,
            ),
          ),
        ]),
      );
    }

    return GwCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Kecukupan hari ini', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        if (mpasi != null) bar('Energi dari MPASI', today.kcal, mpasi, 'kkal'),
        const SizedBox(height: 10),
        Text(
          'Target energi MPASI untuk anak yang masih menyusu (WHO): ${mpasi?.round() ?? '-'} kkal/hari; sisanya dari ASI, yang tidak dicatat. '
          'AKG total ${akg.group.toLowerCase()} (Permenkes 28/2019): ${akg.kcal.round()} kkal dan protein ${akg.protein.round()} g per hari.',
          style: const TextStyle(color: textGray, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        const Text('Sumber protein hewani yang dianjurkan', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in recs)
            Chip(
              avatar: const Icon(Icons.egg_alt_outlined, size: 18, color: brandBlue),
              label: Text('${f.name.split(' (').first} • ${fmtNum(f.protein)} g/100 g'),
            ),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => context.push('/child/${child.id}/recipes'), child: const Text('Lihat menu rekomendasi ›')),
        ),
      ]),
    );
  }
}

// ================================================================ Rekomendasi Makanan
IconData recipeIcon(String id) => switch (id) {
      'bubur_hati' || 'bubur_ayam_kacang_hijau' => Icons.rice_bowl,
      'puree_labu_ikan' || 'nasi_tim_salmon' => Icons.set_meal,
      'bubur_telur_bayam' || 'telur_dadar_sayur' => Icons.egg_alt,
      'puree_pisang_alpukat' => Icons.spa,
      'sup_telur_bayam' => Icons.soup_kitchen,
      'nasi_tim_hati_tempe' => Icons.ramen_dining,
      _ => Icons.icecream,
    };

List<Color> recipeColors(String id) {
  const palettes = [
    [Color(0xFFFFE0C2), Color(0xFFF8B07A)],
    [Color(0xFFD9F2E1), Color(0xFF7CCB97)],
    [Color(0xFFDCE8FF), Color(0xFF86AEFA)],
    [Color(0xFFFCE1EC), Color(0xFFF29BBE)],
    [Color(0xFFFFF2C2), Color(0xFFF2CB54)],
  ];
  return palettes[id.codeUnits.fold(0, (a, b) => a + b) % palettes.length];
}

class RecipeImage extends StatelessWidget {
  const RecipeImage({super.key, required this.recipe, this.size, this.radius = 16, this.iconSize = 44});
  final Recipe recipe;
  final double? size;
  final double radius;
  final double iconSize;
  @override
  Widget build(BuildContext context) {
    final c = recipeColors(recipe.id);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c),
      ),
      child: Icon(recipeIcon(recipe.id), color: Colors.white, size: iconSize, shadows: const [Shadow(color: Color(0x33000000), blurRadius: 6)]),
    );
  }
}

class RecipesPage extends ConsumerWidget {
  const RecipesPage({super.key, required this.childId});
  final String childId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childrenProvider).firstWhere((c) => c.id == childId);
    final last = ref.watch(childMeasurementsProvider(childId)).lastOrNull;
    final status = last == null ? null : statusOf(last.result).status;
    final color = status == null ? brandBlue : statusColor(status);
    final m = child.ageMonths;
    final list = recipesForAge(m);
    final (freq, portion) = m < 9
        ? ('2–3 kali makan utama + 1–2 kali selingan', 'mulai 2–3 sendok makan, bertahap hingga ½ mangkuk 250 ml')
        : m < 12
            ? ('3–4 kali makan utama + 1–2 kali selingan', '½–¾ mangkuk 250 ml')
            : ('3–4 kali makan utama + 1–2 kali selingan', '¾–1 mangkuk 250 ml');
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Rekomendasi Makanan')),
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          color: color,
          padding: const EdgeInsets.fromLTRB(16, 22, 20, 24),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(status == GrowthStatus.normal ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  color: color == brandYellow ? const Color(0xFFD97706) : color, size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(status == null ? 'Menu untuk ${child.name}' : 'Status: ${status.label}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  switch (status) {
                    GrowthStatus.kurang => 'Rekomendasi makanan tinggi kalori dan protein untuk pemulihan gizi',
                    GrowthStatus.waspada => 'Perbanyak protein hewani dan makanan padat energi',
                    GrowthStatus.lebih => 'Menu seimbang; batasi makanan manis dan gorengan',
                    GrowthStatus.normal => 'Menu bergizi seimbang untuk menjaga pertumbuhan optimal',
                    null => 'Menu sesuai usia ${fmtAge(child.ageDays)}',
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.35),
                ),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (needsExclusiveBreastfeeding(m))
              ExclusiveBreastfeedingNotice(child: child)
            else ...[
              TipsBox(
                title: 'Tips Nutrisi',
                bg: const Color(0xFFFEF9C3),
                fg: const Color(0xFF1F2937),
                border: const Color(0xFFFDE047),
                items: [
                  'Berikan makanan dengan protein hewani minimal 2x sehari',
                  'Sertakan sayuran hijau dalam setiap menu',
                  'Usia ${child.ageMonths.floor()} bulan: $freq, porsi $portion',
                  if (m < 12) 'Tanpa gula dan garam tambahan sebelum usia 1 tahun',
                  'Variasikan menu untuk menghindari kebosanan',
                ],
              ),
              const SectionTitle('Menu Rekomendasi'),
              for (final r in list) _RecipeCard(recipe: r, childId: childId),
              const SizedBox(height: 10),
              const Align(alignment: Alignment.centerLeft, child: DraftBadge(text: 'Draf resep — perlu ditinjau ahli gizi')),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.childId});
  final Recipe recipe;
  final String childId;
  @override
  Widget build(BuildContext context) {
    final n = recipeNutrients(recipe);
    return GwCard(
      margin: const EdgeInsets.only(bottom: 14),
      onTap: () => context.push('/recipe/${recipe.id}?child=$childId'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RecipeImage(recipe: recipe, size: 96),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5, color: textDark))),
              const Icon(Icons.chevron_right, color: textGray),
            ]),
            const SizedBox(height: 4),
            Text(recipe.description, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Icon(Icons.schedule, size: 16, color: textGray),
              Text('${recipe.minutes} menit', style: const TextStyle(color: textGray, fontSize: 13)),
              const Text('•', style: TextStyle(color: textGray)),
              Text('${n.kcal.round()} kkal', style: const TextStyle(color: textGray, fontSize: 13)),
              const Text('•', style: TextStyle(color: textGray)),
              Text('${fmtG(n.protein)}g protein', style: const TextStyle(color: textGray, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
              child: Text(recipe.difficulty, style: const TextStyle(color: Color(0xFF15803D), fontSize: 13)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ================================================================ Detail Makanan
class RecipeDetailPage extends ConsumerWidget {
  const RecipeDetailPage({super.key, required this.recipeId, this.childId});
  final String recipeId;
  final String? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = recipeById(recipeId);
    final n = recipeNutrients(r);
    Widget tag(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
          child: Text(t, style: const TextStyle(color: Color(0xFF15803D), fontSize: 14)),
        );
    Widget heading(String t, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 10),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, color: brandBlue), const SizedBox(width: 10)],
            Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark)),
          ]),
        );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Detail Makanan')),
      body: ListView(padding: EdgeInsets.zero, children: [
        SizedBox(height: 240, width: double.infinity, child: RecipeImage(recipe: r, radius: 0, iconSize: 110)),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.schedule, color: Color(0xFF4B5563)),
                const SizedBox(width: 6),
                Text('${r.minutes} menit', style: const TextStyle(fontSize: 15.5, color: Color(0xFF4B5563))),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_outline, color: Color(0xFF4B5563)),
                const SizedBox(width: 6),
                Text('${r.servings} porsi', style: const TextStyle(fontSize: 15.5, color: Color(0xFF4B5563))),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.restaurant, color: brandBlue),
                const SizedBox(width: 6),
                Text('${n.kcal.round()} kcal/porsi', style: const TextStyle(fontSize: 15.5, color: brandBlue, fontWeight: FontWeight.w700)),
              ]),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              if (n.protein >= 8) tag('Bergizi Tinggi'),
              tag(r.difficulty),
              tag('Untuk Anak ${r.minMonths}–${r.maxMonths} bln'),
            ]),
            heading('Deskripsi', icon: Icons.restaurant_menu),
            Text(r.description, style: const TextStyle(fontSize: 15.5, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            Text('Tekstur: ${r.texture}', style: const TextStyle(color: textGray)),
            heading('Informasi Gizi (per porsi)'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: [
                MacroTile(label: 'Protein', value: '${fmtG(n.protein)}g', color: const Color(0xFF1D5BF6), bg: const Color(0xFFEEF4FF)),
                MacroTile(label: 'Karbohidrat', value: '${fmtG(n.carb)}g', color: const Color(0xFF16A34A), bg: const Color(0xFFEFFBF2)),
                MacroTile(label: 'Lemak', value: '${fmtG(n.fat)}g', color: const Color(0xFFCA8A04), bg: const Color(0xFFFEFCE8)),
                MacroTile(label: 'Serat', value: '${fmtG(n.fiber)}g', color: const Color(0xFF9333EA), bg: const Color(0xFFFAF5FF)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: MacroTile(label: 'Vitamin & mineral utama', value: r.vitamins, color: const Color(0xFFEA580C), bg: const Color(0xFFFFF5EC)),
            ),
            heading('Bahan-Bahan'),
            for (final (id, g) in r.ingredients) _Bullet('${foodById(id).name.split(' (').first} — ${fmtShort(g * r.servings)} g'),
            for (final s in r.seasonings) _Bullet(s),
            heading('Cara Membuat'),
            for (var i = 0; i < r.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 13, backgroundColor: brandBlue, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r.steps[i], style: const TextStyle(fontSize: 15, height: 1.4))),
                ]),
              ),
            const SizedBox(height: 8),
            Text('Nilai gizi dihitung dari bahan per porsi (tabel pangan perkiraan). Bahan untuk ${r.servings} porsi.',
                style: const TextStyle(color: textGray, fontSize: 12.5)),
            const SizedBox(height: 8),
            const DraftBadge(text: 'Draf resep — perlu ditinjau ahli gizi'),
            if (childId != null) ...[
              const SizedBox(height: 22),
              PrimaryButton('Catat sebagai Makanan Hari Ini', icon: Icons.playlist_add, onPressed: () {
                final now = DateTime.now();
                final day = DateTime(now.year, now.month, now.day);
                ref.read(foodLogProvider.notifier).addAll([
                  for (final (id, g) in r.ingredients)
                    FoodEntry(id: newId('f'), childId: childId!, date: day, meal: mealForNow(now), foodId: id, grams: g),
                ]);
                showInfo(context, '1 porsi ${r.name} dicatat (${mealForNow(now).label}).');
              }),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          const CircleAvatar(radius: 6, backgroundColor: brandBlue),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15.5, color: Color(0xFF374151)))),
        ]),
      );
}
