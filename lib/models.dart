import 'core/zscore.dart';

/// Peran pengguna sesuai SRS v3.2 (Batasan "Hak akses per peran").
enum Role { parent, teen, health, admin }

extension RoleLabel on Role {
  String get label => switch (this) {
        Role.parent => 'Orang tua',
        Role.teen => 'Remaja',
        Role.health => 'Tenaga kesehatan',
        Role.admin => 'Admin',
      };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.strNumber,
    this.verified = false,
    this.title,
    this.specialty,
    this.experienceYears,
    this.workplace,
  });

  final String id;
  final String name;
  final String email;

  /// Prototype lokal: disimpan polos di memori. Versi Supabase memakai hash (ER-6.5).
  final String password;
  final Role role;

  /// Nomor STR tenaga kesehatan; akun aktif setelah diverifikasi admin.
  final String? strNumber;
  final bool verified;
  final String? title;
  final String? specialty;
  final int? experienceYears;
  final String? workplace;

  bool get isVerifiedHealth => role == Role.health && verified;

  AppUser copyWith({bool? verified, String? password, String? name}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email,
        password: password ?? this.password,
        role: role,
        strNumber: strNumber,
        verified: verified ?? this.verified,
        title: title,
        specialty: specialty,
        experienceYears: experienceYears,
        workplace: workplace,
      );
}

class Child {
  const Child({
    required this.id,
    required this.parentId,
    required this.name,
    required this.sex,
    required this.birthDate,
    required this.posyandu,
    required this.region,
  });

  final String id;
  final String parentId;
  final String name;
  final Sex sex;
  final DateTime birthDate;
  final String posyandu;
  final String region;

  int ageDaysAt(DateTime d) => ageInDays(birthDate, d);
  int get ageDays => ageDaysAt(DateTime.now());
  double get ageMonths => ageDays / 30.4375;
}

class Measurement {
  const Measurement({
    required this.id,
    required this.childId,
    required this.date,
    required this.weightKg,
    required this.heightCm,
    required this.result,
  });

  final String id;
  final String childId;
  final DateTime date;
  final double weightKg;
  final double heightCm;
  final GrowthResult result;
}

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.group,
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
    required this.fiber,
    this.animalProtein = false,
  });

  final String id;
  final String name;

  /// Kelompok pangan: Karbohidrat, Protein hewani, Protein nabati, Sayur, Buah, Susu & olahan.
  final String group;

  /// Kandungan per 100 g bagian yang dapat dimakan (perkiraan, perlu diverifikasi dengan TKPI).
  final double kcal;
  final double protein;
  final double carb;
  final double fat;
  final double fiber;
  final bool animalProtein;

  bool get highProtein => protein >= 10;
}

enum Meal { pagi, siang, malam, selingan }

extension MealLabel on Meal {
  String get label => switch (this) {
        Meal.pagi => 'Pagi',
        Meal.siang => 'Siang',
        Meal.malam => 'Malam',
        Meal.selingan => 'Selingan',
      };
}

class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.childId,
    required this.date,
    required this.meal,
    required this.foodId,
    required this.grams,
  });

  final String id;
  final String childId;
  final DateTime date;
  final Meal meal;
  final String foodId;
  final double grams;
}

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.audience,
    required this.minutes,
    this.isReel = false,
  });

  final String id;
  final String title;
  final String summary;
  final String body;

  /// Peran yang menjadi sasaran konten (personalisasi ER-3.1).
  final Set<Role> audience;
  final int minutes;
  final bool isReel;
}

class Message {
  const Message({required this.senderId, required this.text, required this.time});
  final String senderId;
  final String text;
  final DateTime time;
}

class ConsultThread {
  const ConsultThread({
    required this.id,
    required this.parentId,
    required this.doctorId,
    required this.messages,
  });

  final String id;
  final String parentId;
  final String doctorId;
  final List<Message> messages;

  ConsultThread withMessage(Message m) =>
      ConsultThread(id: id, parentId: parentId, doctorId: doctorId, messages: [...messages, m]);
}

enum Difficulty { mudah, sedang, sulit }

/// Kategori soal/room kuis (ER-7.2). Tenaga kesehatan tidak bermain.
enum QuizCategory { umum, remaja, orangTua, campuran }

extension QuizCategoryLabel on QuizCategory {
  String get label => switch (this) {
        QuizCategory.umum => 'Umum',
        QuizCategory.remaja => 'Remaja',
        QuizCategory.orangTua => 'Orang tua',
        QuizCategory.campuran => 'Campuran',
      };
}

class Question {
  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.difficulty,
    required this.category,
  });

  final String id;
  final String text;
  final List<String> options;
  final int answer;
  final String explanation;
  final Difficulty difficulty;
  final QuizCategory category;
}

/// Ringkasan hasil konsultasi yang ditulis tenaga kesehatan (layar "Detail Konsultasi").
class ConsultNote {
  const ConsultNote({
    required this.id,
    required this.threadId,
    required this.parentId,
    required this.doctorId,
    required this.childId,
    required this.title,
    required this.date,
    required this.keterangan,
    required this.diagnosis,
    required this.anjuran,
    required this.catatan,
  });

  final String id;
  final String threadId;
  final String parentId;
  final String doctorId;
  final String childId;
  final String title;
  final DateTime date;
  final String keterangan;
  final String diagnosis;
  final String anjuran;
  final String catatan;
}

/// Jadwal kontrol dari tenaga kesehatan; ditampilkan sebagai peringatan di Beranda (ER-1.4).
class Appointment {
  const Appointment({required this.id, required this.childId, required this.doctorId, required this.date});
  final String id;
  final String childId;
  final String doctorId;
  final DateTime date;
}

/// Resep MPASI/makanan anak. Nilai gizi dihitung dari bahan per porsi
/// memakai tabel pangan, bukan diketik manual.
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.minutes,
    required this.servings,
    required this.difficulty,
    required this.minMonths,
    required this.maxMonths,
    required this.ingredients,
    required this.seasonings,
    required this.steps,
    required this.texture,
    required this.vitamins,
    this.image,
  });

  final String id;
  final String name;
  final String description;
  final int minutes;
  final int servings;
  final String difficulty;

  /// Rentang usia anak (bulan) yang sesuai tekstur resep.
  final int minMonths;
  final int maxMonths;

  /// Bahan utama per porsi: (id pangan, gram).
  final List<(String, double)> ingredients;

  /// Bumbu/bahan pelengkap yang kandungan gizinya diabaikan.
  final List<String> seasonings;
  final List<String> steps;
  final String texture;
  final String vitamins;
  final String? image;
}

/// Video pendek edukasi (Reels). Prototype belum memutar video sungguhan.
class Reel {
  const Reel({
    required this.id,
    required this.author,
    required this.title,
    required this.caption,
    required this.headline,
    required this.subline,
    required this.seconds,
    required this.likes,
    required this.comments,
    required this.audience,
    required this.colors,
    this.image,
    this.articleId,
  });

  final String id;
  final String author;
  final String title;
  final String caption;
  final String headline;
  final String subline;
  final int seconds;
  final int likes;
  final int comments;
  final Set<Role> audience;
  final List<int> colors;
  final String? image;

  /// Artikel lanjutan untuk tombol "Selengkapnya".
  final String? articleId;
}
