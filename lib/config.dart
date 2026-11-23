import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';

/// PRD F4: build rilis memakai `--dart-define=GROWELL_DEMO=false` agar tombol akun demo,
/// rute login cepat `/demo/…`, kode OTP contoh, dan tombol simulasi tidak tampil.
const demoBuild = bool.fromEnvironment('GROWELL_DEMO', defaultValue: true);

/// Fitur demo tampil pada build demo, dan selalu pada mode lokal (data contoh di memori).
final showDemoProvider = Provider<bool>((ref) => demoBuild || ref.watch(backendProvider) == null);
