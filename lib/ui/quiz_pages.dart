import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/quiz_rules.dart';
import '../models.dart';
import '../state/providers.dart';
import '../state/quiz_engine.dart';
import 'common.dart';

// Tampilan kuis mengikuti desain "Growell • Multiplayer Quiz" (update svg): tema biru,
// mode 2/4 pemain, lobi dengan status siap, kartu skor pemain, dan hasil pertandingan.

String _diff(Difficulty d) => switch (d) {
  Difficulty.mudah => 'Mudah',
  Difficulty.sedang => 'Sedang',
  Difficulty.sulit => 'Sulit',
};

const _quizBg = Color(0xFFF5F8FF);
const _headerGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4A90FF), Color(0xFF1D5FE8)]);
const _blueSoft = Color(0xFFE8F0FF);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);

/// Warna pemain per urutan (desain: biru, ungu, oranye, hijau).
const _playerColors = [
  (Color(0xFF2E7EFE), Color(0xFFE3EDFF)),
  (Color(0xFF8B5CF6), Color(0xFFEFE9FF)),
  (Color(0xFFE08A00), Color(0xFFFFF1DB)),
  (Color(0xFF16A34A), Color(0xFFE3F8EA)),
];

(Color, Color) _colorOf(QuizSession s, Player p) => _playerColors[s.players.indexWhere((x) => x.id == p.id).clamp(0, 3)];

String _shown(Player p) => p.name.replaceFirst('Bot ', '');

String _modeLabel(int capacity) => capacity == 2 ? 'Mode 2 pemain' : 'Mode 4 pemain';

/// Keluar dari ruang setelah frame selesai: mengubah state kuis di tengah
/// pembangunan ulang navigator (saat halaman ditutup) memicu layar error merah.
void _leaveAfterFrame(WidgetRef ref) {
  final engine = ref.read(quizProvider.notifier);
  WidgetsBinding.instance.addPostFrameCallback((_) => engine.leave());
}

// ---------------------------------------------------------------- Komponen bersama
/// Kepala biru melengkung dengan ornamen, judul, subjudul, dan bilah progres opsional.
class _QuizHeader extends StatelessWidget {
  const _QuizHeader({required this.title, required this.subtitle, this.progress, this.onBack});
  final String title;
  final String subtitle;
  final double? progress;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    Widget bubble(double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        gradient: _headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(right: -30, top: 30, child: bubble(110, 0.12)),
          Positioned(right: 30, top: -20, child: bubble(60, 0.12)),
          const Positioned(right: 26, top: 74, child: Icon(Icons.star_rounded, color: Color(0x40FFFFFF), size: 30)),
          Padding(
            padding: EdgeInsets.fromLTRB(onBack == null ? 24 : 12, MediaQuery.paddingOf(context).top + 18, 24, progress == null ? 34 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[
                      Material(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onBack,
                          child: const SizedBox(width: 36, height: 36, child: Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (progress != null) ...[
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 7,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu putih membulat dengan bayangan lembut.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16), this.color = Colors.white, this.border, this.onTap, this.margin});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? border;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  @override
  Widget build(BuildContext context) => Container(
    margin: margin ?? const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border ?? const Color(0xFFE6ECF5), width: border == null ? 1 : 1.8),
      boxShadow: const [BoxShadow(color: Color(0x0F1D4ED8), blurRadius: 14, offset: Offset(0, 4))],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class _Letter extends StatelessWidget {
  const _Letter(this.text, {required this.fg, required this.bg, this.size = 40});
  final String text;
  final Color fg;
  final Color bg;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Text(
      text,
      style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: size * 0.4),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.fg = brandBlue, this.bg = _blueSoft, this.icon});
  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
          ),
        ),
      ],
    ),
  );
}

/// Tombol utama biru bergradasi (desain "Buat Ruang", "Mulai Quiz", "Main Lagi").
class _GradientButton extends StatelessWidget {
  const _GradientButton(this.label, {required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _headerGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled ? const [BoxShadow(color: Color(0x332E7EFE), blurRadius: 14, offset: Offset(0, 6))] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: _blueSoft, borderRadius: BorderRadius.circular(14)),
    child: Text(
      text,
      style: const TextStyle(color: brandBlue, fontSize: 12.5, fontWeight: FontWeight.w600),
    ),
  );
}

// ---------------------------------------------------------------- 01 Pilih mode (beranda kuis)
/// Lencana yang bisa diraih (aturan di BadgesNotifier.recordGame).
const _badgeInfo = <String, (IconData, String)>{
  'Jagoan Gizi': (Icons.restaurant_rounded, '≥ 80% jawaban benar'),
  'Sahabat Posyandu': (Icons.favorite_rounded, 'Main kuis 3 kali'),
  'Kilat': (Icons.bolt_rounded, 'Rata-rata ≤ 5 detik'),
};

class QuizHome extends ConsumerStatefulWidget {
  const QuizHome({super.key});
  @override
  ConsumerState<QuizHome> createState() => _QuizHomeState();
}

class _QuizHomeState extends ConsumerState<QuizHome> {
  int _capacity = 2;
  Difficulty _difficulty = Difficulty.sedang;
  QuizCategory _category = QuizCategory.campuran;
  double _count = 10;
  double _seconds = 15;

  bool _busy = false;

  Future<void> _create({bool practice = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await ref
        .read(quizProvider.notifier)
        .createRoom(
          me: ref.read(currentUserProvider)!,
          settings: QuizSettings(difficulty: _difficulty, category: _category, questionCount: _count.round(), secondsPerQuestion: _seconds.round()),
          capacity: _capacity,
          practice: practice,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) return showError(context, ArgumentError(err));
    context.push('/quiz/room');
  }

  Widget _modeCard(int capacity, String title, String sub, String tag, Color tagFg, Color tagBg, Widget art) {
    final sel = _capacity == capacity;
    return Expanded(
      child: _Card(
        margin: EdgeInsets.zero,
        border: sel ? brandBlue : null,
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 12),
        onTap: () => setState(() => _capacity = capacity),
        child: Column(
          children: [
            art,
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
            ),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(color: textGray, fontSize: 13)),
            const SizedBox(height: 10),
            _Tag(tag, fg: tagFg, bg: tagBg),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 15,
    height: 15,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)!;
    final lb = ref.watch(leaderboardProvider).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final rank = lb.indexWhere((e) => e.key == me.name);
    final badges = ref.watch(badgesProvider)[me.id] ?? const <String>{};
    final live = ref.watch(backendProvider) != null;
    return Scaffold(
      backgroundColor: _quizBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _QuizHeader(title: 'Quiz Growell', subtitle: 'Belajar sehat, main bareng teman!', onBack: context.canPop() ? () => context.pop() : null),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x1A2E7EFE), blurRadius: 16, offset: Offset(0, 6))],
                    ),
                    alignment: Alignment.center,
                    child: const Text('🥗', style: TextStyle(fontSize: 40)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Ayo tantang temanmu!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textDark),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Jawab kuis seputar gizi dan tumbuh kembang',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textGray),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Pilih jumlah pemain',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textDark),
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _modeCard(
                        2,
                        '2 Pemain',
                        'Duel 1 lawan 1',
                        'DUEL CEPAT',
                        brandBlue,
                        _blueSoft,
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: _blueSoft,
                          child: Icon(Icons.people_alt_rounded, color: brandBlue, size: 32),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _modeCard(
                        4,
                        '4 Pemain',
                        'Battle 4 orang',
                        'PALING RAMAI',
                        _green,
                        const Color(0xFFE3F8EA),
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: _blueSoft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [_dot(brandBlue), const SizedBox(width: 7), _dot(const Color(0xFF60A5FA))]),
                              const SizedBox(height: 7),
                              Row(mainAxisSize: MainAxisSize.min, children: [_dot(const Color(0xFF8B5CF6)), const SizedBox(width: 7), _dot(_green)]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Card(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cara bermain',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: textDark),
                      ),
                      const SizedBox(height: 10),
                      for (final (i, t) in [
                        'Pilih mode dan buat atau gabung ruang',
                        'Jawab ${_count.round()} pertanyaan sebelum waktu habis',
                        'Jawaban benar & cepat = poin lebih banyak',
                      ].indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              _Letter('${i + 1}', fg: brandBlue, bg: _blueSoft, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(t, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13.5)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                _Card(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                      leading: const Icon(Icons.tune_rounded, color: brandBlue),
                      title: const Text(
                        'Pengaturan ruang',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textDark),
                      ),
                      subtitle: Text(
                        '${_diff(_difficulty)} • ${_category.label} • ${_count.round()} soal • ${_seconds.round()} detik',
                        style: const TextStyle(fontSize: 12.5, color: textGray),
                      ),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final d in Difficulty.values)
                              ChoiceChip(label: Text(_diff(d)), selected: _difficulty == d, onSelected: (_) => setState(() => _difficulty = d)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final c in QuizCategory.values)
                              ChoiceChip(label: Text(c.label), selected: _category == c, onSelected: (_) => setState(() => _category = c)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Jumlah soal: ${_count.round()}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Slider(value: _count, min: 5, max: 20, divisions: 15, onChanged: (v) => setState(() => _count = v)),
                        Text('Waktu per soal: ${_seconds.round()} detik', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Slider(value: _seconds, min: 10, max: 30, divisions: 20, onChanged: (v) => setState(() => _seconds = v)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _GradientButton(_busy ? 'Membuat ruang…' : 'Buat Ruang', onPressed: _busy ? null : () => _create()),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => context.push('/quiz/join'),
                  child: const Text('Sudah punya kode ruang? Gabung ruang', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (live)
                  TextButton.icon(
                    onPressed: _busy ? null : () => _create(practice: true),
                    icon: const Icon(Icons.smart_toy_outlined, size: 18),
                    label: const Text('Latihan dengan bot (tidak masuk papan skor)'),
                  )
                else
                  const Text(
                    'Mode lokal: lawan adalah bot simulasi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textGray, fontSize: 12.5),
                  ),
                const SizedBox(height: 8),
                _Card(
                  onTap: () => context.push('/quiz/leaderboard'),
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFFFF1DB),
                        child: Icon(Icons.emoji_events_rounded, color: Color(0xFFE08A00)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Leaderboard mingguan',
                              style: TextStyle(fontWeight: FontWeight.w800, color: textDark),
                            ),
                            Text(
                              rank >= 0 ? 'Peringkatmu #${rank + 1} • ${lb[rank].value} poin' : 'Main untuk masuk peringkat minggu ini',
                              style: const TextStyle(color: textGray, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: textGray),
                    ],
                  ),
                ),
                Row(
                  children: [
                    for (final e in _badgeInfo.entries) ...[
                      Expanded(
                        child: Tooltip(
                          message: e.value.$2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            decoration: BoxDecoration(
                              color: badges.contains(e.key) ? const Color(0xFFFFF7E0) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: badges.contains(e.key) ? const Color(0xFFF5C451) : const Color(0xFFE6ECF5)),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  badges.contains(e.key) ? e.value.$1 : Icons.lock_outline,
                                  color: badges.contains(e.key) ? const Color(0xFFE08A00) : const Color(0xFF9CA3AF),
                                  size: 22,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.key,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badges.contains(e.key) ? textDark : textGray),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (e.key != _badgeInfo.keys.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const _FooterNote('Kuis edukatif • Tidak menggantikan saran tenaga kesehatan'),
                const SizedBox(height: 6),
                const DraftBadge(text: 'Bank soal draf (40 soal) — perlu ditinjau nakes'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rute lama `/quiz/create` (tombol "Main" di beranda remaja) memakai layar pilih mode yang sama.
class CreateRoomPage extends StatelessWidget {
  const CreateRoomPage({super.key});
  @override
  Widget build(BuildContext context) => const QuizHome();
}

// ---------------------------------------------------------------- Gabung ruang
class JoinRoomPage extends ConsumerStatefulWidget {
  const JoinRoomPage({super.key});
  @override
  ConsumerState<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends ConsumerState<JoinRoomPage> {
  final _code = TextEditingController();
  bool _busy = false;

  Future<void> _join() async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await ref.read(quizProvider.notifier).joinRoom(me: ref.read(currentUserProvider)!, code: _code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) return showError(context, ArgumentError(err));
    context.pushReplacement('/quiz/room');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _quizBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _QuizHeader(title: 'Gabung Ruang', subtitle: 'Masukkan kode dari host ruang', onBack: () => context.pop()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KODE RUANG',
                        style: TextStyle(color: textGray, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        onSubmitted: (_) => _join(),
                        style: const TextStyle(fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.w900, color: brandBlue),
                        decoration: InputDecoration(
                          hintText: 'ABC123',
                          hintStyle: const TextStyle(color: Color(0xFFBFD3FF), letterSpacing: 6),
                          filled: true,
                          fillColor: _quizBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      Text(
                        ref.watch(backendProvider) == null
                            ? 'Mode lokal: gunakan kode demo $demoRoomCode'
                            : 'Minta kode 6 karakter dari host. Ruang harus belum dimulai dan belum penuh.',
                        style: const TextStyle(color: textGray, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _GradientButton(_busy ? 'Menggabungkan…' : 'Gabung Ruang', onPressed: _busy ? null : _join),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Ruang kuis
class QuizRoomPage extends ConsumerWidget {
  const QuizRoomPage({super.key});

  Future<void> _confirmExit(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar dari kuis?'),
        content: const Text('Skor permainan ini tidak akan tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Lanjut main')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true && context.mounted) _exit(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(quizProvider);
    if (s == null) {
      return Scaffold(
        backgroundColor: _quizBg,
        body: EmptyState(
          icon: Icons.sports_esports,
          text: 'Tidak ada ruang aktif.',
          action: FilledButton(onPressed: () => context.go('/app'), child: const Text('Kembali')),
        ),
      );
    }
    final playing = s.phase == QuizPhase.question || s.phase == QuizPhase.reveal;
    return PopScope(
      canPop: !playing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _leaveAfterFrame(ref);
        } else {
          _confirmExit(context, ref);
        }
      },
      child: Scaffold(
        backgroundColor: _quizBg,
        body: switch (s.phase) {
          QuizPhase.lobby => _Lobby(s: s),
          QuizPhase.question || QuizPhase.reveal => _Gameplay(s: s, onBack: () => _confirmExit(context, ref)),
          QuizPhase.finished => _Result(s: s),
        },
      ),
    );
  }
}

/// Tutup halaman ruang lalu bersihkan state kuis setelah frame.
void _exit(BuildContext context, WidgetRef ref) {
  _leaveAfterFrame(ref);
  if (context.canPop()) {
    Navigator.of(context).pop();
  } else {
    context.go('/app');
  }
}

// ---------------------------------------------------------------- 02/03 Lobi
class _Lobby extends ConsumerWidget {
  const _Lobby({required this.s});
  final QuizSession s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = s.settings;
    void copy() {
      Clipboard.setData(ClipboardData(text: s.code));
      showInfo(context, 'Kode ruang ${s.code} disalin.');
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _QuizHeader(
          title: 'Ruang Permainan',
          subtitle: '${_modeLabel(s.capacity)} • ${s.capacity == 2 ? 'Duel 1 lawan 1' : 'Battle bersama'}',
          progress: s.players.length / s.capacity,
          onBack: () => _exit(context, ref),
        ),
        Transform.translate(
          offset: const Offset(0, -18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'KODE RUANG',
                              style: TextStyle(color: textGray, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              s.code,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: brandBlue, letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const _Tag('● RUANG AKTIF', fg: _green, bg: Color(0xFFE3F8EA)),
                          const SizedBox(height: 8),
                          TextButton(
                            style: TextButton.styleFrom(backgroundColor: _blueSoft, visualDensity: VisualDensity.compact),
                            onPressed: copy,
                            child: const Text('Salin', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pemain bergabung',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: textDark),
                      ),
                    ),
                    Text(
                      '${s.players.length} / ${s.capacity}',
                      style: const TextStyle(color: textGray, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < s.capacity; i++)
                  if (i < s.players.length) _PlayerSlot(s: s, p: s.players[i], index: i) else const _EmptySlot(),
                if (!s.isFull)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _blueSoft, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ajak temanmu',
                          style: TextStyle(color: brandBlue, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        const Text('Bagikan kode ruang agar teman bisa bergabung.', style: TextStyle(color: Color(0xFF4B6BA8), fontSize: 13)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                s.code,
                                style: const TextStyle(color: brandBlue, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: copy,
                              child: const Text('Bagikan kode', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                if (s.iAmHost) ...[
                  _GradientButton(
                    'Mulai Quiz',
                    onPressed: s.isFull
                        ? () async {
                            final err = await ref.read(quizProvider.notifier).start();
                            if (err != null && context.mounted) showError(context, ArgumentError(err));
                          }
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.isFull ? 'Semua pemain sudah siap' : 'Menunggu pemain lain bergabung…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textGray, fontSize: 12.5),
                  ),
                ] else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      const SizedBox(width: 10),
                      Text(
                        s.message ?? 'Menunggu host memulai…',
                        style: const TextStyle(color: textGray, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                _FooterNote('${st.questionCount} soal • ${st.secondsPerQuestion} detik per pertanyaan • ${_diff(st.difficulty)} • Poin untuk jawaban benar'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({required this.s, required this.p, required this.index});
  final QuizSession s;
  final Player p;
  final int index;
  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colorOf(s, p);
    final role = p.id == s.hostId ? 'Host ruang' : 'Pemain ${index + 1}${p.isBot ? ' • bot simulasi' : ''}';
    return TweenAnimationBuilder<double>(
      key: ValueKey(p.id),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(
        scale: 0.9 + 0.1 * t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: _Card(
        border: p.id == s.meId ? brandBlue : null,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            _Letter(_shown(p).characters.first.toUpperCase(), fg: fg, bg: bg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.id == s.meId ? '${_shown(p)} (kamu)' : _shown(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: textDark),
                  ),
                  Text(role, style: const TextStyle(color: textGray, fontSize: 12.5)),
                ],
              ),
            ),
            const _Tag('Siap ✓', fg: _green, bg: Color(0xFFE3F8EA)),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFC9D8F5), width: 1.5),
      color: Colors.white.withValues(alpha: 0.5),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Color(0xFFEFF3FA),
          child: Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF9DB2D6), size: 20),
        ),
        SizedBox(width: 12),
        Text(
          'Menunggu pemain…',
          style: TextStyle(color: Color(0xFF8CA0C3), fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- 04/05 Gameplay (+ hasil per soal)
class _Gameplay extends ConsumerWidget {
  const _Gameplay({required this.s, required this.onBack});
  final QuizSession s;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = s.current!;
    final reveal = s.phase == QuizPhase.reveal;
    final mine = s.me.answer;
    final total = s.questions.length;
    final answered = s.players.where((p) => p.answer != null).length;
    final left = s.secondsLeft.ceil();
    final urgent = !reveal && s.secondsLeft <= 5;
    final ok = mine == q.answer;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _QuizHeader(
          title: 'Quiz berlangsung',
          subtitle: '${_modeLabel(s.capacity)} • ${q.category.label}',
          progress: (s.index + (reveal ? 1 : 0)) / total,
          onBack: onBack,
        ),
        Transform.translate(
          offset: const Offset(0, -18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PERTANYAAN',
                              style: TextStyle(color: textGray, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '${(s.index + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textDark),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: s.streak >= 2
                                      ? _Tag('🔥 ${s.streak}x BERUNTUN', fg: const Color(0xFFB45309), bg: const Color(0xFFFFF1DB))
                                      : const _Tag('BONUS CEPAT', icon: Icons.star_rounded, fg: Color(0xFFB45309), bg: Color(0xFFFFF1DB)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: urgent ? const Color(0xFFFFE1E1) : const Color(0xFFFFF1DB), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(
                          reveal ? '✓' : '${left}s',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: urgent ? _red : const Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ),
                ),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.9,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [for (final p in s.players) _ScoreCard(s: s, p: p, reveal: reveal)],
                ),
                if (reveal) _RevealBanner(ok: ok, timeout: mine == null, points: s.me.lastPoints, streak: s.streak) else const SizedBox.shrink(),
                _Card(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Tag('${q.category.label.toUpperCase()} • ${_diff(q.difficulty).toUpperCase()}'),
                            const SizedBox(height: 10),
                            Text(
                              q.text,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark, height: 1.35),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              reveal ? q.explanation : 'Pilih satu jawaban yang paling tepat.',
                              style: TextStyle(color: reveal ? const Color(0xFF374151) : textGray, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: _blueSoft,
                        child: Text('🥗', style: TextStyle(fontSize: 20)),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < q.options.length; i++)
                  _Option(
                    index: i,
                    text: q.options[i],
                    state: reveal
                        ? (i == q.answer ? _OptState.correct : (i == mine ? _OptState.wrong : _OptState.dimmed))
                        : (mine == null ? _OptState.idle : (i == mine ? _OptState.selected : _OptState.dimmed)),
                    onTap: !reveal && mine == null ? () => ref.read(quizProvider.notifier).answer(i) : null,
                  ),
                const SizedBox(height: 4),
                Text(
                  reveal
                      ? (s.index + 1 >= total ? 'Hasil pertandingan segera tampil…' : 'Pertanyaan berikutnya segera dimulai…')
                      : (mine == null ? 'Jawab sebelum waktu habis!' : 'Jawaban terkunci • $answered/${s.players.length} pemain sudah menjawab'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textGray, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.s, required this.p, required this.reveal});
  final QuizSession s;
  final Player p;
  final bool reveal;
  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colorOf(s, p);
    final done = p.answer != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.id == s.meId ? brandBlue : const Color(0xFFE6ECF5), width: p.id == s.meId ? 1.6 : 1),
      ),
      child: Row(
        children: [
          _Letter(_shown(p).characters.first.toUpperCase(), fg: fg, bg: bg, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.id == s.meId ? 'Kamu' : _shown(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: textDark),
                ),
                Text(
                  reveal && p.lastPoints > 0 ? '${p.score} poin (+${p.lastPoints})' : '${p.score} poin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textGray, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(done ? Icons.star_rounded : Icons.star_outline_rounded, color: done ? const Color(0xFFF5A524) : const Color(0xFFCBD5E1), size: 20),
        ],
      ),
    );
  }
}

class _RevealBanner extends StatelessWidget {
  const _RevealBanner({required this.ok, required this.timeout, required this.points, required this.streak});
  final bool ok;
  final bool timeout;
  final int points;
  final int streak;
  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon, title) = ok
        ? (_green, const Color(0xFFE3F8EA), Icons.check_circle_rounded, 'Benar! +$points poin')
        : timeout
        ? (const Color(0xFF64748B), const Color(0xFFEEF2F7), Icons.timer_off_rounded, 'Waktu habis')
        : (_red, const Color(0xFFFFE8E8), Icons.cancel_rounded, 'Belum tepat');
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 17),
              ),
            ),
            if (ok && streak >= 2)
              Text(
                '🔥 $streak beruntun',
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}

enum _OptState { idle, selected, dimmed, correct, wrong }

class _Option extends StatelessWidget {
  const _Option({required this.index, required this.text, required this.state, this.onTap});
  final int index;
  final String text;
  final _OptState state;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final (border, fill, letterBg, letterFg, trailing) = switch (state) {
      _OptState.selected => (brandBlue, Colors.white, brandBlue, Colors.white, Icons.check_rounded),
      _OptState.correct => (_green, const Color(0xFFF0FDF4), _green, Colors.white, Icons.check_circle_rounded),
      _OptState.wrong => (_red, const Color(0xFFFEF2F2), _red, Colors.white, Icons.cancel_rounded),
      _ => (const Color(0xFFE6ECF5), Colors.white, _blueSoft, brandBlue, null),
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: state == _OptState.dimmed ? 0.5 : 1,
      child: _Card(
        color: fill,
        border: state == _OptState.idle || state == _OptState.dimmed ? null : border,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        onTap: onTap,
        child: Row(
          children: [
            _Letter(String.fromCharCode(65 + index), fg: letterFg, bg: letterBg, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: textDark),
              ),
            ),
            if (trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: border.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(trailing, color: border, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 06 Hasil pertandingan
class _Result extends ConsumerWidget {
  const _Result({required this.s});
  final QuizSession s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = s.ranking;
    final winner = ranking.first;
    final myRank = ranking.indexWhere((p) => p.id == s.meId) + 1;
    final badges = ref.watch(badgesProvider)[s.meId] ?? const <String>{};
    final n = s.questions.length;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _QuizHeader(title: 'Hasil Pertandingan', subtitle: 'Satu langkah kecil untuk tumbuh sehat!', progress: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.elasticOut,
                  builder: (_, t, child) => Transform.scale(scale: t, child: child),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(color: Color(0xFFFFF1DB), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Text('🏆', style: TextStyle(fontSize: 52)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Permainan selesai!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textDark),
              ),
              const SizedBox(height: 4),
              Text(
                myRank == 1 ? 'Hebat, kamu juara! Terus belajar tentang hidup sehat.' : 'Peringkatmu #$myRank. Terus belajar tentang hidup sehat.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: textGray),
              ),
              const SizedBox(height: 18),
              _Card(
                color: const Color(0xFFFFFBEB),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'PEMENANG',
                            style: TextStyle(color: textGray, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                        ),
                        _Tag('TOP PLAYER', fg: Color(0xFFB45309), bg: Color(0xFFFFE9B0)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Letter(_shown(winner).characters.first.toUpperCase(), fg: brandBlue, bg: _blueSoft, size: 50),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                winner.id == s.meId ? '${_shown(winner)} (kamu)' : _shown(winner),
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: textDark),
                              ),
                              Text('${winner.correct} jawaban benar', style: const TextStyle(color: textGray)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${winner.score}',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: brandBlue),
                            ),
                            const Text('poin', style: TextStyle(color: textGray, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 10),
                child: Text(
                  'Peringkat pemain',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textDark),
                ),
              ),
              for (final (i, p) in ranking.indexed)
                _Card(
                  border: p.id == s.meId ? brandBlue : null,
                  padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                  child: Row(
                    children: [
                      _Letter('${i + 1}', fg: _playerColors[i.clamp(0, 3)].$1, bg: _playerColors[i.clamp(0, 3)].$2, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.id == s.meId ? '${_shown(p)} (kamu)' : _shown(p),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: textDark),
                        ),
                      ),
                      Text('${p.correct}/$n benar  ', style: const TextStyle(color: textGray, fontSize: 12.5)),
                      Text(
                        '${p.score} poin',
                        style: TextStyle(fontWeight: FontWeight.w800, color: _playerColors[i.clamp(0, 3)].$1),
                      ),
                    ],
                  ),
                ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in badges)
                      _Tag(b.toUpperCase(), icon: _badgeInfo[b]?.$1 ?? Icons.military_tech, fg: const Color(0xFFB45309), bg: const Color(0xFFFFF1DB)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              _Card(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.menu_book_rounded, color: brandBlue),
                    title: const Text(
                      'Pembahasan soal',
                      style: TextStyle(fontWeight: FontWeight.w800, color: textDark),
                    ),
                    subtitle: Text('${s.me.correct} dari $n jawabanmu benar', style: const TextStyle(fontSize: 12.5, color: textGray)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, q) in s.questions.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                i < s.myHistory.length && s.myHistory[i] ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                size: 20,
                                color: i < s.myHistory.length && s.myHistory[i] ? _green : _red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${i + 1}. ${q.text}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                    Text(
                                      'Jawaban: ${q.options[q.answer]}',
                                      style: const TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    Text(q.explanation, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12.5, height: 1.35)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _GradientButton(
                      'Main Lagi',
                      onPressed: () {
                        _leaveAfterFrame(ref);
                        context.pushReplacement('/quiz/create');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: brandBlue, width: 1.6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: () => _exit(context, ref),
                        child: const Text('Kembali', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: () => context.pushReplacement('/quiz/leaderboard'), child: const Text('Lihat leaderboard mingguan')),
              const Text(
                'Jawaban benar menambah poin. Semangat belajar!',
                textAlign: TextAlign.center,
                style: TextStyle(color: textGray, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Leaderboard
class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)!;
    final lb = ref.watch(leaderboardProvider).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      backgroundColor: _quizBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _QuizHeader(
            title: 'Leaderboard Mingguan',
            subtitle: 'Poin dari semua permainan minggu ini',
            onBack: context.canPop() ? () => context.pop() : () => context.go('/app'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lb.isEmpty) const EmptyState(icon: Icons.emoji_events_outlined, text: 'Belum ada skor minggu ini. Jadilah yang pertama!'),
                for (final (i, e) in lb.indexed)
                  _Card(
                    border: e.key == me.name ? brandBlue : null,
                    color: i == 0 ? const Color(0xFFFFFBEB) : Colors.white,
                    padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                    child: Row(
                      children: [
                        _Letter('${i + 1}', fg: _playerColors[i.clamp(0, 3)].$1, bg: _playerColors[i.clamp(0, 3)].$2, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.key + (e.key == me.name ? ' (kamu)' : ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: textDark),
                          ),
                        ),
                        if (i == 0) const Padding(padding: EdgeInsets.only(right: 6), child: Text('🏆')),
                        Text(
                          '${e.value} poin',
                          style: TextStyle(fontWeight: FontWeight.w800, color: _playerColors[i.clamp(0, 3)].$1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
