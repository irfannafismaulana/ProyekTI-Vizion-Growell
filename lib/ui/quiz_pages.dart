import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/quiz_rules.dart';
import '../models.dart';
import '../state/providers.dart';
import '../state/quiz_engine.dart';
import 'common.dart';

String _diff(Difficulty d) => switch (d) { Difficulty.mudah => 'Mudah', Difficulty.sedang => 'Sedang', Difficulty.sulit => 'Sulit' };

// ---------------------------------------------------------------- Beranda kuis
class QuizHome extends ConsumerWidget {
  const QuizHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)!;
    final lb = ref.watch(leaderboardProvider).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final badges = ref.watch(badgesProvider)[me.id] ?? const <String>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Kuis Kesehatan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: brandBlue,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Main bareng, belajar cegah stunting', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Buat room, bagikan kode, dan jawab soal secepat mungkin.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton.tonal(onPressed: () => context.push('/quiz/create'), child: const Text('Buat room')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                    onPressed: () => context.push('/quiz/join'),
                    child: const Text('Gabung room'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
        if (badges.isNotEmpty) ...[
          const SectionTitle('Lencanamu'),
          Wrap(spacing: 8, children: [for (final b in badges) Chip(avatar: const Icon(Icons.military_tech, size: 18), label: Text(b))]),
        ],
        SectionTitle('Leaderboard mingguan',
            trailing: TextButton(onPressed: () => context.push('/quiz/leaderboard'), child: const Text('Lihat semua'))),
        for (var i = 0; i < lb.length && i < 5; i++)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(lb[i].key, style: TextStyle(fontWeight: lb[i].key == me.name ? FontWeight.w800 : FontWeight.normal)),
              trailing: Text('${lb[i].value} poin'),
            ),
          ),
        const SizedBox(height: 8),
        const DraftBadge(text: 'Bank soal draf (40 soal) — perlu ditinjau nakes'),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Buat room
class CreateRoomPage extends ConsumerStatefulWidget {
  const CreateRoomPage({super.key});
  @override
  ConsumerState<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends ConsumerState<CreateRoomPage> {
  Difficulty _difficulty = Difficulty.sedang;
  QuizCategory _category = QuizCategory.campuran;
  double _count = 5;
  double _seconds = 20;
  bool _asUmum = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Buat room kuis')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Tingkat kesulitan'),
        const SizedBox(height: 6),
        SegmentedButton<Difficulty>(
          segments: [for (final d in Difficulty.values) ButtonSegment(value: d, label: Text(_diff(d)))],
          selected: {_difficulty},
          onSelectionChanged: (s) => setState(() => _difficulty = s.first),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<QuizCategory>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Kategori pemain'),
          items: [for (final c in QuizCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
          onChanged: (v) => setState(() => _category = v!),
        ),
        const Text('Campuran: soal bergiliran sesuai profil pemain yang hadir.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 16),
        Text('Jumlah soal: ${_count.round()}'),
        Slider(value: _count, min: 5, max: 20, divisions: 15, label: '${_count.round()}', onChanged: (v) => setState(() => _count = v)),
        Text('Durasi per soal: ${_seconds.round()} detik'),
        Slider(value: _seconds, min: 10, max: 30, divisions: 20, label: '${_seconds.round()}', onChanged: (v) => setState(() => _seconds = v)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Main dengan profil Umum (bukan ${profileOf(me.role).label})'),
          value: _asUmum,
          onChanged: (v) => setState(() => _asUmum = v),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final err = ref.read(quizProvider.notifier).createRoom(
                  me: me,
                  settings: QuizSettings(difficulty: _difficulty, category: _category, questionCount: _count.round(), secondsPerQuestion: _seconds.round()),
                  myProfile: _asUmum ? QuizCategory.umum : null,
                );
            if (err != null) return showError(context, ArgumentError(err));
            context.pushReplacement('/quiz/room');
          },
          child: const Padding(padding: EdgeInsets.all(12), child: Text('Buat room')),
        ),
        const SizedBox(height: 8),
        const Text('Mode lokal: pemain lain disimulasikan (bot). Room antar-perangkat aktif setelah tersambung Supabase Realtime.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Gabung room
class JoinRoomPage extends ConsumerStatefulWidget {
  const JoinRoomPage({super.key});
  @override
  ConsumerState<JoinRoomPage> createState() => _JoinRoomPageState();
}

class _JoinRoomPageState extends ConsumerState<JoinRoomPage> {
  final _code = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Gabung room')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Kode room (6 karakter)', helperText: 'Mode lokal: gunakan kode demo $demoRoomCode'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final err = ref.read(quizProvider.notifier).joinRoom(me: me, code: _code.text);
            if (err != null) return showError(context, ArgumentError(err));
            context.pushReplacement('/quiz/room');
          },
          child: const Padding(padding: EdgeInsets.all(12), child: Text('Gabung')),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Ruang kuis
class QuizRoomPage extends ConsumerWidget {
  const QuizRoomPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(quizProvider);
    if (s == null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.sports_esports, text: 'Tidak ada room aktif.',
          action: FilledButton(onPressed: () => context.go('/app'), child: const Text('Kembali'))));
    }
    return PopScope(
      canPop: s.phase == QuizPhase.finished || s.phase == QuizPhase.lobby,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(quizProvider.notifier).leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Room ${s.code}'),
          automaticallyImplyLeading: s.phase == QuizPhase.finished || s.phase == QuizPhase.lobby,
        ),
        body: switch (s.phase) {
          QuizPhase.lobby => _Lobby(s: s),
          QuizPhase.question => _QuestionView(s: s),
          QuizPhase.reveal => _Reveal(s: s),
          QuizPhase.finished => _Finished(s: s),
        },
      ),
    );
  }
}

class _Lobby extends ConsumerWidget {
  const _Lobby({required this.s});
  final QuizSession s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: Text('Kode room', style: Theme.of(context).textTheme.labelLarge)),
      Center(child: SelectableText(s.code, style: const TextStyle(fontSize: 40, letterSpacing: 6, fontWeight: FontWeight.w800, color: brandBlue))),
      Center(
        child: Text('${_diff(s.settings.difficulty)} • ${s.settings.category.label} • ${s.settings.questionCount} soal • ${s.settings.secondsPerQuestion} detik',
            style: const TextStyle(color: Colors.black54)),
      ),
      SectionTitle('Pemain (${s.players.length}/30)'),
      for (final p in s.players)
        ListTile(
          leading: CircleAvatar(child: Icon(p.isBot ? Icons.smart_toy_outlined : Icons.person)),
          title: Text(p.name + (p.id == s.hostId ? ' (room master)' : '')),
          subtitle: Text('Profil: ${p.profile.label}'),
        ),
      const SizedBox(height: 12),
      if (s.iAmHost)
        FilledButton(
          onPressed: s.players.length >= 2
              ? () {
                  final err = ref.read(quizProvider.notifier).start();
                  if (err != null) showError(context, ArgumentError(err));
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(s.players.length >= 2 ? 'Mulai kuis' : 'Menunggu pemain lain… (min. 2)'),
          ),
        )
      else
        Center(child: Text(s.message ?? 'Menunggu room master…')),
    ]);
  }
}

class _QuestionView extends ConsumerWidget {
  const _QuestionView({required this.s});
  final QuizSession s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = s.current!;
    final mine = s.me.answer;
    final answered = s.players.where((p) => p.answer != null).length;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        Text('Soal ${s.index + 1}/${s.questions.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text('${s.secondsLeft.ceil()} detik'),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: s.secondsLeft / s.settings.secondsPerQuestion, minHeight: 8, borderRadius: BorderRadius.circular(4)),
      const SizedBox(height: 20),
      Text(q.text, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 20),
      for (var i = 0; i < q.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(16),
              backgroundColor: mine == i ? brandBlue.withValues(alpha: 0.3) : null,
            ),
            onPressed: mine == null ? () => ref.read(quizProvider.notifier).answer(i) : null,
            child: Text('${String.fromCharCode(65 + i)}. ${q.options[i]}'),
          ),
        ),
      const SizedBox(height: 8),
      Center(child: Text(mine == null ? 'Pilih jawaban sebelum waktu habis' : 'Jawaban terkirim. Menunggu pemain lain ($answered/${s.players.length})…',
          style: const TextStyle(color: Colors.black54))),
    ]);
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.s});
  final QuizSession s;
  @override
  Widget build(BuildContext context) {
    final q = s.current!;
    final me = s.me;
    final ok = me.answer == q.answer;
    return ListView(padding: const EdgeInsets.all(20), children: [
      NoticeCard(
        icon: ok ? Icons.check_circle : Icons.cancel,
        color: ok ? brandBlue : const Color(0xFFC62828),
        title: ok ? 'Benar! +${me.lastPoints} poin' : (me.answer == null ? 'Waktu habis' : 'Belum tepat'),
        text: 'Jawaban: ${q.options[q.answer]}',
      ),
      const SectionTitle('Papan skor'),
      for (final (i, p) in s.ranking.indexed)
        ListTile(
          dense: true,
          leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
          title: Text(p.name, style: TextStyle(fontWeight: p.id == s.meId ? FontWeight.w800 : FontWeight.normal)),
          subtitle: Text(p.lastPoints > 0 ? '+${p.lastPoints}' : '+0'),
          trailing: Text('${p.score}'),
        ),
      const SizedBox(height: 8),
      const Center(child: Text('Soal berikutnya segera dimulai…', style: TextStyle(color: Colors.black54))),
    ]);
  }
}

class _Finished extends ConsumerWidget {
  const _Finished({required this.s});
  final QuizSession s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = s.ranking.indexWhere((p) => p.id == s.meId) + 1;
    final badges = ref.watch(badgesProvider)[s.meId] ?? const <String>{};
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: Icon(rank == 1 ? Icons.emoji_events : Icons.flag, size: 56, color: Colors.amber)),
      Center(child: Text('Peringkat #$rank', style: Theme.of(context).textTheme.headlineSmall)),
      Center(child: Text('${s.me.score} poin • ${s.me.correct}/${s.questions.length} benar')),
      if (badges.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 6, children: [for (final b in badges) Chip(label: Text(b))]),
      ],
      const SectionTitle('Hasil akhir'),
      for (final (i, p) in s.ranking.indexed) ListTile(dense: true, leading: Text('#${i + 1}'), title: Text(p.name), trailing: Text('${p.score}')),
      const SectionTitle('Pembahasan'),
      for (final (i, q) in s.questions.indexed)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}. ${q.text}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Jawaban: ${q.options[q.answer]}', style: const TextStyle(color: brandBlue)),
              Text(q.explanation),
            ]),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton(onPressed: () => context.pushReplacement('/quiz/leaderboard'), child: const Text('Lihat leaderboard mingguan')),
      TextButton(
        onPressed: () {
          ref.read(quizProvider.notifier).leave();
          context.go('/app');
        },
        child: const Text('Selesai'),
      ),
    ]);
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
      appBar: AppBar(title: const Text('Leaderboard mingguan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final (i, e) in lb.indexed)
          Card(
            color: e.key == me.name ? brandBlue.withValues(alpha: 0.08) : null,
            child: ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(e.key),
              trailing: Text('${e.value} poin', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}
