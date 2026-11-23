import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../core/quiz_rules.dart';
import '../data/quiz_bank.dart';
import '../models.dart';
import 'providers.dart';
import 'quiz_live.dart';

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
    this.capacity = 4,
    required this.players,
    this.questions = const [],
    this.index = 0,
    this.phase = QuizPhase.lobby,
    this.secondsLeft = 0,
    this.message,
    this.myHistory = const [],
    this.isLive = false,
  });

  /// True = ruang antar-perangkat lewat Supabase; false = lawan bot (mode lokal/latihan).
  final bool isLive;

  final String code;
  final String hostId;
  final String meId;
  final QuizSettings settings;

  /// Mode ruang: 2 pemain (duel) atau 4 pemain (battle).
  final int capacity;
  final List<Player> players;
  final List<Question> questions;
  final int index;
  final QuizPhase phase;
  final double secondsLeft;
  final String? message;

  /// Benar/salah jawaban saya per soal yang sudah dinilai (untuk streak & pembahasan).
  final List<bool> myHistory;

  /// Jumlah jawaban benar berturut-turut sampai soal terakhir yang dinilai.
  int get streak {
    var n = 0;
    for (final ok in myHistory.reversed) {
      if (!ok) break;
      n++;
    }
    return n;
  }

  bool get iAmHost => hostId == meId;
  bool get isFull => players.length >= capacity;
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
    List<bool>? myHistory,
  }) =>
      QuizSession(
        code: code,
        hostId: hostId,
        meId: meId,
        settings: settings,
        capacity: capacity,
        players: players ?? this.players,
        questions: questions ?? this.questions,
        index: index ?? this.index,
        phase: phase ?? this.phase,
        secondsLeft: secondsLeft ?? this.secondsLeft,
        message: message,
        myHistory: myHistory ?? this.myHistory,
        isLive: isLive,
      );
}

QuizCategory profileOf(Role r) => r == Role.teen ? QuizCategory.remaja : QuizCategory.orangTua;

/// Mesin kuis. Dua mode:
/// - **live** (tersambung Supabase): ruang antar-perangkat; fase & nilai diatur server
///   (`quiz_*` RPC), perubahan diterima lewat Realtime + polling cadangan.
/// - **bot** (mode lokal, atau "Latihan dengan bot"): pemain lain adalah bot simulasi.
class QuizEngine extends Notifier<QuizSession?> {
  final _rng = math.Random();
  final List<Timer> _timers = [];
  Timer? _ticker;
  DateTime? _questionStart;
  final Map<String, (double, int)> _botPlan = {}; // id -> (detik menjawab, indeks jawaban)
  bool _practice = false;

  // ---- live
  LiveQuizApi? _api;
  String? _roomId;
  RealtimeChannel? _channel;
  Timer? _poll;
  Timer? _reloadDebounce;
  Duration _serverOffset = Duration.zero; // jam server - jam perangkat
  DateTime? _phaseStart; // jam server
  DateTime _lastTickCall = DateTime(2000);
  int _loadSeq = 0;
  bool _finishedHandled = false;
  (int, int)? _pendingChoice; // (indeks soal, pilihan) sebelum dikonfirmasi server

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
    _ticker = null;
    _poll?.cancel();
    _poll = null;
    _reloadDebounce?.cancel();
    final ch = _channel;
    _channel = null;
    if (ch != null) unawaited(_api?.client.removeChannel(ch));
  }

  void _after(Duration d, void Function() f) => _timers.add(Timer(d, f));

  Player _bot(String name, QuizCategory profile) =>
      Player(id: 'bot_${name.toLowerCase()}', name: 'Bot $name', isBot: true, profile: profile);

  LiveQuizApi? get _liveApi {
    final b = ref.read(backendProvider);
    return b == null ? null : LiveQuizApi(b.client);
  }

  /// True bila "Buat Ruang" membuat ruang antar-perangkat (tersambung Supabase).
  bool get canPlayLive => ref.read(backendProvider) != null;

  String? _checkPlayer(AppUser me) =>
      me.role == Role.health || me.role == Role.admin ? 'Kuis hanya untuk peran orang tua dan remaja.' : null;

  // ------------------------------------------------------------ room
  /// [capacity]: mode 2 pemain (duel) atau 4 pemain (battle).
  /// [practice]: paksa lawan bot walau tersambung database (skor tidak masuk papan skor).
  Future<String?> createRoom({
    required AppUser me,
    required QuizSettings settings,
    QuizCategory? myProfile,
    int capacity = 4,
    bool practice = false,
  }) async {
    final err = settings.validate();
    if (err != null) return err;
    if (capacity != 2 && capacity != 4) return 'Mode permainan harus 2 atau 4 pemain.';
    final roleErr = _checkPlayer(me);
    if (roleErr != null) return roleErr;
    final api = _liveApi;
    if (api != null && !practice) {
      return _enterLive(
        api,
        () => api.create(
          capacity: capacity,
          difficulty: settings.difficulty.name,
          category: settings.category.name,
          count: settings.questionCount,
          seconds: settings.secondsPerQuestion,
          profile: (myProfile ?? profileOf(me.role)).name,
        ),
      );
    }
    _resetLocal();
    _practice = api != null;
    state = QuizSession(
      code: generateRoomCode(_rng),
      hostId: me.id,
      meId: me.id,
      settings: settings,
      capacity: capacity,
      players: [Player(id: me.id, name: me.name, isBot: false, profile: myProfile ?? profileOf(me.role))],
    );
    // Simulasi pemain lain bergabung ke lobi sampai ruang penuh.
    final bots = [_bot('Rina', QuizCategory.remaja), _bot('Adi', QuizCategory.orangTua), _bot('Maya', QuizCategory.umum)].take(capacity - 1).toList();
    for (var i = 0; i < bots.length; i++) {
      _after(Duration(milliseconds: 1200 * (i + 1)), () {
        final s = state;
        if (s == null || s.phase != QuizPhase.lobby || s.isFull) return;
        state = s.copyWith(players: [...s.players, bots[i]]);
      });
    }
    return null;
  }

  Future<String?> joinRoom({required AppUser me, required String code, QuizCategory? myProfile}) async {
    final roleErr = _checkPlayer(me);
    if (roleErr != null) return roleErr;
    final c = code.trim().toUpperCase();
    if (c.length != 6) return 'Kode ruang harus 6 karakter.';
    final api = _liveApi;
    if (api != null) return _enterLive(api, () => api.join(c, (myProfile ?? profileOf(me.role)).name));
    if (c != demoRoomCode) {
      return 'Ruang $c tidak ditemukan. Mode lokal hanya menyediakan ruang demo $demoRoomCode (ruang antar-perangkat aktif setelah tersambung Supabase).';
    }
    _resetLocal();
    final host = _bot('Rina', QuizCategory.remaja);
    state = QuizSession(
      code: c,
      hostId: host.id,
      meId: me.id,
      settings: const QuizSettings(difficulty: Difficulty.mudah, category: QuizCategory.campuran, questionCount: 5, secondsPerQuestion: 15),
      capacity: 2,
      players: [host, Player(id: me.id, name: me.name, isBot: false, profile: myProfile ?? profileOf(me.role))],
      message: 'Menunggu host memulai kuis…',
    );
    _after(const Duration(seconds: 4), start);
    return null;
  }

  void _resetLocal() {
    _cancelAll();
    _api = null;
    _roomId = null;
    _practice = false;
  }

  void leave() {
    final api = _api, room = _roomId;
    _resetLocal();
    state = null;
    if (api != null && room != null) unawaited(api.leave(room).catchError((Object _) {}));
  }

  /// Room master memulai kuis; minimal 2 pemain (Gambar E6).
  Future<String?> start() async {
    final s = state;
    if (s == null || s.phase != QuizPhase.lobby) return null;
    if (s.players.length < 2) return 'Minimal 2 pemain untuk memulai kuis.';
    final qs = selectQuestions(
      bank: quizBank,
      settings: s.settings,
      playerProfiles: s.players.map((p) => p.profile).toList(),
      rng: _rng,
    );
    final api = _api, room = _roomId;
    if (s.isLive && api != null && room != null) {
      try {
        await api.start(room, [for (final q in qs) q.id]);
        _reload();
        return null;
      } catch (e) {
        return describeBackendError(e);
      }
    }
    state = s.copyWith(questions: qs, index: 0);
    _beginQuestion();
    return null;
  }

  // ------------------------------------------------------------ live (Supabase)
  Future<String?> _enterLive(LiveQuizApi api, Future<String> Function() open) async {
    _resetLocal();
    state = null;
    try {
      final roomId = await open();
      _api = api;
      _roomId = roomId;
      _finishedHandled = false;
      _pendingChoice = null;
      await _syncClock();
      final snap = await api.load(roomId);
      if (snap == null) return 'Ruang tidak ditemukan.';
      _apply(snap);
      _channel = api.watch(roomId, _reload);
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _reload());
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _liveTick());
      return null;
    } catch (e) {
      _resetLocal();
      return describeBackendError(e);
    }
  }

  DateTime get _serverNow => DateTime.now().add(_serverOffset);

  Future<void> _syncClock() async {
    final api = _api, room = _roomId;
    if (api == null || room == null) return;
    final sent = DateTime.now();
    final server = await api.tick(room);
    final rtt = DateTime.now().difference(sent);
    _serverOffset = server.difference(sent.add(rtt ~/ 2));
  }

  void _reload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 60), () async {
      final api = _api, room = _roomId;
      if (api == null || room == null) return;
      final seq = ++_loadSeq;
      try {
        final snap = await api.load(room);
        if (seq != _loadSeq || _roomId != room) return;
        if (snap == null) {
          _resetLocal();
          state = null;
          ref.read(syncErrorProvider.notifier).report('Ruang kuis sudah ditutup host.');
          return;
        }
        _apply(snap);
      } catch (_) {
        // Koneksi terputus sesaat: coba lagi pada polling berikutnya.
      }
    });
  }

  static QuizPhase _phaseOf(String s) => switch (s) {
        'question' => QuizPhase.question,
        'reveal' => QuizPhase.reveal,
        'finished' => QuizPhase.finished,
        _ => QuizPhase.lobby,
      };

  void _apply(LiveRoomSnapshot snap) {
    final r = snap.room;
    final meId = _api!.userId;
    final phase = _phaseOf(r['status'] as String);
    final index = r['current_index'] as int;
    final ids = (r['question_ids'] as List).cast<String>();
    final byId = {for (final q in quizBank) q.id: q};
    final settings = QuizSettings(
      difficulty: Difficulty.values.byName(r['difficulty'] as String),
      category: QuizCategory.values.byName(r['category'] as String),
      questionCount: r['question_count'] as int,
      secondsPerQuestion: r['seconds_per_question'] as int,
    );
    _phaseStart = DateTime.parse(r['phase_started_at'] as String);
    if (_pendingChoice != null && (_pendingChoice!.$1 != index || phase != QuizPhase.question)) _pendingChoice = null;

    int? answerOf(Map<String, dynamic> p) {
      final isMe = p['user_id'] == meId;
      if (phase == QuizPhase.question) {
        if (isMe) return snap.myAnswers[index]?.$1 ?? (_pendingChoice?.$1 == index ? _pendingChoice!.$2 : null);
        return p['answered_index'] == index ? -1 : null; // sudah menjawab, isi jawaban dirahasiakan
      }
      if (phase == QuizPhase.lobby) return null;
      return p['last_choice'] as int?;
    }

    final players = [
      for (final p in snap.players)
        Player(
          id: p['user_id'] as String,
          name: p['display_name'] as String,
          isBot: false,
          profile: QuizCategory.values.byName(p['profile'] as String),
          score: p['score'] as int,
          correct: p['correct'] as int,
          lastPoints: p['last_points'] as int,
          answer: answerOf(p),
          totalAnswerSeconds: (p['total_answer_ms'] as int) / 1000,
        ),
    ];
    final judged = switch (phase) { QuizPhase.lobby => 0, QuizPhase.question => index, _ => index + 1 };
    state = QuizSession(
      code: r['code'] as String,
      hostId: r['host_id'] as String,
      meId: meId,
      settings: settings,
      capacity: r['capacity'] as int,
      players: players,
      questions: [for (final id in ids) ?byId[id]],
      index: index,
      phase: phase,
      secondsLeft: _secondsLeft(phase, settings.secondsPerQuestion),
      myHistory: [for (var i = 0; i < judged; i++) snap.myAnswers[i]?.$2 ?? false],
      isLive: true,
    );
    if (phase == QuizPhase.finished && !_finishedHandled) {
      _finishedHandled = true;
      _finishLive();
    }
  }

  double _secondsLeft(QuizPhase phase, int duration) {
    if (phase != QuizPhase.question || _phaseStart == null) return 0;
    final elapsed = _serverNow.difference(_phaseStart!).inMilliseconds / 1000;
    return (duration - elapsed).clamp(0.0, duration.toDouble());
  }

  /// Hitung mundur lokal; bila waktu soal/pembahasan habis, minta server memajukan fase.
  void _liveTick() {
    final s = state, api = _api, room = _roomId;
    if (s == null || api == null || room == null || _phaseStart == null) return;
    if (s.phase == QuizPhase.question) {
      final left = _secondsLeft(s.phase, s.settings.secondsPerQuestion);
      if ((left - s.secondsLeft).abs() >= 0.1) state = s.copyWith(secondsLeft: left, message: s.message);
    }
    final elapsed = _serverNow.difference(_phaseStart!).inMilliseconds / 1000;
    final due = (s.phase == QuizPhase.question && elapsed >= s.settings.secondsPerQuestion) ||
        (s.phase == QuizPhase.reveal && elapsed >= 3.6);
    if (due && DateTime.now().difference(_lastTickCall) > const Duration(milliseconds: 900)) {
      _lastTickCall = DateTime.now();
      unawaited(api.tick(room).then((_) => _reload(), onError: (Object _) {}));
    }
  }

  void _answerLive(QuizSession s, int option) {
    final api = _api, room = _roomId;
    if (api == null || room == null) return;
    _pendingChoice = (s.index, option);
    state = s.copyWith(players: [for (final p in s.players) p.id == s.meId ? p.copyWith(answer: option) : p]);
    unawaited(api.answer(room, s.index, option).then((_) => _reload(), onError: (Object e) {
      _pendingChoice = null;
      ref.read(syncErrorProvider.notifier).report(describeBackendError(e));
      _reload();
    }));
  }

  /// Skor semua pemain sudah disimpan server; perbarui papan skor & lencana saya.
  void _finishLive() {
    final s = state!;
    final api = _api;
    final me = s.me;
    ref.read(badgesProvider.notifier).recordGame(
          s.meId,
          correct: me.correct,
          total: s.questions.length,
          avgSeconds: s.questions.isEmpty ? 0 : me.totalAnswerSeconds / s.questions.length,
        );
    if (api != null) {
      unawaited(api.leaderboard().then((lb) => ref.read(leaderboardProvider.notifier).replaceAll(lb), onError: (Object _) {}));
    }
    _ticker?.cancel();
    _poll?.cancel();
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
    if (s.isLive) return _answerLive(s, option);
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
    state = s.copyWith(phase: QuizPhase.reveal, players: players, secondsLeft: 0, myHistory: [...s.myHistory, s.me.answer == q.answer]);
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
    // Latihan dengan bot saat tersambung database tidak masuk papan skor:
    // skor resmi hanya dari ruang live yang dinilai server.
    if (!_practice) {
      for (final p in s.players) {
        if (p.id == s.meId) {
          lb.recordMine(name: p.name, points: p.score, correct: p.correct, total: s.questions.length);
        } else {
          lb.addPoints(p.name, p.score);
        }
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
