import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state/providers.dart';
import 'common.dart';

/// Verifikasi STR tenaga kesehatan oleh admin (Gambar E1, ER-6.5).
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)!;
    final health = ref.watch(usersProvider).where((u) => u.role == Role.health).toList();
    final pending = health.where((u) => !u.verified).toList();
    final done = health.where((u) => u.verified).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi STR tenaga kesehatan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SectionTitle('Menunggu verifikasi (${pending.length})'),
        if (pending.isEmpty) const Text('Tidak ada pengajuan baru.'),
        for (final u in pending)
          Card(
            child: ListTile(
              leading: const Icon(Icons.hourglass_top, color: Colors.orange),
              title: Text(u.name),
              subtitle: Text('${u.title ?? 'Tenaga kesehatan'} • STR ${u.strNumber}\nDokumen: dokumen_STR.pdf (simulasi)'),
              isThreeLine: true,
              trailing: FilledButton(
                onPressed: () {
                  try {
                    ref.read(usersProvider.notifier).verifyHealthWorker(actor: me, userId: u.id);
                    showInfo(context, '${u.name} terverifikasi.');
                  } catch (e) {
                    showError(context, e);
                  }
                },
                child: const Text('Verifikasi'),
              ),
            ),
          ),
        SectionTitle('Terverifikasi (${done.length})'),
        for (final u in done)
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified, color: brandBlue),
              title: Text(u.name),
              subtitle: Text('${u.title} • STR ${u.strNumber}'),
            ),
          ),
        const SizedBox(height: 8),
        const Text('Prototype: pemeriksaan keaslian STR dilakukan manual oleh admin.', style: TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    );
  }
}
