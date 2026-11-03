import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/content.dart';
import '../models.dart';
import '../state/providers.dart';
import '../util/download.dart';
import 'common.dart';

/// Konten yang relevan untuk peran pengguna (personalisasi ER-3.1).
bool _forRole(Set<Role> audience, Role role) => role == Role.parent || role == Role.teen ? audience.contains(role) : true;

String _mmss(int s) => '${two(s ~/ 60)}:${two(s % 60)}';

String _count(int n) => n >= 10000 ? '${(n / 1000).toStringAsFixed(0)}rb' : '$n';

// ================================================================ Reels
class ReelsPage extends ConsumerStatefulWidget {
  const ReelsPage({super.key});
  @override
  ConsumerState<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends ConsumerState<ReelsPage> {
  int _current = 0;
  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserProvider)!.role;
    final list = reels.where((r) => _forRole(r.audience, role)).toList();
    return Stack(children: [
      PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: list.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (c, i) => _ReelView(reel: list[i], active: i == _current),
      ),
      Positioned(
        top: 12,
        left: 16,
        right: 8,
        child: Row(children: [
          const Text('Reels', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 8)])),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.black26, shape: const StadiumBorder()),
            onPressed: () => context.push('/articles'),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Artikel'),
          ),
        ]),
      ),
    ]);
  }
}

class _ReelView extends ConsumerStatefulWidget {
  const _ReelView({required this.reel, required this.active});
  final Reel reel;
  final bool active;
  @override
  ConsumerState<_ReelView> createState() => _ReelViewState();
}

class _ReelViewState extends ConsumerState<_ReelView> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this, duration: Duration(seconds: widget.reel.seconds))
    ..addListener(() => setState(() {}));
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _ReelView old) {
    super.didUpdateWidget(old);
    if (!widget.active && _progress.isAnimating) _progress.stop();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_progress.isAnimating) {
      _progress.stop();
    } else {
      if (_progress.isCompleted) _progress.reset();
      _progress.forward();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reel;
    final liked = ref.watch(likesProvider).contains(r.id);
    final saved = ref.watch(bookmarksProvider).contains(r.id);
    final left = (r.seconds * (1 - _progress.value)).round();
    Widget action(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(children: [
            Material(
              color: const Color(0x80424242),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(width: 50, height: 50, child: Icon(icon, color: color, size: 28)),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, shadows: [Shadow(blurRadius: 4)])),
          ]),
        );
    Widget box(String t, double size) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
          child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
        );

    return GestureDetector(
      onTap: _toggle,
      child: Stack(fit: StackFit.expand, children: [
        if (r.image != null)
          Image.asset(r.image!, fit: BoxFit.cover)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [for (final c in r.colors) Color(c)]),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              box(r.headline, 22),
              box(r.subline, 17),
            ]),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.15, 0.55, 1],
              colors: [Color(0x55000000), Colors.transparent, Colors.transparent, Color(0xAA000000)],
            ),
          ),
        ),
        if (!_progress.isAnimating)
          const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 84, shadows: [Shadow(blurRadius: 10)])),
        Positioned(
          right: 10,
          bottom: 128,
          child: Column(children: [
            action(liked ? Icons.favorite : Icons.favorite_border, _count(r.likes + (liked ? 1 : 0)),
                () => ref.read(likesProvider.notifier).toggle(r.id),
                color: liked ? const Color(0xFFFF4D6D) : Colors.white),
            action(Icons.chat_bubble_outline, _count(r.comments), () => _comments(context)),
            action(Icons.share_outlined, 'Share', () async {
              final ok = await shareText(r.title, '${r.title} — ${r.caption} (GroWell)');
              if (context.mounted) showInfo(context, ok ? 'Siap dibagikan.' : 'Berbagi belum didukung.');
            }),
            action(saved ? Icons.bookmark : Icons.bookmark_border, saved ? 'Saved' : 'Save',
                () => ref.read(bookmarksProvider.notifier).toggle(r.id)),
          ]),
        ),
        Positioned(
          left: 16,
          right: 78,
          bottom: 58,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.author, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6)])),
            const SizedBox(height: 8),
            Text(r.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 6)])),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                if (_expanded && r.articleId != null) {
                  context.push('/article/${r.articleId}');
                } else {
                  setState(() => _expanded = true);
                }
              },
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: _expanded ? '${r.caption} ' : '${r.caption.length > 90 ? '${r.caption.substring(0, 90)}…' : r.caption} '),
                  TextSpan(
                    text: _expanded ? (r.articleId != null ? 'Baca artikel ›' : '') : 'Selengkapnya...',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ]),
                style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45, shadows: [Shadow(blurRadius: 6)]),
              ),
            ),
          ]),
        ),
        Positioned(
          left: 16,
          right: 12,
          bottom: 40,
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: _progress.value, minHeight: 4, backgroundColor: Colors.white30, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Text(_mmss(left), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  void _comments(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Komentar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 12),
            Text('Kolom komentar aktif setelah tersambung server (tahap Supabase). Komentar akan dimoderasi agar informasi kesehatan tetap akurat.',
                style: TextStyle(color: textGray)),
          ]),
        ),
      ),
    );
  }
}

// ================================================================ Artikel
class EducationPage extends ConsumerStatefulWidget {
  const EducationPage({super.key});
  @override
  ConsumerState<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends ConsumerState<EducationPage> {
  String _query = '';
  bool _savedOnly = false;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserProvider)!.role;
    final saved = ref.watch(bookmarksProvider);
    final arts = articles
        .where((a) => _forRole(a.audience, role))
        .where((a) => _query.isEmpty || a.title.toLowerCase().contains(_query.toLowerCase()))
        .where((a) => !_savedOnly || saved.contains(a.id))
        .toList();
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Artikel Edukasi')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Cari artikel',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 10),
        Row(children: [
          FilterChip(label: const Text('Tersimpan'), selected: _savedOnly, onSelected: (v) => setState(() => _savedOnly = v)),
          const Spacer(),
          const DraftBadge(text: 'Draf konten — belum ditinjau nakes'),
        ]),
        const SizedBox(height: 6),
        if (arts.isEmpty) const EmptyState(icon: Icons.search_off, text: 'Artikel tidak ditemukan. Coba kata kunci lain.'),
        for (final a in arts) ArticleTile(article: a),
      ]),
    );
  }
}

class ArticleTile extends ConsumerWidget {
  const ArticleTile({super.key, required this.article});
  final Article article;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(bookmarksProvider).contains(article.id);
    return GwCard(
      onTap: () => context.push('/article/${article.id}'),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.article_outlined, color: brandBlue, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(article.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: textDark)),
            const SizedBox(height: 4),
            Text(article.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textGray, fontSize: 13.5)),
            const SizedBox(height: 4),
            Text('${article.minutes} menit baca', style: const TextStyle(color: textGray, fontSize: 12)),
          ]),
        ),
        Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? brandBlue : textGray),
      ]),
    );
  }
}

class ArticlePage extends ConsumerWidget {
  const ArticlePage({super.key, required this.articleId});
  final String articleId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = articles.firstWhere((x) => x.id == articleId);
    final saved = ref.watch(bookmarksProvider).contains(a.id);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artikel'),
        actions: [
          IconButton(
            tooltip: saved ? 'Hapus dari simpanan' : 'Simpan',
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => ref.read(bookmarksProvider.notifier).toggle(a.id),
          ),
          IconButton(
            tooltip: 'Bagikan',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final ok = await shareText(a.title, '${a.title} — ${a.summary} (GroWell)');
              if (!ok) await Clipboard.setData(ClipboardData(text: '${a.title} — ${a.summary} (GroWell)'));
              if (context.mounted) showInfo(context, 'Ringkasan artikel siap dibagikan ke WhatsApp/Instagram.');
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(a.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textDark)),
        const SizedBox(height: 8),
        Row(children: [Text('${a.minutes} menit baca', style: const TextStyle(color: textGray)), const Spacer(), const DraftBadge()]),
        const SizedBox(height: 16),
        Text(a.body, style: const TextStyle(height: 1.6, fontSize: 15.5)),
      ]),
    );
  }
}
