import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/nutrition.dart';
import '../core/status.dart';
import '../data/recipes.dart';
import '../models.dart';
import '../state/providers.dart';
import 'common.dart';

/// Jawaban asisten: teks + tautan opsional ke halaman aplikasi.
class AssistantReply {
  const AssistantReply(this.text, {this.linkLabel, this.route});
  final String text;
  final String? linkLabel;
  final String? route;
}

/// SIMULASI "AI pendamping gizi": pencocokan kata kunci ke jawaban draf yang
/// memakai data anak (usia, status). Belum memakai model bahasa; jawaban
/// wajib ditinjau ahli gizi sebelum rilis.
AssistantReply answerQuestion(String q, {Child? child, GrowthStatus? status}) {
  final s = q.toLowerCase();
  final m = child?.ageMonths ?? 0;
  final name = child?.name ?? 'anak';
  bool has(List<String> k) => k.any(s.contains);

  if (has(['demam', 'kejang', 'sesak', 'diare', 'muntah', 'lemas', 'darurat', 'dehidrasi'])) {
    return const AssistantReply(
      'Gejala seperti demam tinggi, kejang, sesak napas, diare atau muntah terus-menerus, dan anak sangat lemas perlu '
      'diperiksa tenaga kesehatan secepatnya. Segera ke puskesmas/IGD terdekat. Asisten ini tidak dapat menilai kondisi darurat.',
      linkLabel: 'Konsultasi dokter',
      route: '/app?tab=2',
    );
  }
  // "asi" sebagai kata utuh, agar "mpasi" tidak ikut cocok.
  if (RegExp(r'\basi\b').hasMatch(s) || has(['menyusu', 'susu formula'])) {
    return AssistantReply(m < 6
        ? '$name berusia di bawah 6 bulan: berikan ASI saja (ASI eksklusif), tanpa air putih, madu, atau makanan lain. Susui sesering bayi mau, siang dan malam.'
        : 'Setelah 6 bulan, ASI tetap dilanjutkan sampai 2 tahun atau lebih, berdampingan dengan MPASI. Berikan MPASI dulu baru ASI saat jam makan bila anak sulit makan.');
  }
  if (has(['susah makan', 'gtm', 'tidak mau makan', 'menolak makan', 'pilih-pilih'])) {
    return const AssistantReply(
      'Tips anak susah makan: (1) jadwal makan teratur, makan maksimal 30 menit; (2) tawarkan porsi kecil dengan tekstur sesuai usia; '
      '(3) hindari memaksa dan distraksi gawai; (4) beri contoh makan bersama keluarga; (5) tawarkan ulang makanan baru 8–15 kali. '
      'Bila berat badan tidak naik 2 bulan berturut-turut, konsultasikan ke tenaga kesehatan.',
      linkLabel: 'Konsultasi dokter',
      route: '/app?tab=2',
    );
  }
  if (has(['protein', 'hewani', 'telur', 'ikan', 'hati', 'daging'])) {
    return const AssistantReply(
      'Protein hewani paling berkaitan dengan pencegahan stunting. Sumber terjangkau: telur, ikan kembung/lele, hati ayam, ayam, dan susu (≥ 12 bulan). '
      'Usahakan ada protein hewani di setiap waktu makan, minimal 2 kali sehari.',
      linkLabel: 'Lihat menu rekomendasi',
      route: '/recipes',
    );
  }
  if (has(['mpasi', 'menu', 'resep', 'makan apa', 'porsi', 'tekstur'])) {
    if (child != null && m < 6) {
      return AssistantReply('$name belum 6 bulan, jadi belum perlu MPASI. MPASI dimulai tepat usia 6 bulan dengan tekstur lumat.');
    }
    final list = child == null ? recipes.take(3).toList() : recipesForAge(m);
    final names = list.take(3).map((r) => r.name).join(', ');
    final freq = m < 9 ? '2–3 kali makan + 1–2 selingan, mulai 2–3 sendok makan' : '3–4 kali makan + 1–2 selingan';
    return AssistantReply('Untuk usia ${m.floor()} bulan: $freq, tekstur ${m < 9 ? 'lumat/disaring' : m < 12 ? 'cincang' : 'makanan keluarga dipotong kecil'}. '
        'Contoh menu: $names.', linkLabel: 'Lihat resep', route: '/recipes');
  }
  if (has(['stunting', 'pendek', 'tinggi badan', 'panjang badan', 'status', 'merah', 'kurang'])) {
    final st = switch (status) {
      GrowthStatus.kurang => 'Status $name saat ini MERAH (Kurang). Segera bawa ke puskesmas untuk pemeriksaan dan rencana perbaikan gizi.',
      GrowthStatus.waspada => 'Status $name saat ini KUNING (Waspada): mendekati batas bawah. Perbaiki asupan dan ukur ulang bulan depan.',
      GrowthStatus.lebih => 'Berat $name di atas standar untuk panjang badannya; konsultasikan pola makan.',
      GrowthStatus.normal => 'Status $name saat ini HIJAU (Normal). Pertahankan dan timbang rutin setiap bulan.',
      null => 'Catat berat dan panjang badan untuk melihat statusnya.',
    };
    return AssistantReply('Stunting ditandai panjang/tinggi badan menurut umur di bawah -2 SD standar WHO. $st',
        linkLabel: 'Lihat grafik pertumbuhan', route: child == null ? null : '/child/${child.id}');
  }
  if (has(['kalori', 'energi', 'akg', 'kebutuhan'])) {
    final akg = akgForAgeMonths(m);
    final mp = mpasiEnergyTarget(m);
    return AssistantReply('AKG ${akg.group.toLowerCase()} (Permenkes 28/2019): ${akg.kcal.round()} kkal dan protein ${akg.protein.round()} g per hari. '
        '${mp == null ? 'Seluruhnya dari ASI.' : 'Bila masih menyusu, sekitar ${mp.round()} kkal dari MPASI dan sisanya dari ASI.'}',
        linkLabel: 'Lihat laporan gizi', route: child == null ? null : '/child/${child.id}/nutrition');
  }
  return const AssistantReply(
    'Maaf, saya belum bisa menjawab pertanyaan itu. Coba tanyakan tentang MPASI, protein hewani, ASI, anak susah makan, '
    'kebutuhan kalori, atau status pertumbuhan. Untuk keluhan kesehatan, konsultasikan dengan dokter.',
    linkLabel: 'Konsultasi dokter',
    route: '/app?tab=2',
  );
}

class _Msg {
  const _Msg(this.mine, this.reply);
  final bool mine;
  final AssistantReply reply;
}

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});
  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _text = TextEditingController();
  final List<_Msg> _msgs = [];

  void _ask(String q) {
    if (q.trim().isEmpty) return;
    final child = ref.read(activeChildProvider);
    final last = child == null ? null : ref.read(childMeasurementsProvider(child.id)).lastOrNull;
    final status = last == null ? null : statusOf(last.result).status;
    setState(() {
      _msgs.add(_Msg(true, AssistantReply(q.trim())));
      _msgs.add(_Msg(false, answerQuestion(q, child: child, status: status)));
    });
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);
    const chips = ['Menu MPASI untuk anak saya', 'Sumber protein hewani', 'Anak susah makan', 'Kebutuhan kalori', 'Apa arti status anak saya?'];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(children: [
          CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Icon(Icons.forum_rounded, color: brandBlue)),
          SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Asisten Ahli Gizi', style: TextStyle(fontSize: 18)),
            Text('AI pendamping gizi anak • simulasi', style: TextStyle(fontSize: 12.5, color: Colors.white70)),
          ]),
        ]),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: const Color(0xFFFEF9C3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: const Text('Prototype: jawaban berbasis aturan dan konten draf, bukan model AI, dan tidak menggantikan saran tenaga kesehatan.',
              style: TextStyle(fontSize: 12, color: Color(0xFF713F12))),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _bubble(AssistantReply('Halo! Saya asisten gizi GroWell${child == null ? '' : ' untuk ${child.name} (${fmtAge(child.ageDays)})'}. '
                'Mau tanya apa hari ini?'), false),
            for (final m in _msgs) _bubble(m.reply, m.mine),
          ]),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final c in chips) Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(c), onPressed: () => _ask(c))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _text,
                onSubmitted: _ask,
                decoration: InputDecoration(
                  hintText: 'Tulis pertanyaan...',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              tooltip: 'Kirim',
              style: IconButton.styleFrom(backgroundColor: brandBlue, fixedSize: const Size(52, 52)),
              onPressed: () => _ask(_text.text),
              icon: const Icon(Icons.send_outlined, color: Colors.white),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _bubble(AssistantReply r, bool mine) {
    final child = ref.read(activeChildProvider);
    String? route = r.route;
    if (route == '/recipes') route = child == null ? null : '/child/${child.id}/recipes';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: mine ? brandBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.text, style: TextStyle(color: mine ? Colors.white : textDark, fontSize: 15, height: 1.4)),
          if (!mine && route != null && r.linkLabel != null)
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              onPressed: () => route!.startsWith('/app') ? context.go(route) : context.push(route),
              child: Text('${r.linkLabel} ›'),
            ),
        ]),
      ),
    );
  }
}
