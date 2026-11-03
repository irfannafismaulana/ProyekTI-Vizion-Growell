import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/quiz_rules.dart';
import '../data/quiz_bank.dart';
import '../models.dart';
import 'providers.dart';

/// Kode room demo untuk fitur "Gabung room" pada mode lokal (tanpa server).
const demoRoomCode = 'GRW24A';

enum QuizPhase { lobby, question, reveal, finished }

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.isBot,
    required this.profile,
    this.score = 0,
    this.correct = 0,
    this.lastPoints = 0,
    this.answer,
    this.answerSeconds,
    this.totalAnswerSeconds = 0,
  });

  final String id;
  final String name;
  final bool isBot;
  final QuizCategory profile;
  final int score;
  final int correct;
  final int lastPoints;
  final int? answer;
  final double? answerSeconds;
  final double totalAnswerSeconds;

  Player copyWith({int? score, int? correct, int? lastPoints, int? answer, double? answerSeconds, double? totalAnswerSeconds, bool clearAnswer = false}) =>
      Player(
        id: id,
        name: name,
        isBot: isBot,
        profile: profile,
        score: score ?? this.score,
        correct: correct ?? this.correct,
        lastPoints: lastPoints ?? this.lastPoints,
        answer: clearAnswer ? null : (answer ?? this.answer),
        answerSeconds: clearAnswer ? null : (answerSeconds ?? this.answerSeconds),
        totalAnswerSeconds: totalAnswerSeconds ?? this.totalAnswerSeconds,
      );
}

class QuizSession {
  const QuizSession({
    required this.code,
    required this.hostId,
    required this.meId,
    required this.settings,
    required this.players,
    this.questions = const [],
    this.index = 0,
    this.phase = QuizPhase.lobby,
    this.secondsLeft = 0,
    this.message,
  });

  final String code;
  final String hostId;
  final String meId;
  final QuizSettings settings;
  final List<Player> players;
  final List<Question> questions;
  final int index;
  final QuizPhase phase;
  final double secondsLeft;
  final String? message;

  bool get iAmHost => hostId == meId;
  Player get me => players.firstWhere((p) => p.id == meId);
  Question? get current => index < questions.length ? questions[index] : null;
  List<Player> get ranking => [...players]..sort((a, b) => b.score.compareTo(a.score));

  QuizSession copyWith({
    List<Player>? players,
    List<Question>? questions,
    int? index,
    QuizPhase? phase,
    double? secondsLeft,
    String? message,
  }) =>
      QuizSession(
        code: code,
        hostId: hostId,
        meId: meId,
        settings: settings,
        players: players ?? this.players,
        questions: questions ?? this.questions,
        index: index ?? this.index,
        phase: phase ?? this.phase,
        secondsLeft: secondsLeft ?? this.secondsLeft,
        message: message,
      );
}

QuizCategory profileOf(Role r) => r == Role.teen ? QuizCategory.remaja : QuizCategory.orangTua;

/// Mesin kuis lokal. Pemain lain adalah bot simulasi; pada tahap Supabase,
/// sumber pemain diganti Realtime Broadcast/Presence tanpa mengubah aturan.
class QuizEngine extends Notifier<QuizSession?> {
  final _rng = math.Random();
  final List<Timer> _timers = [];
  Timer? _ticker;
  DateTime? _questionStart;
  final Map<String, (double, int)> _botPlan = {}; // id -> (detik menjawab, indeks jawaban)

  @override
  QuizSession? build() {
    ref.onDispose(_cancelAll);
    return null;
  }

  void _cancelAll() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _ticker?.cancel();
  }

  void _after(Duration d, void Function() f) => _timers.add(Timer(d, f));

  Player _bot(String name, QuizCategory profile) =>
      Player(id: 'bot_${name.toLowerCase()}', name: 'Bot $name', isBot: true, profile: profile);

  // ------------------------------------------------------------ room
  String? createRoom({required AppUser me, required QuizSettings settings, QuizCategory? myProfile}) {
    final err = settings.validate();
    if (err != null) return err;
    if (me.role == Role.health || me.role == Role.admin) return 'Kuis hanya untuk peran orang tua dan remaja.';
    _cancelAll();
    state = QuizSession(
      code: generateRoomCode(_rng),
      hostId: me.id,
      meId: me.id,
      settings: settings,
      players: [Player(id: me.id, name: me.name, isBot: false, profile: myProfile ?? profileOf(me.role))],
    );
    // Simulasi pemain lain bergabung ke lobi.
    final bots = [_bot('Rina', QuizCategory.remaja), _bot('Adi', QuizCategory.orangTua), _bot('Maya', QuizCategory.umum)];
    for (var i = 0; i < bots.length; i++) {
      _after(Duration(milliseconds: 1200 * (i + 1)), () {
        final s = state;
        if (s == null || s.phase != QuizPhase.lobby || s.players.length >= 30) return;
        state = s.copyWith(players: [...s.players, bots[i]]);
      });
    }
    return null;
  }

  String? joinRoom({required AppUser me, required String code, QuizCategory? myProfile}) {
    if (me.role == Role.health || me.role == Role.admin) return 'Kuis hanya untuk peran orang tua dan remaja.';
    final c = code.trim().toUpperCase();
    if (c.length != 6) return 'Kode room harus 6 karakter.';
    if (c != demoRoomCode) {
      return 'Room $c tidak ditemukan. Mode lokal hanya menyediakan room demo $demoRoomCode (room antar-perangkat aktif setelah tersambung Supabase).';
    }
    _cancelAll();
    final host = _bot('Rina', QuizCategory.remaja);
    state = QuizSession(
      code: c,
      hostId: host.id,
      meId: me.id,
      settings: const QuizSettings(difficulty: Difficulty.mudah, category: QuizCategory.campuran, questionCount: 5, secondsPerQuestion: 15),
      players: [host, _bot('Adi', QuizCategory.orangTua), Player(id: me.id, name: me.name, isBot: false, profile: myProfile ?? profileOf(me.role))],
      message: 'Menunggu room master memulai kuis…',
    );
    _after(const Duration(seconds: 4), start);
    return null;
  }

  void leave() {
    _cancelAll();
    state = null;
  }

  /// Room master memulai kuis; minimal 2 pemain (Gambar E6).
  String? start() {
    final s = state;
    if (s == null || s.phase != QuizPhase.lobby) return null;
    if (s.players.length < 2) return 'Minimal 2 pemain untuk memulai kuis.';
    final qs = selectQuestions(
      bank: quizBank,
      settings: s.settings,
      playerProfiles: s.players.map((p) => p.profile).toList(),
      rng: _rng,
    );
    state = s.copyWith(questions: qs, index: 0);
    _beginQuestion();
    return null;
  }

  void _beginQuestion() {
    final s = state!;
    final q = s.current!;
    final dur = s.settings.secondsPerQuestion.toDouble();
    _questionStart = clock.now();
    _botPlan.clear();
    final accuracy = switch (q.difficulty) { Difficulty.mudah => 0.8, Difficulty.sedang => 0.6, Difficulty.sulit => 0.45 };
    for (final p in s.players.where((p) => p.isBot)) {
      final correct = _rng.nextDouble() < accuracy;
      final wrong = ([0, 1, 2, 3]..remove(q.answer))..shuffle(_rng);
      _botPlan[p.id] = (2 + _rng.nextDouble() * (dur * 0.7), correct ? q.answer : wrong.first);
    }
    // ER-7.3: semua pemain menerima soal yang sama pada saat yang sama.
    state = s.copyWith(
      phase: QuizPhase.question,
      secondsLeft: dur,
      players: [for (final p in s.players) p.copyWith(clearAnswer: true, lastPoints: 0)],
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    final s = state;
    if (s == null || s.phase != QuizPhase.question) return;
    final dur = s.settings.secondsPerQuestion.toDouble();
    final elapsed = clock.now().difference(_questionStart!).inMilliseconds / 1000;
    var players = s.players;
    for (final p in players.where((p) => p.isBot && p.answer == null)) {
      final plan = _botPlan[p.id]!;
      if (elapsed >= plan.$1) {
        players = [for (final x in players) x.id == p.id ? x.copyWith(answer: plan.$2, answerSeconds: plan.$1) : x];
      }
    }
    final left = math.max(0.0, dur - elapsed);
    state = s.copyWith(players: players, secondsLeft: left);
    if (left <= 0 || players.every((p) => p.answer != null)) _reveal();
  }

  void answer(int option) {
    final s = state;
    if (s == null || s.phase != QuizPhase.question || s.me.answer != null) return;
    final elapsed = clock.now().difference(_questionStart!).inMilliseconds / 1000;
    state = s.copyWith(players: [for (final p in s.players) p.id == s.meId ? p.copyWith(answer: option, answerSeconds: elapsed) : p]);
    _tick();
  }

  void _reveal() {
    _ticker?.cancel();
    final s = state!;
    final q = s.current!;
    final dur = s.settings.secondsPerQuestion;
    // ER-7.3: papan skor dihitung segera setelah waktu habis/semua menjawab.
    final players = [
      for (final p in s.players)
        () {
          final ok = p.answer == q.answer;
          final pts = pointsFor(correct: ok, secondsLeft: dur - (p.answerSeconds ?? dur.toDouble()), duration: dur);
          return p.copyWith(
            score: p.score + pts,
            correct: p.correct + (ok ? 1 : 0),
            lastPoints: pts,
            totalAnswerSeconds: p.totalAnswerSeconds + (p.answerSeconds ?? dur.toDouble()),
          );
        }(),
    ];
    state = s.copyWith(phase: QuizPhase.reveal, players: players, secondsLeft: 0);
    _after(const Duration(milliseconds: 3500), _next);
  }

  void _next() {
    final s = state;
    if (s == null) return;
    if (s.index + 1 < s.questions.length) {
      state = s.copyWith(index: s.index + 1);
      _beginQuestion();
    } else {
      state = s.copyWith(phase: QuizPhase.finished);
      _finish();
    }
  }

  void _finish() {
    final s = state!;
    final lb = ref.read(leaderboardProvider.notifier);
    final me = s.me;
    for (final p in s.players) {
      if (p.id == s.meId) {
        // Skor sendiri disimpan ke database (mode Supabase); pemain lain/bot hanya di layar.
        lb.recordMine(name: p.name, points: p.score, correct: p.correct, total: s.questions.length);
      } else {
        lb.addPoints(p.name, p.score);
      }
    }
    ref.read(badgesProvider.notifier).recordGame(
          s.meId,
          correct: me.correct,
          total: s.questions.length,
          avgSeconds: s.questions.isEmpty ? 0 : me.totalAnswerSeconds / s.questions.length,
        );
  }
}

final quizProvider = NotifierProvider<QuizEngine, QuizSession?>(QuizEngine.new);
