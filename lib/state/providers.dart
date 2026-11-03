import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../core/zscore.dart';
import '../data/seed.dart';
import '../models.dart';
import 'backend.dart';

export 'backend.dart' show backendProvider, syncErrorProvider, demoEmails;

/// Dua mode data:
/// - lokal (tanpa konfigurasi Supabase, dipakai uji otomatis): data contoh di memori;
/// - database: notifier mulai kosong, diisi `SupabaseBackend.loadAll` setelah login,
///   dan setiap perubahan ditulis ke Supabase lewat [syncToBackend].

final _rng = math.Random();
int _seq = 0;
String newId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rng.nextInt(1 << 30).toRadixString(36)}${_seq++}';

class AccessDenied implements Exception {
  AccessDenied(this.message);
  final String message;
  @override
  String toString() => message;
}

bool _remote(Ref ref) => ref.read(backendProvider) != null;

// ---------------------------------------------------------------- Users & sesi
class UsersNotifier extends Notifier<List<AppUser>> {
  @override
  List<AppUser> build() => _remote(ref) ? [] : [...seedUsers];

  void replaceAll(List<AppUser> users) => state = users;

  AppUser? byEmail(String email) {
    final e = email.trim().toLowerCase();
    for (final u in state) {
      if (u.email.toLowerCase() == e) return u;
    }
    return null;
  }

  AppUser byId(String id) => state.firstWhere((u) => u.id == id);

  /// Registrasi mode lokal (submodul 1). Tenaga kesehatan wajib STR dan menunggu verifikasi admin.
  AppUser register({
    required String name,
    required String email,
    required String password,
    required Role role,
    String? strNumber,
    String? title,
  }) {
    if (byEmail(email) != null) throw ArgumentError('Email sudah terdaftar. Gunakan email lain atau masuk.');
    _checkRegistration(role, strNumber);
    final u = AppUser(
      id: newId('u'),
      name: name.trim(),
      email: email.trim(),
      password: password,
      role: role,
      strNumber: strNumber?.trim(),
      verified: false,
      title: title,
      specialty: role == Role.health ? 'Dokter Umum' : null,
    );
    state = [...state, u];
    return u;
  }

  void resetPassword(String email, String newPassword) {
    final u = byEmail(email);
    if (u == null) throw ArgumentError('Email tidak ditemukan.');
    state = [for (final x in state) x.id == u.id ? x.copyWith(password: newPassword) : x];
  }

  /// Hanya admin yang boleh memverifikasi STR (ER-6.5).
  void verifyHealthWorker({required AppUser actor, required String userId}) {
    if (actor.role != Role.admin) throw AccessDenied('Hanya admin yang dapat memverifikasi STR.');
    final before = state;
    state = [for (final x in state) x.id == userId ? x.copyWith(verified: true) : x];
    syncToBackend(ref, (b) => b.verifyHealthWorker(userId), rollback: () => state = before);
  }
}

void _checkRegistration(Role role, String? strNumber) {
  if (role == Role.admin) throw AccessDenied('Akun admin tidak dapat dibuat melalui registrasi.');
  if (role == Role.health && (strNumber == null || strNumber.trim().isEmpty)) {
    throw ArgumentError('Nomor STR wajib diisi untuk tenaga kesehatan.');
  }
}

final usersProvider = NotifierProvider<UsersNotifier, List<AppUser>>(UsersNotifier.new);

const _wrongLogin = 'Email atau password salah. Periksa kembali, atau gunakan "Lupa Password".';

class SessionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  SupabaseBackend? get _b => ref.read(backendProvider);

  /// Mengembalikan pesan kesalahan, atau null bila berhasil.
  Future<String?> login(String email, String password) async {
    final b = _b;
    if (b == null) {
      final u = ref.read(usersProvider.notifier).byEmail(email);
      if (u == null || u.password != password) return _wrongLogin;
      state = u.id;
      return null;
    }
    try {
      await b.signIn(email, password);
      await _enter(b);
      return null;
    } on AuthException catch (e) {
      return e.code == 'invalid_credentials' || e.statusCode == '400' ? _wrongLogin : e.message;
    } catch (e) {
      return describeBackendError(e);
    }
  }

  Future<void> _enter(SupabaseBackend b) async {
    await b.loadAll(ref.read);
    state = b.userId;
    b.subscribe(ref.read);
  }

  /// Lanjutkan sesi tersimpan di browser (mode database) saat aplikasi dibuka ulang.
  Future<void> restore() async {
    final b = _b;
    if (b == null || b.userId == null) return;
    try {
      await _enter(b);
    } catch (_) {
      await b.signOut();
    }
  }

  /// Login cepat akun demo (mode lokal). Mode database memakai [login] dengan demo123.
  void loginAs(String userId) => state = userId;

  Future<void> logout() async {
    final b = _b;
    state = null;
    if (b != null) {
      await b.signOut();
      _resetUserData(ref);
    }
  }

  /// Registrasi: lokal langsung masuk; database lewat Supabase Auth (profil dibuat trigger).
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required Role role,
    String? strNumber,
    String? title,
  }) async {
    final b = _b;
    try {
      if (b == null) {
        final u = ref.read(usersProvider.notifier).register(
            name: name, email: email, password: password, role: role, strNumber: strNumber, title: title);
        state = u.id;
        return null;
      }
      _checkRegistration(role, strNumber);
      final signedIn = await b.signUp(email: email, password: password, data: {
        'name': name.trim(),
        'role': role.name,
        'str_number': ?strNumber?.trim(),
        'title': ?title,
      });
      if (!signedIn) return 'Akun dibuat. Periksa email untuk konfirmasi, lalu masuk.';
      await _enter(b);
      return null;
    } on ArgumentError catch (e) {
      return '${e.message}';
    } on AccessDenied catch (e) {
      return e.message;
    } on AuthException catch (e) {
      return e.code == 'user_already_exists' ? 'Email sudah terdaftar. Gunakan email lain atau masuk.' : e.message;
    } catch (e) {
      return describeBackendError(e);
    }
  }

  // Lupa password: lokal memakai OTP tetap; database mengirim kode OTP ke email (Mailpit di lokal).
  static const demoOtp = '123456';

  Future<String?> requestPasswordReset(String email) async {
    final b = _b;
    if (b == null) {
      return ref.read(usersProvider.notifier).byEmail(email) == null ? 'Email tidak terdaftar. Periksa penulisan email.' : null;
    }
    try {
      await b.requestPasswordReset(email);
      return null;
    } catch (e) {
      return describeBackendError(e);
    }
  }

  Future<String?> verifyResetCode(String email, String code) async {
    final b = _b;
    if (b == null) return code.trim() == demoOtp ? null : 'Kode OTP salah. Periksa email Anda dan masukkan 6 digit kode.';
    try {
      await b.verifyResetCode(email, code);
      return null;
    } on AuthException {
      return 'Kode OTP salah atau kedaluwarsa. Minta kode baru bila perlu.';
    } catch (e) {
      return describeBackendError(e);
    }
  }

  Future<String?> setNewPassword(String email, String password) async {
    final b = _b;
    try {
      if (b == null) {
        ref.read(usersProvider.notifier).resetPassword(email, password);
      } else {
        await b.setNewPassword(password);
      }
      return null;
    } on ArgumentError catch (e) {
      return '${e.message}';
    } catch (e) {
      return describeBackendError(e);
    }
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, String?>(SessionNotifier.new);

final currentUserProvider = Provider<AppUser?>((ref) {
  final id = ref.watch(sessionProvider);
  if (id == null) return null;
  final users = ref.watch(usersProvider);
  for (final u in users) {
    if (u.id == id) return u;
  }
  return null;
});

// ---------------------------------------------------------------- Anak & pengukuran
class ChildrenNotifier extends Notifier<List<Child>> {
  @override
  List<Child> build() {
    if (_remote(ref)) return [];
    final now = DateTime.now();
    return [
      for (final c in seedChildren)
        Child(
          id: c.id,
          parentId: c.parentId,
          name: c.name,
          sex: c.sex,
          birthDate: DateTime(now.year, now.month, now.day).subtract(Duration(days: c.ageDaysToday)),
          posyandu: c.posyandu,
          region: c.region,
        ),
    ];
  }

  void replaceAll(List<Child> children) => state = children;

  Child add({required String parentId, required String name, required Sex sex, required DateTime birthDate, required String posyandu}) {
    final c = Child(
      id: newId('c'),
      parentId: parentId,
      name: name.trim(),
      sex: sex,
      birthDate: birthDate,
      posyandu: posyandu,
      region: regionOfPosyandu[posyandu] ?? '-',
    );
    state = [...state, c];
    syncToBackend(ref, (b) => b.insertChild(c), rollback: () => state = state.where((x) => x.id != c.id).toList());
    return c;
  }

  Child byId(String id) => state.firstWhere((c) => c.id == id);
}

final childrenProvider = NotifierProvider<ChildrenNotifier, List<Child>>(ChildrenNotifier.new);

class MeasurementsNotifier extends Notifier<List<Measurement>> {
  @override
  List<Measurement> build() {
    if (_remote(ref)) return [];
    final children = ref.read(childrenProvider);
    final list = <Measurement>[];
    for (final s in seedChildren) {
      final child = children.firstWhere((c) => c.id == s.id);
      for (final (age, w, h) in s.measurements) {
        final date = child.birthDate.add(Duration(days: age));
        list.add(_make(child, date, w, h));
      }
    }
    return list;
  }

  void replaceAll(List<Measurement> ms) => state = ms;

  Measurement _make(Child child, DateTime date, double w, double h) => Measurement(
        id: newId('m'),
        childId: child.id,
        date: date,
        weightKg: w,
        heightCm: h,
        result: assess(sex: child.sex, birthDate: child.birthDate, measuredAt: date, weightKg: w, heightCm: h),
      );

  /// Validasi input (ER-6.2) lalu hitung z-score (ER-1.1). Pesan kesalahan
  /// menyebut penyebab dan cara memperbaiki (ER-6.1). Database memvalidasi ulang.
  Measurement add({
    required Child child,
    required DateTime date,
    required double weightKg,
    required double heightCm,
    String source = 'manual',
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    if (day.isAfter(DateTime(today.year, today.month, today.day))) {
      throw ArgumentError('Tanggal ukur tidak boleh di masa depan. Pilih tanggal hari ini atau sebelumnya.');
    }
    if (day.isBefore(child.birthDate)) {
      throw ArgumentError('Tanggal ukur sebelum tanggal lahir anak. Periksa kembali tanggalnya.');
    }
    if (weightKg < 1 || weightKg > 30) {
      throw ArgumentError('Berat badan $weightKg kg tidak wajar untuk baduta. Isi dalam kilogram, contoh 8,5.');
    }
    if (heightCm < 40 || heightCm > 120) {
      throw ArgumentError('Panjang/tinggi badan $heightCm cm tidak wajar untuk baduta. Isi dalam sentimeter, contoh 72,5.');
    }
    final m = _make(child, day, weightKg, heightCm); // dapat melempar RangeError (umur > 24 bulan)
    state = [...state, m];
    syncToBackend(ref, (b) => b.insertMeasurement(m, source: source), rollback: () => state = state.where((x) => x.id != m.id).toList());
    return m;
  }
}

final measurementsProvider = NotifierProvider<MeasurementsNotifier, List<Measurement>>(MeasurementsNotifier.new);

/// Riwayat pengukuran satu anak, urut tanggal.
final childMeasurementsProvider = Provider.family<List<Measurement>, String>((ref, childId) {
  final all = ref.watch(measurementsProvider).where((m) => m.childId == childId).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return all;
});

// ---------------------------------------------------------------- Gizi harian
class FoodLogNotifier extends Notifier<List<FoodEntry>> {
  @override
  List<FoodEntry> build() {
    if (_remote(ref)) return [];
    final now = DateTime.now();
    DateTime d(int ago) => DateTime(now.year, now.month, now.day).subtract(Duration(days: ago));
    FoodEntry e(String child, int ago, Meal meal, String food, double g) =>
        FoodEntry(id: newId('f'), childId: child, date: d(ago), meal: meal, foodId: food, grams: g);
    // Variasi porsi agar grafik tren terlihat wajar (data contoh; sama dengan supabase/seed.sql).
    double v(int ago, double base) => base * (0.85 + ((ago * 37) % 30) / 100);
    return [
      // Abiyu (6 bulan): MPASI lumat 2x sehari + selingan, dimulai 2 minggu terakhir.
      for (var ago = 1; ago <= 14; ago++) ...[
        e('c_abiyu', ago, Meal.pagi, 'bubur', v(ago, 80)),
        e('c_abiyu', ago, Meal.pagi, 'telur', v(ago, 15)),
        e('c_abiyu', ago, Meal.siang, 'bubur', v(ago + 3, 80)),
        e('c_abiyu', ago, Meal.siang, ago.isEven ? 'hati' : 'ikan', v(ago, 12)),
        e('c_abiyu', ago, Meal.siang, 'wortel', 10),
        e('c_abiyu', ago, Meal.siang, 'minyak', 2),
        if (ago % 3 != 0) e('c_abiyu', ago, Meal.selingan, 'pisang', v(ago, 30)),
      ],
      e('c_abiyu', 0, Meal.pagi, 'bubur', 80),
      e('c_abiyu', 0, Meal.pagi, 'telur', 15),
      // Alya (9 bulan): 3x makan + selingan selama 2 bulan terakhir.
      for (var ago = 1; ago <= 60; ago++) ...[
        e('c_alya', ago, Meal.pagi, 'bubur', v(ago, 100)),
        e('c_alya', ago, Meal.pagi, 'telur', v(ago, 25)),
        e('c_alya', ago, Meal.siang, 'nasi', v(ago + 5, 50)),
        e('c_alya', ago, Meal.siang, switch (ago % 3) { 0 => 'ayam', 1 => 'ikan', _ => 'tempe' }, v(ago, 20)),
        e('c_alya', ago, Meal.siang, ago.isEven ? 'bayam' : 'brokoli', 20),
        e('c_alya', ago, Meal.malam, 'nasi', v(ago + 9, 50)),
        e('c_alya', ago, Meal.malam, ago.isOdd ? 'hati' : 'tahu', v(ago, 15)),
        e('c_alya', ago, Meal.malam, 'minyak', 3),
        e('c_alya', ago, Meal.selingan, ago.isEven ? 'pepaya' : 'alpukat', v(ago, 40)),
      ],
      e('c_alya', 0, Meal.pagi, 'bubur', 100),
      e('c_alya', 0, Meal.pagi, 'telur', 25),
    ];
  }

  void replaceAll(List<FoodEntry> entries) => state = entries;

  /// Simpan beberapa makanan sekaligus (hasil foto makanan yang sudah dikoreksi).
  void addAll(List<FoodEntry> entries) {
    for (final x in entries) {
      if (x.grams <= 0 || x.grams > 1000) {
        throw ArgumentError('Porsi ${x.grams} g tidak wajar. Isi berat porsi dalam gram, contoh 50.');
      }
    }
    state = [...state, ...entries];
    final ids = {for (final x in entries) x.id};
    syncToBackend(ref, (b) => b.insertFood(entries), rollback: () => state = state.where((x) => !ids.contains(x.id)).toList());
  }

  void add({required String childId, required DateTime date, required Meal meal, required String foodId, required double grams}) =>
      addAll([FoodEntry(id: newId('f'), childId: childId, date: date, meal: meal, foodId: foodId, grams: grams)]);

  void remove(String id) {
    final before = state;
    state = state.where((e) => e.id != id).toList();
    syncToBackend(ref, (b) => b.deleteFood(id), rollback: () => state = before);
  }
}

final foodLogProvider = NotifierProvider<FoodLogNotifier, List<FoodEntry>>(FoodLogNotifier.new);

// ---------------------------------------------------------------- Konsultasi
class ConsultNotifier extends Notifier<List<ConsultThread>> {
  @override
  List<ConsultThread> build() {
    if (_remote(ref)) return [];
    final now = DateTime.now();
    return [
      ConsultThread(id: 't_seed', parentId: 'u_rani', doctorId: 'u_sarah', messages: [
        Message(senderId: 'u_rani', text: 'Dok, panjang badan Abiyu naiknya sedikit sekali dua bulan ini. Apa perlu khawatir?', time: now.subtract(const Duration(days: 8, hours: 3))),
        Message(senderId: 'u_sarah', text: 'Bu, mohon datang ke Puskesmas untuk pengukuran ulang. Sementara itu catat MPASI Abiyu di menu Gizi Harian ya.', time: now.subtract(const Duration(days: 8, hours: 1))),
      ]),
      ConsultThread(id: 't_irfan', parentId: 'u_rani', doctorId: 'u_irfan', messages: [
        Message(senderId: 'u_irfan', text: 'Halo, ada yang bisa saya bantu?', time: now.subtract(const Duration(hours: 20))),
        Message(senderId: 'u_rani', text: 'Halo dok, saya ingin konsultasi.', time: now.subtract(const Duration(hours: 19, minutes: 58))),
        Message(senderId: 'u_irfan', text: 'Silakan, keluhan apa yang ingin disampaikan?', time: now.subtract(const Duration(hours: 19, minutes: 55))),
      ]),
    ];
  }

  void replaceAll(List<ConsultThread> threads) => state = threads;

  ConsultThread openThread({required AppUser parent, required String doctorId}) {
    if (parent.role != Role.parent) throw AccessDenied('Konsultasi hanya tersedia untuk akun orang tua.');
    for (final t in state) {
      if (t.parentId == parent.id && t.doctorId == doctorId) return t;
    }
    final t = ConsultThread(id: newId('t'), parentId: parent.id, doctorId: doctorId, messages: const []);
    state = [...state, t];
    syncToBackend(ref, (b) => b.insertThread(t), rollback: () => state = state.where((x) => x.id != t.id).toList());
    return t;
  }

  /// ER-4.2 / TC-03: hanya orang tua pemilik percakapan yang boleh bertanya, dan
  /// hanya tenaga kesehatan terverifikasi yang ditunjuk yang boleh menjawab.
  /// Aturan yang sama ditegakkan RLS di database.
  void send({required AppUser sender, required String threadId, required String text}) {
    final t = state.firstWhere((x) => x.id == threadId);
    if (text.trim().isEmpty) throw ArgumentError('Pesan masih kosong. Tulis pertanyaan atau jawaban terlebih dahulu.');
    final isAsker = sender.role == Role.parent && sender.id == t.parentId;
    final isAnswerer = sender.isVerifiedHealth && sender.id == t.doctorId;
    if (!isAsker && !isAnswerer) {
      throw AccessDenied('Akses tidak diizinkan: hanya tenaga kesehatan terverifikasi yang dapat memberi jawaban medis.');
    }
    final msg = Message(senderId: sender.id, text: text.trim(), time: DateTime.now());
    state = [for (final x in state) x.id == threadId ? x.withMessage(msg) : x];
    syncToBackend(ref, (b) => b.insertMessage(threadId, msg.text), rollback: () {
      state = [
        for (final x in state)
          x.id == threadId
              ? ConsultThread(id: x.id, parentId: x.parentId, doctorId: x.doctorId, messages: x.messages.where((m) => !identical(m, msg)).toList())
              : x,
      ];
    });
  }
}

final consultProvider = NotifierProvider<ConsultNotifier, List<ConsultThread>>(ConsultNotifier.new);

// ---------------------------------------------------------------- Edukasi
/// Set id yang disimpan/disukai; tersinkron ke tabel [table] pada mode database.
class _FlagSetNotifier extends Notifier<Set<String>> {
  _FlagSetNotifier(this.table, this.column);
  final String table;
  final String column;
  @override
  Set<String> build() => {};
  void replaceAll(Set<String> ids) => state = ids;
  void toggle(String id) {
    final before = state;
    final on = !state.contains(id);
    state = on ? {...state, id} : ({...state}..remove(id));
    syncToBackend(ref, (b) => b.setFlag(table, column, id, on), rollback: () => state = before);
  }
}

class BookmarksNotifier extends _FlagSetNotifier {
  BookmarksNotifier() : super('bookmarks', 'item_id');
}

final bookmarksProvider = NotifierProvider<BookmarksNotifier, Set<String>>(BookmarksNotifier.new);

// ---------------------------------------------------------------- Leaderboard & lencana
class LeaderboardNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => _remote(ref) ? {} : {...seedLeaderboard};

  void replaceAll(Map<String, int> scores) => state = scores;

  /// Poin pemain lain/bot hanya di layar; poin sendiri disimpan ke database.
  void addPoints(String name, int points) => state = {...state, name: (state[name] ?? 0) + points};

  void recordMine({required String name, required int points, required int correct, required int total}) {
    addPoints(name, points);
    syncToBackend(ref, (b) => b.insertScore(name: name, points: points, correct: correct, total: total));
  }
}

final leaderboardProvider = NotifierProvider<LeaderboardNotifier, Map<String, int>>(LeaderboardNotifier.new);

class BadgesNotifier extends Notifier<Map<String, Set<String>>> {
  @override
  Map<String, Set<String>> build() => {};
  int gamesPlayed(String userId) => _games[userId] ?? 0;
  final Map<String, int> _games = {};

  void restore(String userId, Set<String> badges, int games) {
    _games[userId] = games;
    state = {...state, userId: badges};
  }

  void recordGame(String userId, {required int correct, required int total, required double avgSeconds}) {
    _games[userId] = (_games[userId] ?? 0) + 1;
    final b = {...?state[userId]};
    if (total > 0 && correct / total >= 0.8) b.add('Jagoan Gizi');
    if (_games[userId]! >= 3) b.add('Sahabat Posyandu');
    if (correct > 0 && avgSeconds <= 5) b.add('Kilat');
    state = {...state, userId: b};
    if (b.isNotEmpty) syncToBackend(ref, (be) => be.insertBadges(b));
  }
}

final badgesProvider = NotifierProvider<BadgesNotifier, Map<String, Set<String>>>(BadgesNotifier.new);

// ---------------------------------------------------------------- Anak terpilih
/// Anak yang sedang dipilih di Beranda orang tua (chip nama anak).
class SelectedChild extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String id) => state = id;
}

final selectedChildProvider = NotifierProvider<SelectedChild, String?>(SelectedChild.new);

/// Anak aktif milik orang tua yang login (pilihan chip, atau anak pertama).
final activeChildProvider = Provider<Child?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final mine = ref.watch(childrenProvider).where((c) => c.parentId == user.id).toList();
  final sel = ref.watch(selectedChildProvider);
  return mine.where((c) => c.id == sel).firstOrNull ?? mine.firstOrNull;
});

// ---------------------------------------------------------------- Catatan konsultasi & jadwal kontrol
class ConsultNotesNotifier extends Notifier<List<ConsultNote>> {
  @override
  List<ConsultNote> build() {
    if (_remote(ref)) return [];
    final now = DateTime.now();
    return [
      ConsultNote(
        id: 'n_seed',
        threadId: 't_seed',
        parentId: 'u_rani',
        doctorId: 'u_sarah',
        childId: 'c_abiyu',
        title: 'Deteksi Dini Stunting',
        date: DateTime(now.year, now.month, now.day, 13, 42).subtract(const Duration(days: 7)),
        keterangan: 'Deteksi dini stunting (anak 6 bulan). Panjang badan 62,3 cm dan berat badan 6,5 kg. '
            'Panjang badan anak di bawah standar WHO. Diperlukan evaluasi asupan nutrisi, riwayat kesehatan, '
            'dan pola makan untuk intervensi stunting.',
        diagnosis: 'Risiko stunting – panjang badan kurang dari standar usia',
        anjuran: 'Lanjutkan ASI. MPASI 2–3 kali sehari dengan protein hewani setiap makan (telur, ikan, hati ayam) '
            'dan tambahan lemak. Timbang dan ukur rutin setiap bulan.',
        catatan: 'Kontrol ulang dalam 1 bulan. Jika tidak ada peningkatan, rujuk ke spesialis gizi.',
      ),
    ];
  }

  void replaceAll(List<ConsultNote> notes) => state = notes;

  /// Hanya nakes terverifikasi yang menangani percakapan yang boleh menulis catatan (ER-4.2).
  ConsultNote add({
    required AppUser actor,
    required String threadId,
    required String childId,
    required String title,
    required String keterangan,
    required String diagnosis,
    required String anjuran,
    required String catatan,
  }) {
    final t = ref.read(consultProvider).firstWhere((x) => x.id == threadId);
    if (!actor.isVerifiedHealth || actor.id != t.doctorId) {
      throw AccessDenied('Hanya tenaga kesehatan terverifikasi yang menangani konsultasi ini yang dapat menulis catatan.');
    }
    if (title.trim().isEmpty || diagnosis.trim().isEmpty) {
      throw ArgumentError('Judul dan diagnosis wajib diisi.');
    }
    final n = ConsultNote(
      id: newId('n'),
      threadId: threadId,
      parentId: t.parentId,
      doctorId: actor.id,
      childId: childId,
      title: title.trim(),
      date: DateTime.now(),
      keterangan: keterangan.trim(),
      diagnosis: diagnosis.trim(),
      anjuran: anjuran.trim(),
      catatan: catatan.trim(),
    );
    state = [...state, n];
    syncToBackend(ref, (b) => b.insertNote(n), rollback: () => state = state.where((x) => x.id != n.id).toList());
    return n;
  }
}

final consultNotesProvider = NotifierProvider<ConsultNotesNotifier, List<ConsultNote>>(ConsultNotesNotifier.new);

class AppointmentsNotifier extends Notifier<List<Appointment>> {
  @override
  List<Appointment> build() {
    if (_remote(ref)) return [];
    final now = DateTime.now();
    return [
      Appointment(
        id: 'ap_seed',
        childId: 'c_abiyu',
        doctorId: 'u_sarah',
        date: DateTime(now.year, now.month, now.day, 9).add(const Duration(days: 5)),
      ),
    ];
  }

  void replaceAll(List<Appointment> list) => state = list;

  Appointment schedule({required AppUser actor, required String childId, required DateTime date}) {
    if (!actor.isVerifiedHealth) throw AccessDenied('Hanya tenaga kesehatan terverifikasi yang dapat menjadwalkan kontrol.');
    final today = DateTime.now();
    if (date.isBefore(DateTime(today.year, today.month, today.day))) {
      throw ArgumentError('Tanggal kontrol tidak boleh di masa lalu.');
    }
    final a = Appointment(id: newId('ap'), childId: childId, doctorId: actor.id, date: date);
    state = [...state, a];
    syncToBackend(ref, (b) => b.insertAppointment(a), rollback: () => state = state.where((x) => x.id != a.id).toList());
    return a;
  }
}

final appointmentsProvider = NotifierProvider<AppointmentsNotifier, List<Appointment>>(AppointmentsNotifier.new);

/// Jadwal kontrol terdekat yang belum lewat untuk seorang anak.
final nextAppointmentProvider = Provider.family<Appointment?, String>((ref, childId) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final list = ref.watch(appointmentsProvider).where((a) => a.childId == childId && !a.date.isBefore(today)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return list.firstOrNull;
});

// ---------------------------------------------------------------- Reels
class LikesNotifier extends _FlagSetNotifier {
  LikesNotifier() : super('reel_likes', 'reel_id');
}

final likesProvider = NotifierProvider<LikesNotifier, Set<String>>(LikesNotifier.new);

/// Data milik pengguna yang dikosongkan saat keluar (mode database).
void _resetUserData(Ref ref) {
  ref
    ..invalidate(usersProvider)
    ..invalidate(childrenProvider)
    ..invalidate(measurementsProvider)
    ..invalidate(foodLogProvider)
    ..invalidate(consultProvider)
    ..invalidate(consultNotesProvider)
    ..invalidate(appointmentsProvider)
    ..invalidate(leaderboardProvider)
    ..invalidate(badgesProvider)
    ..invalidate(bookmarksProvider)
    ..invalidate(likesProvider)
    ..invalidate(selectedChildProvider);
}
