import 'package:supabase_flutter/supabase_flutter.dart';

/// Keadaan satu ruang kuis dari database (PRD F5).
class LiveRoomSnapshot {
  const LiveRoomSnapshot({required this.room, required this.players, required this.myAnswers});

  /// Baris `quiz_rooms`.
  final Map<String, dynamic> room;

  /// Baris `quiz_room_players`, urut waktu bergabung.
  final List<Map<String, dynamic>> players;

  /// Jawaban saya per indeks soal: (pilihan, benar?). Jawaban pemain lain tidak terbaca (RLS).
  final Map<int, (int, bool)> myAnswers;
}

/// Pembungkus RPC kuis antar-perangkat. Semua aturan (giliran, waktu, nilai)
/// ditegakkan oleh fungsi di `supabase/migrations/20261123000002_kuis_live.sql`.
class LiveQuizApi {
  LiveQuizApi(this.client);
  final SupabaseClient client;

  String get userId => client.auth.currentUser!.id;

  Future<String> create({
    required int capacity,
    required String difficulty,
    required String category,
    required int count,
    required int seconds,
    required String profile,
  }) async =>
      await client.rpc('quiz_create_room', params: {
        'p_capacity': capacity,
        'p_difficulty': difficulty,
        'p_category': category,
        'p_count': count,
        'p_seconds': seconds,
        'p_profile': profile,
      }) as String;

  Future<String> join(String code, String profile) async =>
      await client.rpc('quiz_join_room', params: {'p_code': code, 'p_profile': profile}) as String;

  Future<void> start(String roomId, List<String> questionIds) =>
      client.rpc('quiz_start', params: {'p_room': roomId, 'p_question_ids': questionIds});

  Future<void> answer(String roomId, int index, int choice) =>
      client.rpc('quiz_answer', params: {'p_room': roomId, 'p_index': index, 'p_choice': choice});

  /// Memajukan fase bila waktunya tiba; mengembalikan jam server.
  Future<DateTime> tick(String roomId) async =>
      DateTime.parse(await client.rpc('quiz_tick', params: {'p_room': roomId}) as String);

  Future<void> leave(String roomId) => client.rpc('quiz_leave_room', params: {'p_room': roomId});

  /// Null bila ruang sudah ditutup atau saya bukan lagi anggotanya.
  Future<LiveRoomSnapshot?> load(String roomId) async {
    final (rooms, players, answers) = await (
      client.from('quiz_rooms').select().eq('id', roomId),
      client.from('quiz_room_players').select().eq('room_id', roomId).order('joined_at', ascending: true),
      client.from('quiz_answers').select('question_index, choice, correct').eq('room_id', roomId).eq('user_id', userId),
    ).wait;
    if (rooms.isEmpty || !players.any((p) => p['user_id'] == userId)) return null;
    return LiveRoomSnapshot(
      room: rooms.first,
      players: players,
      myAnswers: {for (final a in answers) a['question_index'] as int: (a['choice'] as int, a['correct'] as bool)},
    );
  }

  /// Dengarkan perubahan ruang & pemain (Realtime, disaring RLS).
  RealtimeChannel watch(String roomId, void Function() onChange) {
    return client
        .channel('quiz-$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'quiz_rooms',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: roomId),
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'quiz_room_players',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<Map<String, int>> leaderboard() async {
    final rows = await client.from('weekly_leaderboard').select();
    return {for (final r in rows) r['display_name'] as String: r['points'] as int};
  }
}
