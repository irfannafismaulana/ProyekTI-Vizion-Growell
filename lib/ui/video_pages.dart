import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../state/providers.dart';
import 'common.dart';

String _mmss(int s) => '${two(s ~/ 60)}:${two(s % 60)}';

String _size(int bytes) => bytes >= 1024 * 1024 ? '${fmtNum(bytes / (1024 * 1024))} MB' : '${(bytes / 1024).ceil()} KB';

String audienceLabel(Set<Role> a) => [if (a.contains(Role.parent)) 'Orang tua', if (a.contains(Role.teen)) 'Remaja'].join(' & ');

/// Jenis berkas dari MIME/nama berkas; null bila bukan video yang didukung.
({String mime, String ext})? videoTypeOf(String? mime, String name) {
  final lower = name.toLowerCase();
  if (mime == 'video/mp4' || lower.endsWith('.mp4') || lower.endsWith('.m4v')) return (mime: 'video/mp4', ext: 'mp4');
  if (mime == 'video/webm' || lower.endsWith('.webm')) return (mime: 'video/webm', ext: 'webm');
  if (mime == 'video/quicktime' || lower.endsWith('.mov')) return (mime: 'video/quicktime', ext: 'mov');
  return null;
}

// ================================================================ Tab "Video" tenaga kesehatan
class NakesVideosPage extends ConsumerWidget {
  const NakesVideosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)!;
    final mine = ref.watch(eduVideosProvider).where((v) => v.authorId == me.id).toList();
    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        decoration: const BoxDecoration(gradient: headerGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Video Edukasi', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Unggah video singkat (maks. 3 menit). Video tampil di tab Reels orang tua dan remaja.',
              style: TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4)),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: brandBlue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            onPressed: () => context.push('/nakes/videos/new'),
            icon: const Icon(Icons.video_call_rounded),
            label: const Text('Unggah Video'),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle('Video saya (${mine.length})'),
          if (mine.isEmpty)
            const EmptyState(icon: Icons.ondemand_video_rounded, text: 'Belum ada video. Unggah video edukasi pertama Anda.')
          else
            for (final v in mine) _VideoTile(video: v),
        ]),
      ),
    ]);
  }
}

class _VideoTile extends ConsumerWidget {
  const _VideoTile({required this.video});
  final Reel video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = video;
    return GwCard(
      onTap: () => context.push('/video/${v.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 64,
          height: 86,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [for (final c in v.colors) Color(c)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 34),
            Positioned(
              bottom: 6,
              child: Text(_mmss(v.seconds), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: textDark)),
            const SizedBox(height: 4),
            Text('Untuk: ${audienceLabel(v.audience)}', style: const TextStyle(color: textGray, fontSize: 13)),
            if (v.createdAt != null) Text('Diunggah ${fmtDate(v.createdAt!)}', style: const TextStyle(color: textGray, fontSize: 12.5)),
          ]),
        ),
        IconButton(
          tooltip: 'Hapus video',
          icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Hapus video?'),
                content: Text('"${v.title}" tidak akan tampil lagi di Reels.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Hapus'),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            try {
              ref.read(eduVideosProvider.notifier).remove(actor: ref.read(currentUserProvider)!, id: v.id);
              if (context.mounted) showInfo(context, 'Video dihapus.');
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
          },
        ),
      ]),
    );
  }
}

// ================================================================ Unggah video
class UploadVideoPage extends ConsumerStatefulWidget {
  const UploadVideoPage({super.key});
  @override
  ConsumerState<UploadVideoPage> createState() => _UploadVideoPageState();
}

class _UploadVideoPageState extends ConsumerState<UploadVideoPage> {
  final _title = TextEditingController();
  final _caption = TextEditingController();
  final Set<Role> _audience = {Role.parent, Role.teen};
  XFile? _file;
  Uint8List? _bytes;
  ({String mime, String ext})? _type;
  VideoPlayerController? _player;
  int _seconds = 0;
  bool _loading = false;
  bool _uploading = false;

  @override
  void dispose() {
    _player?.dispose();
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    XFile? x;
    try {
      x = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: EduVideosNotifier.maxSeconds));
    } catch (_) {
      if (mounted) showError(context, ArgumentError('Galeri video tidak dapat dibuka di perangkat ini.'));
      return;
    }
    if (x == null) return;
    final type = videoTypeOf(x.mimeType, x.name);
    if (type == null) {
      if (mounted) showError(context, ArgumentError('Format tidak didukung. Gunakan video MP4, WebM, atau MOV.'));
      return;
    }
    setState(() => _loading = true);
    final old = _player;
    _player = null;
    await old?.dispose();
    final bytes = await x.readAsBytes();
    // Di web, path XFile adalah URL blob sementara yang bisa langsung diputar.
    final player = VideoPlayerController.networkUrl(Uri.parse(x.path));
    var seconds = 0;
    try {
      await player.initialize();
      seconds = player.value.duration.inMilliseconds ~/ 1000 + (player.value.duration.inMilliseconds % 1000 > 0 ? 1 : 0);
    } catch (_) {
      await player.dispose();
      if (mounted) {
        setState(() => _loading = false);
        showError(context, ArgumentError('Video tidak dapat dibaca browser. Gunakan MP4 (H.264).'));
      }
      return;
    }
    if (!mounted) return player.dispose();
    setState(() {
      _file = x;
      _bytes = bytes;
      _type = type;
      _player = player;
      _seconds = seconds;
      _loading = false;
      if (_title.text.trim().isEmpty) _title.text = _titleFromName(x!.name);
    });
    final err = _sizeOrDurationError();
    if (err != null) showError(context, ArgumentError(err));
  }

  String _titleFromName(String name) {
    final base = name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return base.length > 120 ? base.substring(0, 120) : base;
  }

  String? _sizeOrDurationError() {
    final b = _bytes;
    if (b == null) return null;
    if (b.length > EduVideosNotifier.maxBytes) return 'Ukuran video ${_size(b.length)} melebihi batas 50 MB.';
    if (_seconds > EduVideosNotifier.maxSeconds) return 'Durasi ${_mmss(_seconds)} melebihi batas 3 menit untuk video singkat.';
    return null;
  }

  Future<void> _upload() async {
    final b = _bytes, f = _file, t = _type;
    if (b == null || f == null || t == null) return showError(context, ArgumentError('Pilih video terlebih dahulu.'));
    final err = EduVideosNotifier.validate(title: _title.text, audience: _audience, sizeBytes: b.length, seconds: _seconds);
    if (err != null) return showError(context, ArgumentError(err));
    setState(() => _uploading = true);
    _player?.pause();
    try {
      await ref.read(eduVideosProvider.notifier).upload(
            actor: ref.read(currentUserProvider)!,
            title: _title.text,
            caption: _caption.text,
            audience: {..._audience},
            bytes: b,
            mime: t.mime,
            extension: t.ext,
            seconds: _seconds,
            localUrl: f.path,
          );
      if (!mounted) return;
      showInfo(context, 'Video diunggah dan tampil di Reels ${audienceLabel(_audience).toLowerCase()}.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/app?tab=2');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showError(context, e is ArgumentError || e is AccessDenied ? e : ArgumentError(describeBackendError(e)));
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
    final p = _player;
    final tooBig = _sizeOrDurationError() != null;
    Widget audienceChip(Role r, String label, IconData icon) => FilterChip(
          avatar: Icon(icon, size: 18),
          label: Text(label),
          selected: _audience.contains(r),
          onSelected: _uploading ? null : (on) => setState(() => on ? _audience.add(r) : _audience.remove(r)),
        );
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Unggah Video')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: const Color(0xFF111827),
              child: InkWell(
                onTap: _loading || _uploading ? null : (p == null ? _pick : () => setState(() => p.value.isPlaying ? p.pause() : p.play())),
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : p == null
                        ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.video_library_outlined, color: Colors.white, size: 52),
                            SizedBox(height: 10),
                            Text('Pilih Video', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                            SizedBox(height: 6),
                            Text('MP4/WebM/MOV • maks. 3 menit • maks. 50 MB', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ])
                        : Stack(fit: StackFit.expand, children: [
                            Center(child: AspectRatio(aspectRatio: p.value.aspectRatio, child: VideoPlayer(p))),
                            if (!p.value.isPlaying) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 64)),
                          ]),
              ),
            ),
          ),
        ),
        if (_file != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(tooBig ? Icons.error_outline : Icons.check_circle, size: 18, color: tooBig ? const Color(0xFFDC2626) : brandGreen),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${_file!.name} • ${_mmss(_seconds)} • ${_size(_bytes!.length)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textGray, fontSize: 13)),
            ),
            TextButton(onPressed: _loading || _uploading ? null : _pick, child: const Text('Ganti')),
          ]),
        ],
        const SizedBox(height: 18),
        TextField(controller: _title, enabled: !_uploading, maxLength: 120, decoration: _dec('Judul video', 'contoh: Cara membuat MPASI hati ayam')),
        const SizedBox(height: 8),
        TextField(
          controller: _caption,
          enabled: !_uploading,
          maxLength: 1000,
          minLines: 3,
          maxLines: 6,
          decoration: _dec('Keterangan', 'Ringkasan isi video dan pesan utamanya'),
        ),
        const SizedBox(height: 10),
        const Text('Tampilkan untuk', style: TextStyle(fontWeight: FontWeight.w600, color: textDark)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: [
          audienceChip(Role.parent, 'Orang tua', Icons.family_restroom),
          audienceChip(Role.teen, 'Remaja', Icons.school_outlined),
        ]),
        const SizedBox(height: 24),
        PrimaryButton(
          _uploading ? 'Mengunggah…' : 'Unggah ke Reels',
          icon: Icons.cloud_upload_outlined,
          onPressed: _uploading || _loading || _file == null || tooBig ? null : _upload,
        ),
        if (_uploading) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
        const SizedBox(height: 12),
        const Text('Pastikan isi video sesuai pedoman kesehatan. Video dapat dihapus kapan saja dari tab Video.',
            style: TextStyle(fontSize: 12, color: textGray)),
      ]),
    );
  }
}

// ================================================================ Pratinjau video
class VideoPreviewPage extends ConsumerStatefulWidget {
  const VideoPreviewPage({super.key, required this.videoId});
  final String videoId;
  @override
  ConsumerState<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends ConsumerState<VideoPreviewPage> {
  VideoPlayerController? _player;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final v = ref.read(eduVideosProvider).where((x) => x.id == widget.videoId).firstOrNull;
    if (v?.videoUrl == null) return;
    final p = VideoPlayerController.networkUrl(Uri.parse(v!.videoUrl!));
    _player = p;
    p.addListener(_refresh);
    p.initialize().then((_) => p.play(), onError: (Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player
      ?..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(eduVideosProvider).where((x) => x.id == widget.videoId).firstOrNull;
    final p = _player;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(v?.title ?? 'Video', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: v == null
          ? const Center(child: Text('Video tidak ditemukan.', style: TextStyle(color: Colors.white)))
          : Column(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => p != null && p.value.isInitialized ? (p.value.isPlaying ? p.pause() : p.play()) : null,
                  child: Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: _failed
                        ? const Text('Video tidak dapat diputar.', style: TextStyle(color: Colors.white))
                        : p == null || !p.value.isInitialized
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Stack(alignment: Alignment.center, children: [
                                AspectRatio(aspectRatio: p.value.aspectRatio, child: VideoPlayer(p)),
                                if (!p.value.isPlaying) const Icon(Icons.play_circle_fill, color: Colors.white70, size: 72),
                              ]),
                  ),
                ),
              ),
              if (p != null && p.value.isInitialized)
                VideoProgressIndicator(p, allowScrubbing: true, colors: const VideoProgressColors(playedColor: brandBlue)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  if (v.caption.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(v.caption, style: const TextStyle(color: Colors.white70, height: 1.4)),
                  ],
                  const SizedBox(height: 6),
                  Text('Untuk: ${audienceLabel(v.audience)} • ${_mmss(v.seconds)}', style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
                ]),
              ),
            ]),
    );
  }
}
