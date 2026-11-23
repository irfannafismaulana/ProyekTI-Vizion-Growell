import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Konfigurasi Firebase dari `--dart-define-from-file=firebase_config.json` (PRD F8).
/// Kosong = push notification nonaktif; aplikasi tetap berjalan normal.
class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const webAppId = String.fromEnvironment('FIREBASE_APP_ID_WEB');
  static const androidAppId = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  static String get appId => kIsWeb ? webAppId : androidAppId;
  static bool get configured => apiKey.isNotEmpty && projectId.isNotEmpty && senderId.isNotEmpty && appId.isNotEmpty;
}

/// Pesan push yang diterima saat aplikasi terbuka.
typedef PushHandler = void Function(String title, String body, String? route);

/// Daftarkan perangkat ke FCM dan simpan tokennya di tabel `push_tokens`.
class PushService {
  PushService._();
  static final instance = PushService._();

  bool _initialized = false;
  String? _token;
  StreamSubscription<RemoteMessage>? _onMessage;
  StreamSubscription<String>? _onRefresh;

  /// Dipanggil setelah login (mode database). Tidak melempar galat: push bersifat opsional.
  Future<void> register(SupabaseClient client, {required PushHandler onForeground}) async {
    if (!FirebaseConfig.configured) return;
    try {
      if (!_initialized) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: FirebaseConfig.apiKey,
            appId: FirebaseConfig.appId,
            messagingSenderId: FirebaseConfig.senderId,
            projectId: FirebaseConfig.projectId,
          ),
        );
        _initialized = true;
      }
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      // Token registrasi klasik: dikirim lewat FCM HTTP v1 `message.token` (supabase/functions/_shared/fcm.ts).
      // firebase_messaging 17 menyarankan register()/onRegistered (Firebase Installation ID); migrasi
      // menunggu dukungan pengiriman FID di server.
      // ignore: deprecated_member_use
      final token = await fm.getToken(vapidKey: kIsWeb && FirebaseConfig.vapidKey.isNotEmpty ? FirebaseConfig.vapidKey : null);
      if (token == null) return;
      await _save(client, token);
      await _onRefresh?.cancel();
      // ignore: deprecated_member_use
      _onRefresh = fm.onTokenRefresh.listen((t) => _save(client, t));
      await _onMessage?.cancel();
      _onMessage = FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        onForeground(n?.title ?? 'GroWell', n?.body ?? '', m.data['route'] as String?);
      });
    } catch (e) {
      debugPrint('Push notification nonaktif: $e');
    }
  }

  Future<void> _save(SupabaseClient client, String token) async {
    _token = token;
    final platform = kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
    await client.rpc('register_push_token', params: {'p_token': token, 'p_platform': platform});
  }

  /// Dipanggil sebelum logout agar perangkat ini tidak menerima notifikasi akun tersebut.
  Future<void> unregister(SupabaseClient client) async {
    final t = _token;
    _token = null;
    await _onMessage?.cancel();
    await _onRefresh?.cancel();
    if (t == null) return;
    try {
      await client.rpc('unregister_push_token', params: {'p_token': t});
    } catch (_) {}
  }
}
