import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/status.dart';
import '../models.dart';
import '../state/providers.dart';
import '../util/download.dart';
import 'common.dart';

String _initials(String name) {
  final parts = name.replaceAll(',', ' ').split(' ').where((p) => p.isNotEmpty).toList();
  return parts.take(2).map((p) => p[0]).join();
}

/// "dr. Sarah Wijaya, Sp.A" → "Sp.A"
String _degree(AppUser u) => u.name.contains(',') ? u.name.split(',').last.trim() : (u.specialty ?? '');

/// Bar judul biru di tengah seperti layar "Konsultasi Dokter".
class _CenteredHeader extends StatelessWidget {
  const _CenteredHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: brandBlue,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
      );
}

// ================================================================ Orang tua: Konsultasi Dokter
class ConsultHome extends ConsumerWidget {
  const ConsultHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)!;
    final users = ref.watch(usersProvider);
    // Hanya tenaga kesehatan dengan STR terverifikasi yang tampil (ER-4.2).
    final docs = users.where((u) => u.isVerifiedHealth).toList();
    final notes = ref.watch(consultNotesProvider).where((n) => n.parentId == me.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    return Column(children: [
      const _CenteredHeader('Konsultasi Dokter'),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          for (final d in docs)
            GwCard(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(children: [
                const CircleAvatar(radius: 26, backgroundColor: brandBlue, child: Icon(Icons.person_outline, color: Colors.white, size: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.name, style: const TextStyle(fontSize: 16.5, color: Color(0xFF111827))),
                    const SizedBox(height: 2),
                    Text(d.specialty ?? '', style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14)),
                  ]),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: brandBlue,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    textStyle: const TextStyle(fontSize: 15.5),
                  ),
                  onPressed: () {
                    final t = ref.read(consultProvider.notifier).openThread(parent: me, doctorId: d.id);
                    context.push('/consult/${t.id}');
                  },
                  child: const Text('Konsultasi'),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          const Text('Akun dokter adalah contoh fiktif. Hanya tenaga kesehatan dengan STR terverifikasi yang ditampilkan.',
              style: TextStyle(fontSize: 12, color: textGray)),
          if (notes.isNotEmpty) ...[
            const SectionTitle('Riwayat Konsultasi'),
            for (final n in notes) ConsultNoteTile(note: n),
          ],
        ]),
      ),
    ]);
  }
}

class ConsultNoteTile extends ConsumerWidget {
  const ConsultNoteTile({super.key, required this.note});
  final ConsultNote note;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(usersProvider).firstWhere((u) => u.id == note.doctorId);
    final child = ref.watch(childrenProvider).where((c) => c.id == note.childId).firstOrNull;
    return GwCard(
      onTap: () => context.push('/consult/note/${note.id}'),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: const Color(0xFFFCE7F3), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.description_outlined, color: Color(0xFFBE185D)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(note.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            Text('${doc.name}${child == null ? '' : ' • ${child.name}'}', style: const TextStyle(color: textGray, fontSize: 13)),
            Text('${fmtDmy(note.date)} • ${fmtTime(note.date)}', style: const TextStyle(color: textGray, fontSize: 12)),
          ]),
        ),
        const Icon(Icons.chevron_right, color: textGray),
      ]),
    );
  }
}

// ================================================================ Chat
class ThreadPage extends ConsumerStatefulWidget {
  const ThreadPage({super.key, required this.threadId});
  final String threadId;
  @override
  ConsumerState<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends ConsumerState<ThreadPage> {
  final _text = TextEditingController();

  void _send() {
    final me = ref.read(currentUserProvider)!;
    try {
      ref.read(consultProvider.notifier).send(sender: me, threadId: widget.threadId, text: _text.text);
      _text.clear();
    } catch (e) {
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)!;
    final users = ref.watch(usersProvider);
    final t = ref.watch(consultProvider).where((x) => x.id == widget.threadId).firstOrNull;
    if (t == null || (me.id != t.parentId && me.id != t.doctorId)) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.lock, text: 'Akses tidak diizinkan.'));
    }
    final other = users.firstWhere((u) => u.id == (me.id == t.parentId ? t.doctorId : t.parentId));
    final isParent = me.id == t.parentId;
    final notes = ref.watch(consultNotesProvider).where((n) => n.threadId == t.id).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 0,
        title: Row(children: [
          const CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(Icons.person_outline, color: brandBlue, size: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(other.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              Text(isParent ? (other.specialty ?? '') : 'Orang tua', style: const TextStyle(fontSize: 13.5, color: Colors.white70)),
            ]),
          ),
        ]),
        actions: isParent
            ? [
                IconButton(tooltip: 'Panggilan suara', onPressed: () => context.push('/call/${other.id}'), icon: const Icon(Icons.call_outlined)),
                IconButton(tooltip: 'Video call', onPressed: () => context.push('/call/${other.id}?video=1'), icon: const Icon(Icons.videocam_outlined)),
                const SizedBox(width: 6),
              ]
            : [
                IconButton(
                  tooltip: 'Tulis catatan konsultasi',
                  onPressed: () => context.push('/nakes/note/${t.id}'),
                  icon: const Icon(Icons.note_add_outlined),
                ),
              ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), children: [
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NoticeCard(
                  icon: Icons.description_outlined,
                  title: 'Ringkasan konsultasi: ${n.title}',
                  text: '${fmtDmy(n.date)} • ${n.diagnosis}',
                  action: TextButton(onPressed: () => context.push('/consult/note/${n.id}'), child: const Text('Lihat detail')),
                ),
              ),
            if (t.messages.isEmpty && isParent) _Incoming('Halo, ada yang bisa saya bantu? (pesan otomatis)', null),
            for (final m in t.messages) m.senderId == me.id ? _Outgoing(m.text, m.time) : _Incoming(m.text, m.time),
          ]),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ketik pesan...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 16),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 52,
                height: 52,
                child: IconButton.filled(
                  tooltip: 'Kirim',
                  style: IconButton.styleFrom(backgroundColor: brandBlue),
                  onPressed: _send,
                  icon: const Icon(Icons.send_outlined, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Incoming extends StatelessWidget {
  const _Incoming(this.text, this.time);
  final String text;
  final DateTime? time;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.fromLTRB(16, 8, 0, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: const TextStyle(fontSize: 16, color: Color(0xFF111827), height: 1.45)),
            if (time != null) Text(fmtTime(time!), style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ]),
        ),
      );
}

class _Outgoing extends StatelessWidget {
  const _Outgoing(this.text, this.time);
  final String text;
  final DateTime time;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 290),
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: const BoxDecoration(
            color: brandBlue,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(fmtTime(time), style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ),
      );
}

// ================================================================ Panggilan suara / video (simulasi)
class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key, required this.doctorId, this.video = false});
  final String doctorId;
  final bool video;
  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  bool _connected = false;
  bool _speaker = false;
  bool _muted = false;
  late bool _camera = widget.video;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Prototype: panggilan disimulasikan, tersambung setelah 3 detik.
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _connected = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(usersProvider).firstWhere((u) => u.id == widget.doctorId);
    Widget btn(IconData icon, bool active, VoidCallback onTap, {String? tip}) => Tooltip(
          message: tip ?? '',
          child: Material(
            color: active ? const Color(0xFFDBEAFE) : Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 64, height: 64, child: Icon(icon, color: const Color(0xFF1E88E5), size: 30)),
            ),
          ),
        );
    final status = _connected ? 'Terhubung • ${two(_seconds ~/ 60)}:${two(_seconds % 60)}' : (widget.video ? 'Sedang Memanggil...' : 'Memanggil...');
    return Scaffold(
      backgroundColor: brandBlue,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: brandBlue,
        title: Text(widget.video ? '' : 'Panggilan Suara', style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 21)),
      ),
      body: SafeArea(
        child: Stack(children: [
          if (widget.video)
            Positioned(
              top: 0,
              right: 20,
              child: Container(
                width: 140,
                height: 196,
                decoration: BoxDecoration(
                  color: const Color(0xFF5F5F5F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_camera ? Icons.person : Icons.videocam_off_outlined, color: Colors.white70, size: 56),
                  const SizedBox(height: 6),
                  Text(_camera ? 'Kamera Anda' : 'Kamera mati', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ),
          Align(
            alignment: const Alignment(0, -0.15),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircleAvatar(radius: 64, backgroundColor: Colors.white, child: Icon(Icons.person_outline, color: Color(0xFF1E88E5), size: 70)),
              const SizedBox(height: 30),
              Text(d.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26)),
              const SizedBox(height: 8),
              Text(d.specialty ?? '', style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 24),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (_connected) const Icon(Icons.call_outlined, color: Colors.white, size: 18),
                if (_connected) const SizedBox(width: 8),
                Text(status, style: const TextStyle(color: Colors.white, fontSize: 15)),
              ]),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                btn(_speaker ? Icons.volume_up : Icons.volume_up_outlined, _speaker, () => setState(() => _speaker = !_speaker), tip: 'Speaker'),
                if (widget.video)
                  btn(_camera ? Icons.videocam_outlined : Icons.videocam_off_outlined, !_camera, () => setState(() => _camera = !_camera), tip: 'Kamera'),
                btn(_muted ? Icons.mic_off_outlined : Icons.mic_none, _muted, () => setState(() => _muted = !_muted), tip: 'Mikrofon'),
                Tooltip(
                  message: 'Akhiri panggilan',
                  child: Material(
                    color: const Color(0xFFFF4757),
                    shape: const CircleBorder(),
                    elevation: 6,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.pop(),
                      child: const SizedBox(width: 64, height: 64, child: Icon(Icons.call_end, color: Colors.white, size: 34)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              const Text('Simulasi — panggilan belum tersambung ke layanan nyata.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ================================================================ Detail Konsultasi
class ConsultNotePage extends ConsumerWidget {
  const ConsultNotePage({super.key, required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)!;
    final n = ref.watch(consultNotesProvider).where((x) => x.id == noteId).firstOrNull;
    if (n == null || (me.id != n.parentId && me.id != n.doctorId)) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.lock, text: 'Catatan tidak ditemukan atau akses tidak diizinkan.'));
    }
    final doc = ref.watch(usersProvider).firstWhere((u) => u.id == n.doctorId);
    final child = ref.watch(childrenProvider).where((c) => c.id == n.childId).firstOrNull;
    final appt = child == null ? null : ref.watch(nextAppointmentProvider(child.id));
    Widget section(String title, String text, Color bg, Color fg) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 12),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Text(text.isEmpty ? '-' : text, style: TextStyle(color: fg, fontSize: 15.5, height: 1.5)),
          ),
        ]);
    Future<void> printPdf() async {
      final ok = downloadBytes('konsultasi_${n.date.toIso8601String().substring(0, 10)}.pdf', await _pdf(n, doc, child),
          mime: 'application/pdf');
      if (context.mounted) showInfo(context, ok ? 'PDF diunduh.' : 'Unduhan belum didukung di perangkat ini.');
    }

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Detail Konsultasi'),
        actions: [IconButton(tooltip: 'Cetak PDF', onPressed: printPdf, icon: const Icon(Icons.print_outlined))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 32), children: [
        GwCard(
          padding: const EdgeInsets.all(18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE5E7EB),
              child: Text(_initials(doc.name), style: const TextStyle(color: Color(0xFF374151), fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${doc.name} • ${doc.specialty ?? _degree(doc)}', style: const TextStyle(color: textGray, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${fmtDmy(n.date)} • ${fmtTime(n.date)}${child == null ? '' : ' • ${child.name}'}',
                    style: const TextStyle(color: textGray, fontSize: 13)),
              ]),
            ),
          ]),
        ),
        section('Keterangan', n.keterangan, Colors.white, const Color(0xFF374151)),
        section('Diagnosis', n.diagnosis, const Color(0xFFEFF6FF), const Color(0xFF1E3A8A)),
        section('Resep & Anjuran', n.anjuran, const Color(0xFFFEFCE8), const Color(0xFF854D0E)),
        section('Catatan Penting', n.catatan, const Color(0xFFFDF2F8), const Color(0xFF9D174D)),
        if (appt != null) ...[
          const SizedBox(height: 16),
          NoticeCard(
            icon: Icons.event_available,
            color: const Color(0xFFD97706),
            title: 'Jadwal kontrol berikutnya',
            text: '${fmtDmy(appt.date)} pukul ${fmtTime(appt.date)}',
          ),
        ],
        const SizedBox(height: 24),
        PrimaryButton('Cetak PDF', icon: Icons.print_outlined, onPressed: printPdf),
        const SizedBox(height: 10),
        const Text('Contoh data fiktif. Ringkasan konsultasi tidak menggantikan pemeriksaan langsung.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textGray)),
      ]),
    );
  }
}

/// Font bawaan PDF hanya mendukung Latin-1; ganti tanda baca khusus.
String _latin(String s) => s
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('•', '-')
    .replaceAll('’', "'")
    .replaceAll('≥', '>=')
    .replaceAll('≤', '<=')
    .replaceAll('…', '...');

Future<Uint8List> _pdf(ConsultNote n, AppUser doc, Child? child) async {
  final d = pw.Document(title: 'Detail Konsultasi - ${n.title}', author: 'GroWell');
  pw.Widget sec(String title, String text, PdfColor bg) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.SizedBox(height: 14),
        pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Text(_latin(text.isEmpty ? '-' : text), style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        ),
      ]);
  d.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Text('GroWell - Detail Konsultasi', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF2E7EFE))),
      pw.SizedBox(height: 4),
      pw.Text('Tumbuh Sehat, Tumbuh Hebat', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.Divider(),
      pw.Text(_latin(n.title), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(_latin('${doc.name} - ${doc.specialty ?? ''}')),
      pw.Text(_latin('${fmtDmy(n.date)} ${fmtTime(n.date)}${child == null ? '' : ' - Anak: ${child.name}'}')),
      sec('Keterangan', n.keterangan, PdfColors.grey100),
      sec('Diagnosis', n.diagnosis, PdfColor.fromInt(0xFFEFF6FF)),
      sec('Resep & Anjuran', n.anjuran, PdfColor.fromInt(0xFFFEFCE8)),
      sec('Catatan Penting', n.catatan, PdfColor.fromInt(0xFFFDF2F8)),
      pw.Spacer(),
      pw.Text('Dokumen prototype GroWell - contoh data fiktif. Tidak menggantikan pemeriksaan langsung.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    ]),
  ));
  return d.save();
}

// ================================================================ Tenaga kesehatan: kotak masuk
class NakesInbox extends ConsumerWidget {
  const NakesInbox({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)!;
    final users = ref.watch(usersProvider);
    final threads = ref.watch(consultProvider).where((t) => t.doctorId == me.id).toList();
    final notes = ref.watch(consultNotesProvider).where((n) => n.doctorId == me.id).toList();
    return Column(children: [
      const _CenteredHeader('Konsultasi Masuk'),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          if (threads.isEmpty) const EmptyState(icon: Icons.inbox, text: 'Belum ada konsultasi dari orang tua.'),
          for (final t in threads)
            () {
              final p = users.firstWhere((u) => u.id == t.parentId);
              final waiting = t.messages.isNotEmpty && t.messages.last.senderId == t.parentId;
              return GwCard(
                onTap: () => context.push('/consult/${t.id}'),
                child: Row(children: [
                  const CircleAvatar(radius: 24, backgroundColor: Color(0xFFDBEAFE), child: Icon(Icons.family_restroom, color: brandBlue)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      Text(t.messages.isEmpty ? '-' : t.messages.last.text, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: textGray)),
                    ]),
                  ),
                  waiting ? const StatusChip('Perlu dijawab', 2) : const StatusChip('Dijawab', 0),
                ]),
              );
            }(),
          if (notes.isNotEmpty) ...[
            const SectionTitle('Catatan yang Anda tulis'),
            for (final n in notes) ConsultNoteTile(note: n),
          ],
        ]),
      ),
    ]);
  }
}

// ================================================================ Tenaga kesehatan: tulis catatan konsultasi
class NakesNotePage extends ConsumerStatefulWidget {
  const NakesNotePage({super.key, required this.threadId});
  final String threadId;
  @override
  ConsumerState<NakesNotePage> createState() => _NakesNotePageState();
}

class _NakesNotePageState extends ConsumerState<NakesNotePage> {
  String? _childId;
  final _title = TextEditingController(text: 'Konsultasi Pertumbuhan');
  final _ket = TextEditingController();
  final _diag = TextEditingController();
  final _anj = TextEditingController();
  final _cat = TextEditingController();
  DateTime? _control;

  void _prefill(Child c) {
    final last = ref.read(childMeasurementsProvider(c.id)).lastOrNull;
    if (last == null) {
      _ket.text = '${c.name} (${fmtAge(c.ageDays)}). Belum ada data pengukuran.';
      return;
    }
    final s = statusOf(last.result);
    _ket.text = '${c.name} (${fmtAge(last.result.ageDays)} saat diukur ${fmtDmy(last.date)}). '
        'Panjang badan ${fmtNum(last.heightCm)} cm dan berat badan ${fmtNum(last.weightKg)} kg. '
        'TB/U ${fmtZ(last.result.zHeightForAge)} SD, BB/U ${fmtZ(last.result.zWeightForAge)} SD. Status aplikasi: ${s.status.label}.';
  }

  void _save() {
    final me = ref.read(currentUserProvider)!;
    if (_childId == null) return showError(context, ArgumentError('Pilih anak yang dikonsultasikan.'));
    try {
      final n = ref.read(consultNotesProvider.notifier).add(
            actor: me,
            threadId: widget.threadId,
            childId: _childId!,
            title: _title.text,
            keterangan: _ket.text,
            diagnosis: _diag.text,
            anjuran: _anj.text,
            catatan: _cat.text,
          );
      if (_control != null) ref.read(appointmentsProvider.notifier).schedule(actor: me, childId: _childId!, date: _control!);
      showInfo(context, 'Catatan konsultasi tersimpan dan terlihat oleh orang tua.');
      context.pushReplacement('/consult/note/${n.id}');
    } catch (e) {
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(consultProvider).firstWhere((x) => x.id == widget.threadId);
    final kids = ref.watch(childrenProvider).where((c) => c.parentId == t.parentId).toList();
    InputDecoration dec(String l) => InputDecoration(
          labelText: l,
          alignLabelWithHint: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        );
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Catatan Konsultasi')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _childId,
          decoration: dec('Anak'),
          items: [for (final c in kids) DropdownMenuItem(value: c.id, child: Text('${c.name} (${fmtAge(c.ageDays)})'))],
          onChanged: (v) => setState(() {
            _childId = v;
            _prefill(kids.firstWhere((c) => c.id == v));
          }),
        ),
        const SizedBox(height: 12),
        TextField(controller: _title, decoration: dec('Judul')),
        const SizedBox(height: 12),
        TextField(controller: _ket, maxLines: 4, decoration: dec('Keterangan')),
        const SizedBox(height: 12),
        TextField(controller: _diag, maxLines: 2, decoration: dec('Diagnosis')),
        const SizedBox(height: 12),
        TextField(controller: _anj, maxLines: 3, decoration: dec('Resep & Anjuran')),
        const SizedBox(height: 12),
        TextField(controller: _cat, maxLines: 2, decoration: dec('Catatan Penting')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14), backgroundColor: Colors.white),
          icon: const Icon(Icons.event),
          label: Text(_control == null ? 'Jadwalkan kontrol (opsional)' : 'Kontrol: ${fmtDmy(_control!)} 09:00'),
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: now.add(const Duration(days: 30)));
            if (d != null) setState(() => _control = DateTime(d.year, d.month, d.day, 9));
          },
        ),
        const SizedBox(height: 20),
        PrimaryButton('Simpan Catatan', onPressed: _save),
      ]),
    );
  }
}
