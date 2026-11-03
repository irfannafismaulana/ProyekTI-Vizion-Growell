import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/zscore.dart';
import '../data/seed.dart';
import '../models.dart';
import 'providers.dart';

/// Pembaca provider generik; bisa `ref.read` (Notifier) atau `container.read`.
typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// Null = mode lokal (data contoh di memori, dipakai uji otomatis).
/// Terisi bila aplikasi dijalankan dengan --dart-define SUPABASE_URL & SUPABASE_PUBLISHABLE_KEY.
final backendProvider = Provider<SupabaseBackend?>((ref) => null);

// ---------------------------------------------------------------- Pesan gagal sinkron
class SyncErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void report(String message) => state = message;
}

final syncErrorProvider = NotifierProvider<SyncErrorNotifier, String?>(SyncErrorNotifier.new);

/// Pesan ramah untuk kesalahan dari Supabase.
String describeBackendError(Object e) {
  if (e is PostgrestException) {
    if (e.code == '42501') return 'Ditolak database (hak akses/RLS): ${e.message}';
    if (e.code == '23514' || e.code == 'P0001') return e.message;
    if (e.code == '23505') return 'Data sudah ada.';
    return 'Gagal menyimpan ke database: ${e.message}';
  }
  if (e is AuthException) return e.message;
  return 'Gagal terhubung ke database: $e';
}

/// Perubahan sudah diterapkan di layar; tulis ke database di latar belakang.
/// Bila gagal, kembalikan keadaan semula dan tampilkan pesan.
void syncToBackend(Ref ref, Future<void> Function(SupabaseBackend b) write, {void Function()? rollback}) {
  final b = ref.read(backendProvider);
  if (b == null) return;
  unawaited(write(b).catchError((Object e) {
    rollback?.call();
    ref.read(syncErrorProvider.notifier).report(describeBackendError(e));
  }));
}

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
double _num(Object? v) => (v as num).toDouble();
DateTime _ts(Object? v) => DateTime.parse(v as String).toLocal();

/// Email akun demo untuk rute `/demo/<userId>` pada mode database.
const demoEmails = {
  'u_rani': 'rani@demo.id',
  'u_fitri': 'fitri@demo.id',
  'u_wulan': 'wulan@demo.id',
  'u_dina': 'dina@demo.id',
  'u_irfan': 'irfan@demo.id',
  'u_siti': 'siti@demo.id',
  'u_budi': 'budi@demo.id',
  'u_sarah': 'sarah@demo.id',
  'u_rina': 'rina@demo.id',
  'u_candra': 'candra@demo.id',
  'u_admin': 'admin@demo.id',
};

/// Akses ke Supabase (PostgreSQL + Auth + Realtime). Semua query disaring RLS di server.
class SupabaseBackend {
  SupabaseBackend(this.client, {required this.url});
  final SupabaseClient client;
  final String url;
  RealtimeChannel? _channel;
  final Map<String, Timer> _debounce = {};

  String? get userId => client.auth.currentUser?.id;

  // ------------------------------------------------------------ Auth
  Future<void> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email.trim(), password: password);

  /// Mengembalikan true bila langsung masuk (konfirmasi email nonaktif di lokal).
  Future<bool> signUp({required String email, required String password, required Map<String, dynamic> data}) async {
    final r = await client.auth.signUp(email: email.trim(), password: password, data: data);
    return r.session != null;
  }

  Future<void> signOut() async {
    await unsubscribe();
    await client.auth.signOut();
  }

  Future<void> requestPasswordReset(String email) => client.auth.resetPasswordForEmail(email.trim());

  Future<void> verifyResetCode(String email, String code) =>
      client.auth.verifyOTP(type: OtpType.recovery, email: email.trim(), token: code.trim());

  Future<void> setNewPassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
    await client.auth.signOut();
  }

  // ------------------------------------------------------------ Muat data
  Future<List<AppUser>> _profiles() async {
    final rows = await client.from('profiles').select();
    return [
      for (final r in rows)
        AppUser(
          id: r['id'] as String,
          name: r['name'] as String,
          email: r['email'] as String,
          password: '',
          role: Role.values.byName(r['role'] as String),
          strNumber: r['str_number'] as String?,
          verified: r['verified'] as bool,
          title: r['title'] as String?,
          specialty: r['specialty'] as String?,
          experienceYears: r['experience_years'] as int?,
          workplace: r['workplace'] as String?,
        ),
    ];
  }

  Future<(List<Child>, List<Measurement>)> _childrenAndMeasurements() async {
    final (cRows, mRows) = await (
      client.from('children').select().order('created_at', ascending: true).order('id', ascending: true),
      client.from('measurements').select().order('measured_on', ascending: true),
    ).wait;
    final kids = [
      for (final r in cRows)
        Child(
          id: r['id'] as String,
          parentId: r['parent_id'] as String,
          name: r['name'] as String,
          sex: Sex.values.byName(r['sex'] as String),
          birthDate: DateTime.parse(r['birth_date'] as String),
          posyandu: r['posyandu'] as String,
          region: regionOfPosyandu[r['posyandu']] ?? '-',
        ),
    ];
    final byId = {for (final c in kids) c.id: c};
    final ms = <Measurement>[];
    for (final r in mRows) {
      final child = byId[r['child_id']];
      if (child == null) continue;
      final date = DateTime.parse(r['measured_on'] as String);
      final w = _num(r['weight_kg']), h = _num(r['height_cm']);
      ms.add(Measurement(
        id: r['id'] as String,
        childId: child.id,
        date: date,
        weightKg: w,
        heightCm: h,
        result: assess(sex: child.sex, birthDate: child.birthDate, measuredAt: date, weightKg: w, heightCm: h),
      ));
    }
    return (kids, ms);
  }

  Future<List<FoodEntry>> _food() async {
    final rows = await client.from('food_entries').select();
    return [
      for (final r in rows)
        FoodEntry(
          id: r['id'] as String,
          childId: r['child_id'] as String,
          date: DateTime.parse(r['eaten_on'] as String),
          meal: Meal.values.byName(r['meal'] as String),
          foodId: r['food_id'] as String,
          grams: _num(r['grams']),
        ),
    ];
  }

  Future<List<ConsultThread>> _threads() async {
    final rows = await client.from('consult_threads').select('id, parent_id, doctor_id, consult_messages(sender_id, body, sent_at)').order('created_at', ascending: true);
    return [
      for (final r in rows)
        ConsultThread(
          id: r['id'] as String,
          parentId: r['parent_id'] as String,
          doctorId: r['doctor_id'] as String,
          messages: [
            for (final m in (r['consult_messages'] as List).cast<Map<String, dynamic>>())
              Message(senderId: m['sender_id'] as String, text: m['body'] as String, time: _ts(m['sent_at'])),
          ]..sort((a, b) => a.time.compareTo(b.time)),
        ),
    ];
  }

  Future<List<ConsultNote>> _notes(List<ConsultThread> threads) async {
    final rows = await client.from('consult_notes').select().order('created_at', ascending: true);
    final parentOf = {for (final t in threads) t.id: t.parentId};
    return [
      for (final r in rows)
        ConsultNote(
          id: r['id'] as String,
          threadId: r['thread_id'] as String,
          parentId: parentOf[r['thread_id']] ?? '',
          doctorId: r['doctor_id'] as String,
          childId: r['child_id'] as String,
          title: r['title'] as String,
          date: _ts(r['created_at']),
          keterangan: r['keterangan'] as String,
          diagnosis: r['diagnosis'] as String,
          anjuran: r['anjuran'] as String,
          catatan: r['catatan'] as String,
        ),
    ];
  }

  Future<List<Appointment>> _appointments() async {
    final rows = await client.from('appointments').select();
    return [
      for (final r in rows)
        Appointment(id: r['id'] as String, childId: r['child_id'] as String, doctorId: r['doctor_id'] as String, date: _ts(r['scheduled_at'])),
    ];
  }

  Future<Map<String, int>> _leaderboard() async {
    final rows = await client.from('weekly_leaderboard').select();
    return {for (final r in rows) r['display_name'] as String: r['points'] as int};
  }

  Future<(Set<String>, int)> _badges() async {
    final uid = userId!;
    final (rows, games) = await (
      client.from('user_badges').select('badge').eq('user_id', uid),
      client.from('quiz_scores').select('id').eq('user_id', uid),
    ).wait;
    return ({for (final r in rows) r['badge'] as String}, games.length);
  }

  Future<Set<String>> _ids(String table, String column) async {
    final rows = await client.from(table).select(column);
    return {for (final r in rows) r[column] as String};
  }

  /// Muat semua data yang boleh dilihat pengguna yang sedang masuk.
  Future<void> loadAll(Reader read) async {
    final (users, cm, food, threads, appts, lb, badges, saved, liked) = await (
      _profiles(),
      _childrenAndMeasurements(),
      _food(),
      _threads(),
      _appointments(),
      _leaderboard(),
      _badges(),
      _ids('bookmarks', 'item_id'),
      _ids('reel_likes', 'reel_id'),
    ).wait;
    final notes = await _notes(threads);
    read(usersProvider.notifier).replaceAll(users);
    read(childrenProvider.notifier).replaceAll(cm.$1);
    read(measurementsProvider.notifier).replaceAll(cm.$2);
    read(foodLogProvider.notifier).replaceAll(food);
    read(consultProvider.notifier).replaceAll(threads);
    read(consultNotesProvider.notifier).replaceAll(notes);
    read(appointmentsProvider.notifier).replaceAll(appts);
    read(leaderboardProvider.notifier).replaceAll(lb);
    read(badgesProvider.notifier).restore(userId!, badges.$1, badges.$2);
    read(bookmarksProvider.notifier).replaceAll(saved);
    read(likesProvider.notifier).replaceAll(liked);
  }

  // ------------------------------------------------------------ Realtime
  /// Dengarkan perubahan dari pengguna lain (chat, catatan, jadwal, verifikasi, pengukuran).
  void subscribe(Reader read) {
    unawaited(unsubscribe());
    void later(String key, Future<void> Function() reload) {
      _debounce[key]?.cancel();
      _debounce[key] = Timer(const Duration(milliseconds: 300), () => reload().catchError((Object _) {}));
    }

    Future<void> threads() async {
      final t = await _threads();
      read(consultProvider.notifier).replaceAll(t);
      read(consultNotesProvider.notifier).replaceAll(await _notes(t));
    }

    final reloaders = <String, Future<void> Function()>{
      'profiles': () async => read(usersProvider.notifier).replaceAll(await _profiles()),
      'children': () async {
        final (c, m) = await _childrenAndMeasurements();
        read(childrenProvider.notifier).replaceAll(c);
        read(measurementsProvider.notifier).replaceAll(m);
      },
      'consult_threads': threads,
      'consult_messages': threads,
      'consult_notes': threads,
      'appointments': () async => read(appointmentsProvider.notifier).replaceAll(await _appointments()),
    };
    reloaders['measurements'] = reloaders['children']!;

    var ch = client.channel('growell-changes');
    for (final e in reloaders.entries) {
      final group = e.key == 'measurements' ? 'children' : (e.key.startsWith('consult_') ? 'consult' : e.key);
      ch = ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: e.key,
        callback: (_) => later(group, e.value),
      );
    }
    _channel = ch..subscribe();
  }

  Future<void> unsubscribe() async {
    final c = _channel;
    _channel = null;
    for (final t in _debounce.values) {
      t.cancel();
    }
    if (c != null) await client.removeChannel(c);
  }

  // ------------------------------------------------------------ Tulis data
  Future<void> insertChild(Child c) => client.from('children').insert({
        'id': c.id,
        'parent_id': c.parentId,
        'name': c.name,
        'sex': c.sex.name,
        'birth_date': ymd(c.birthDate),
        'posyandu': c.posyandu,
      });

  Future<void> insertMeasurement(Measurement m, {required String source}) => client.from('measurements').insert({
        'id': m.id,
        'child_id': m.childId,
        'measured_on': ymd(m.date),
        'weight_kg': m.weightKg,
        'height_cm': m.heightCm,
        'source': source,
      });

  Future<void> insertFood(List<FoodEntry> entries) => client.from('food_entries').insert([
        for (final e in entries)
          {'id': e.id, 'child_id': e.childId, 'eaten_on': ymd(e.date), 'meal': e.meal.name, 'food_id': e.foodId, 'grams': e.grams},
      ]);

  Future<void> deleteFood(String id) => client.from('food_entries').delete().eq('id', id);

  Future<void> insertThread(ConsultThread t) =>
      client.from('consult_threads').insert({'id': t.id, 'parent_id': t.parentId, 'doctor_id': t.doctorId});

  Future<void> insertMessage(String threadId, String text) =>
      client.from('consult_messages').insert({'thread_id': threadId, 'sender_id': userId, 'body': text});

  Future<void> insertNote(ConsultNote n) => client.from('consult_notes').insert({
        'id': n.id,
        'thread_id': n.threadId,
        'child_id': n.childId,
        'doctor_id': n.doctorId,
        'title': n.title,
        'keterangan': n.keterangan,
        'diagnosis': n.diagnosis,
        'anjuran': n.anjuran,
        'catatan': n.catatan,
      });

  Future<void> insertAppointment(Appointment a) => client.from('appointments').insert({
        'id': a.id,
        'child_id': a.childId,
        'doctor_id': a.doctorId,
        'scheduled_at': a.date.toUtc().toIso8601String(),
      });

  Future<void> verifyHealthWorker(String userId) => client.from('profiles').update({'verified': true}).eq('id', userId);

  Future<void> insertScore({required String name, required int points, required int correct, required int total}) =>
      client.from('quiz_scores').insert({'user_id': userId, 'display_name': name, 'points': points, 'correct': correct, 'total': total});

  Future<void> insertBadges(Set<String> badges) => client.from('user_badges').upsert(
        [for (final b in badges) {'user_id': userId, 'badge': b}],
        onConflict: 'user_id,badge',
        ignoreDuplicates: true,
      );

  Future<void> setFlag(String table, String column, String id, bool on) => on
      ? client.from(table).insert({'user_id': userId, column: id})
      : client.from(table).delete().eq('user_id', userId!).eq(column, id);
}
