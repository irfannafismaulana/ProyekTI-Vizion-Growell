import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'state/backend.dart';
import 'state/providers.dart';

/// Diisi lewat `--dart-define-from-file=supabase_local.json`. Kosong → mode lokal (data di memori).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseBackend? backend;
  if (_supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
    backend = SupabaseBackend(Supabase.instance.client, url: _supabaseUrl);
  }
  final container = ProviderContainer(overrides: [if (backend != null) backendProvider.overrideWithValue(backend)]);
  // Sesi tersimpan di browser → langsung masuk dan muat data dari database.
  await container.read(sessionProvider.notifier).restore();
  runApp(UncontrolledProviderScope(container: container, child: const GroWellApp()));
}
