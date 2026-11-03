import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models.dart';
import 'state/providers.dart';
import 'ui/admin_pages.dart';
import 'ui/assistant_page.dart';
import 'ui/auth_pages.dart';
import 'ui/common.dart';
import 'ui/consult_pages.dart';
import 'ui/display_frame.dart';
import 'ui/education_pages.dart';
import 'ui/growth_pages.dart';
import 'ui/home_pages.dart';
import 'ui/nutrition_pages.dart';
import 'ui/quiz_pages.dart';

const _public = {'/login', '/register', '/forgot'};

final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Skala tampilan dari URL (?zoom=150); null = otomatis.
final _zoom = zoomFromUrl();

/// Pembatasan akses per peran (Batasan "Hak akses per peran", ER-6.5).
bool _allowed(Role role, String path) {
  if (path.startsWith('/child') || path.startsWith('/recipe') || path.startsWith('/call') ||
      path == '/assistant' || path == '/notifications') {
    return role == Role.parent;
  }
  if (path.startsWith('/quiz')) return role == Role.parent || role == Role.teen;
  if (path.startsWith('/consult/')) return role == Role.parent || role == Role.health;
  if (path.startsWith('/nakes')) return role == Role.health;
  if (path.startsWith('/admin')) return role == Role.admin;
  return true;
}

/// Router dibuat sekali; redirect dievaluasi ulang lewat [GroWellApp] yang
/// memanggil `router.refresh()` setiap kali pengguna aktif berubah.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final path = state.uri.path;
      if (path.startsWith('/demo/')) return null;
      final user = ref.read(currentUserProvider);
      if (user == null) return _public.contains(path) ? null : '/login';
      if (user.role == Role.health && !user.verified) return path == '/pending' ? null : '/pending';
      if (_public.contains(path) || path == '/pending') return '/app';
      if (!_allowed(user.role, path)) return '/app';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(path: '/pending', builder: (_, _) => const PendingVerificationPage()),
      // Login cepat untuk demo: /demo/<userId>?next=/rute
      GoRoute(
        path: '/demo/:userId',
        builder: (_, s) => DemoLoginPage(userId: s.pathParameters['userId']!, next: s.uri.queryParameters['next'] ?? '/app'),
      ),
      GoRoute(
        path: '/app',
        builder: (_, s) => HomeShell(initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0),
      ),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsPage()),
      GoRoute(path: '/assistant', builder: (_, _) => const AssistantPage()),
      GoRoute(path: '/child/new', builder: (_, _) => const AddChildPage()),
      GoRoute(path: '/child/:id', builder: (_, s) => GrowthPage(childId: s.pathParameters['id']!)),
      GoRoute(path: '/child/:id/measure', builder: (_, s) => AddMeasurementPage(childId: s.pathParameters['id']!)),
      GoRoute(path: '/child/:id/food', builder: (_, s) => FoodPhotoPage(childId: s.pathParameters['id']!)),
      GoRoute(path: '/child/:id/nutrition', builder: (_, s) => NutritionPage(childId: s.pathParameters['id']!)),
      GoRoute(path: '/child/:id/recipes', builder: (_, s) => RecipesPage(childId: s.pathParameters['id']!)),
      GoRoute(
        path: '/recipe/:id',
        builder: (_, s) => RecipeDetailPage(recipeId: s.pathParameters['id']!, childId: s.uri.queryParameters['child']),
      ),
      GoRoute(path: '/articles', builder: (_, _) => const EducationPage()),
      GoRoute(path: '/article/:id', builder: (_, s) => ArticlePage(articleId: s.pathParameters['id']!)),
      GoRoute(path: '/consult/note/:id', builder: (_, s) => ConsultNotePage(noteId: s.pathParameters['id']!)),
      GoRoute(path: '/consult/:id', builder: (_, s) => ThreadPage(threadId: s.pathParameters['id']!)),
      GoRoute(
        path: '/call/:doctorId',
        builder: (_, s) => CallPage(doctorId: s.pathParameters['doctorId']!, video: s.uri.queryParameters['video'] == '1'),
      ),
      GoRoute(path: '/quiz', builder: (_, _) => const QuizHome()),
      GoRoute(path: '/quiz/create', builder: (_, _) => const CreateRoomPage()),
      GoRoute(path: '/quiz/join', builder: (_, _) => const JoinRoomPage()),
      GoRoute(path: '/quiz/room', builder: (_, _) => const QuizRoomPage()),
      GoRoute(path: '/quiz/leaderboard', builder: (_, _) => const LeaderboardPage()),
      GoRoute(path: '/nakes/child/:id', builder: (_, s) => GrowthPage(childId: s.pathParameters['id']!, readOnly: true)),
      GoRoute(path: '/nakes/note/:threadId', builder: (_, s) => NakesNotePage(threadId: s.pathParameters['threadId']!)),
      GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
    ],
  );
});

class GroWellApp extends ConsumerWidget {
  const GroWellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = ColorScheme.fromSeed(seedColor: brandBlue, primary: brandBlue, surface: Colors.white);
    final router = ref.watch(routerProvider);
    // Login/logout/verifikasi mengubah pengguna aktif → evaluasi ulang redirect.
    ref.listen(currentUserProvider, (_, _) => router.refresh());
    // Penulisan ke database gagal (mis. ditolak RLS) → tampilkan pesan.
    ref.listen(syncErrorProvider, (_, msg) {
      if (msg == null) return;
      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)));
    });
    return MaterialApp.router(
      scaffoldMessengerKey: messengerKey,
      title: 'GroWell',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        // App bar biru dengan judul putih seperti desain Figma.
        appBarTheme: const AppBarTheme(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          iconTheme: IconThemeData(color: Colors.white, size: 28),
          actionsIconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFF0F2F5))),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
        chipTheme: const ChipThemeData(shape: StadiumBorder()),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
      ),
      // Prototype web: tampilkan seukuran layar HP agar sesuai desain mobile.
      // Bingkai HP; di layar besar vertikal (mis. 1200×1920) UI diperbesar memenuhi layar.
      builder: (context, child) => DisplayFrame(zoom: _zoom, child: child!),
    );
  }
}
