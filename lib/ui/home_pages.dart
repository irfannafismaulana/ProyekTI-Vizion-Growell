import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/status.dart';
import '../core/zscore.dart';
import '../data/content.dart';
import '../data/seed.dart';
import '../models.dart';
import '../state/providers.dart';
import 'admin_pages.dart';
import 'common.dart';
import 'consult_pages.dart';
import 'education_pages.dart';
import 'growth_pages.dart';
import 'nakes_pages.dart';
import 'quiz_pages.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon, this.page);
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;
}

/// Navigasi bawah sesuai hak akses per peran. Orang tua memakai tombol "+" di tengah (desain Figma).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late int _index = widget.initialTab;

  @override
  void didUpdateWidget(covariant HomeShell old) {
    super.didUpdateWidget(old);
    // context.go('/app?tab=n') dari halaman lain berpindah ke tab yang diminta.
    if (old.initialTab != widget.initialTab) _index = widget.initialTab;
  }

  List<_Tab> _tabs(Role role) => switch (role) {
        Role.parent => const [
            _Tab('Beranda', Icons.home_outlined, Icons.home_rounded, ParentHome()),
            _Tab('Reels', Icons.play_circle_outline, Icons.play_circle, ReelsPage()),
            _Tab('Konsultasi', Icons.medical_services_outlined, Icons.medical_services, ConsultHome()),
            _Tab('Profil', Icons.person_outline, Icons.person, ProfilePage()),
          ],
        Role.teen => const [
            _Tab('Beranda', Icons.home_outlined, Icons.home_rounded, TeenHome()),
            _Tab('Reels', Icons.play_circle_outline, Icons.play_circle, ReelsPage()),
            _Tab('Kuis', Icons.sports_esports_outlined, Icons.sports_esports, QuizHome()),
            _Tab('Profil', Icons.person_outline, Icons.person, ProfilePage()),
          ],
        Role.health => const [
            _Tab('Dashboard', Icons.dashboard_outlined, Icons.dashboard, NakesDashboard()),
            _Tab('Konsultasi', Icons.chat_bubble_outline, Icons.chat_bubble, NakesInbox()),
            _Tab('Profil', Icons.person_outline, Icons.person, ProfilePage()),
          ],
        Role.admin => const [
            _Tab('Verifikasi', Icons.verified_user_outlined, Icons.verified_user, AdminPage(embedded: true)),
            _Tab('Profil', Icons.person_outline, Icons.person, ProfilePage()),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final isParent = user.role == Role.parent;
    // Orang tua tanpa data anak melihat layar "Selamat Datang" terlebih dahulu.
    if (isParent && ref.watch(activeChildProvider) == null) return const WelcomePage();

    final tabs = _tabs(user.role);
    final i = _index.clamp(0, tabs.length - 1);
    Widget item(int k) {
      final t = tabs[k];
      final sel = k == i;
      final c = sel ? brandBlue : const Color(0xFF9CA3AF);
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _index = k),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(sel ? t.activeIcon : t.icon, color: c, size: 28),
            const SizedBox(height: 4),
            Text(t.label, style: TextStyle(color: c, fontSize: 12.5, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageBg,
      body: IndexedStack(index: i, children: [for (final t in tabs) t.page]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: isParent
          ? SizedBox(
              width: 64,
              height: 64,
              child: FloatingActionButton(
                tooltip: 'Pilih aksi',
                backgroundColor: brandBlue,
                foregroundColor: Colors.white,
                elevation: 6,
                shape: const CircleBorder(),
                onPressed: () => showActionSheet(context, ref),
                child: const Icon(Icons.add, size: 36),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(children: [
          if (isParent) ...[item(0), item(1), const SizedBox(width: 76), item(2), item(3)] else for (var k = 0; k < tabs.length; k++) item(k),
        ]),
      ),
    );
  }
}

/// Lembar "Pilih Aksi" dari tombol + (desain "catat").
void showActionSheet(BuildContext context, WidgetRef ref) {
  final child = ref.read(activeChildProvider);
  if (child == null) return;
  Widget option(BuildContext c, IconData icon, Color fg, Color bg, String title, String sub, VoidCallback onTap) => GwCard(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        onTap: () {
          Navigator.pop(c);
          onTap();
        },
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: fg, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: textDark)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: textGray, fontSize: 14)),
            ]),
          ),
        ]),
      );
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(width: 48, height: 5, decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(3))),
          ),
          const SizedBox(height: 22),
          const Text('Pilih Aksi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: textDark)),
          const SizedBox(height: 16),
          option(c, Icons.photo_camera_outlined, brandBlue, const Color(0xFFDBEAFE), 'Catat Gizi Harian', 'Upload foto makanan ${child.name}',
              () => context.push('/child/${child.id}/food')),
          option(c, Icons.photo_camera_outlined, const Color(0xFF9333EA), const Color(0xFFF3E8FF), 'Catat Pertumbuhan Anak',
              'Foto anak untuk pengukuran AI (simulasi)', () => showChildPhotoDialog(context, child)),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.edit_note),
              label: const Text('Isi hasil timbang & ukur secara manual'),
              onPressed: () {
                Navigator.pop(c);
                context.push('/child/${child.id}/measure');
              },
            ),
          ),
        ]),
      ),
    ),
  );
}

// ---------------------------------------------------------------- Selamat datang (belum ada anak)
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEEF5FF), Colors.white]),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(28, 34, 28, 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(children: [
                const AppLogo(height: 135),
                const SizedBox(height: 18),
                const Text('Selamat Datang!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: textDark)),
                const SizedBox(height: 14),
                const Text(
                  'Untuk mulai menggunakan aplikasi, silakan tambahkan data anak Anda terlebih dahulu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF4B5563), height: 1.5),
                ),
                const SizedBox(height: 28),
                PrimaryButton('Tambah Data Anak', onPressed: () => context.push('/child/new')),
              ]),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: const Text('Keluar')),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Beranda orang tua
class ParentHome extends ConsumerWidget {
  const ParentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final children = ref.watch(childrenProvider).where((c) => c.parentId == user.id).toList();
    final child = ref.watch(activeChildProvider);
    if (child == null) return const SizedBox.shrink();
    final appt = ref.watch(nextAppointmentProvider(child.id));
    final notifCount = ref.watch(notificationsProvider).length;

    return ListView(padding: EdgeInsets.zero, children: [
      // Header gradasi biru
      Container(
        decoration: const BoxDecoration(gradient: headerGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
        padding: const EdgeInsets.fromLTRB(22, 24, 20, 28),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.child_care, color: brandBlue, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Halo, ${child.name}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
              Text(fmtAgeMonths(child.ageDays), style: const TextStyle(color: Colors.white, fontSize: 16)),
            ]),
          ),
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push('/notifications'),
              child: SizedBox(
                width: 54,
                height: 54,
                child: Badge(
                  isLabelVisible: notifCount > 0,
                  label: Text('$notifCount'),
                  alignment: const Alignment(0.6, -0.6),
                  child: const Center(child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: 30)),
                ),
              ),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 42,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final c in children) ...[
                _ChildChip(child: c, selected: c.id == child.id, onTap: () => ref.read(selectedChildProvider.notifier).select(c.id)),
                const SizedBox(width: 10),
              ],
              _Pill(
                color: brandGreen,
                onTap: () => context.push('/child/new'),
                child: const Row(children: [
                  Icon(Icons.add, color: Colors.white, size: 22),
                  SizedBox(width: 6),
                  Text('Tambah Anak', style: TextStyle(color: Colors.white, fontSize: 16)),
                ]),
              ),
            ]),
          ),
          if (appt != null) ...[const SizedBox(height: 16), AppointmentBanner(appointment: appt)],
          const SectionTitle('Status Tumbuh Kembang Anak'),
          StatusCard(child: child),
          const SizedBox(height: 10),
          GrowthSummaryCard(child: child),
          const SectionTitle('Layanan Kesehatan'),
          _ServiceTile(Icons.forum_rounded, 'Asisten Ahli Gizi', 'AI pendamping gizi anak (simulasi)', () => context.push('/assistant')),
          _ServiceTile(Icons.insights_rounded, 'Laporan Gizi Harian', 'Tren kalori, protein, karbo, lemak & serat',
              () => context.push('/child/${child.id}/nutrition')),
          _ServiceTile(Icons.restaurant_menu_rounded, 'Rekomendasi Makanan', 'Menu MPASI sesuai usia ${child.name}',
              () => context.push('/child/${child.id}/recipes')),
          _ServiceTile(Icons.show_chart_rounded, 'Grafik Pertumbuhan WHO', 'TB/U, BB/U, BB/TB dan z-score',
              () => context.push('/child/${child.id}')),
          _ServiceTile(Icons.sports_esports_rounded, 'Kuis Kesehatan', 'Main bareng, kumpulkan poin', () => context.push('/quiz')),
          _ServiceTile(Icons.menu_book_rounded, 'Artikel Edukasi', 'Bacaan singkat seputar gizi & stunting', () => context.push('/articles')),
        ]),
      ),
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.color, required this.onTap, this.border});
  final Widget child;
  final Color color;
  final VoidCallback onTap;
  final Color? border;
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: border == null ? BorderSide.none : BorderSide(color: border!, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Center(child: child)),
        ),
      );
}

class _ChildChip extends StatelessWidget {
  const _ChildChip({required this.child, required this.selected, required this.onTap});
  final Child child;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _Pill(
        color: selected ? brandBlue : Colors.white,
        border: selected ? null : brandBlue,
        onTap: onTap,
        child: Row(children: [
          if (selected) ...[const Icon(Icons.check, color: Colors.white, size: 20), const SizedBox(width: 6)],
          Text(child.name, style: TextStyle(color: selected ? Colors.white : brandBlue, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Banner kuning jadwal kontrol (ER-1.4 pengingat).
class AppointmentBanner extends ConsumerWidget {
  const AppointmentBanner({super.key, required this.appointment});
  final Appointment appointment;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final days = DateTime(appointment.date.year, appointment.date.month, appointment.date.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final when = days == 0 ? 'hari ini' : days == 1 ? 'besok' : 'dalam $days hari';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: warnBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: warnBorder, width: 1.5)),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Peringatan: ', style: TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: 'Dokter menjadwalkan kontrol pada ${fmtDmy(appointment.date)} ($when)'),
            ]),
            style: const TextStyle(fontSize: 15.5, color: Colors.black, height: 1.35),
          ),
        ),
      ]),
    );
  }
}

/// Kartu status warna (desain: "Status Perkembangan Anak : MERAH (Kurang)").
class StatusCard extends ConsumerWidget {
  const StatusCard({super.key, required this.child});
  final Child child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(childMeasurementsProvider(child.id)).lastOrNull;
    if (child.ageDays > maxAgeDays) {
      return const NoticeCard(
        icon: Icons.info_outline,
        title: 'Di luar cakupan pemantauan',
        text: 'Usia anak di atas 24 bulan. GroWell memantau baduta usia 0–24 bulan.',
      );
    }
    if (last == null) {
      return _ColoredStatus(
        color: const Color(0xFF64748B),
        icon: Icons.straighten,
        title: 'Belum ada data pertumbuhan',
        text: 'Catat berat dan panjang badan ${child.name} untuk melihat status tumbuh kembangnya.',
        button: 'Catat Pertumbuhan',
        onPressed: () => showChildPhotoDialog(context, child),
      );
    }
    final info = statusOf(last.result);
    final s = info.status;
    final text = switch (s) {
      GrowthStatus.kurang => '${_cap(info.reasons.first)}. Gizi anak kurang, kunjungi Puskesmas SEGERA!',
      GrowthStatus.lebih => '${_cap(info.reasons.first)}. Konsultasikan pola makan dengan tenaga kesehatan.',
      GrowthStatus.waspada => '${_cap(info.reasons.first)}. Perbaiki asupan dan ukur ulang bulan depan.',
      GrowthStatus.normal => 'Pertumbuhan sesuai standar WHO. Pertahankan pola makan dan timbang rutin setiap bulan.',
    };
    return _ColoredStatus(
      color: statusColor(s),
      icon: s == GrowthStatus.normal ? Icons.check_circle_outline : Icons.warning_amber_rounded,
      title: 'Status Perkembangan Anak :\n${s.colorName} (${s.label})',
      text: text,
      button: 'Rekomendasi Makanan',
      onPressed: () => context.push('/child/${child.id}/recipes'),
      onTap: () => context.push('/child/${child.id}'),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _ColoredStatus extends StatelessWidget {
  const _ColoredStatus({
    required this.color,
    required this.icon,
    required this.title,
    required this.text,
    required this.button,
    required this.onPressed,
    this.onTap,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String text;
  final String button;
  final VoidCallback onPressed;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final dark = color == brandYellow;
    final fg = dark ? const Color(0xFF3B2F00) : Colors.white;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: color == brandYellow ? const Color(0xFFD97706) : color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w800, height: 1.35)),
                const SizedBox(height: 8),
                Text(text, style: TextStyle(color: fg.withValues(alpha: 0.95), fontSize: 14.5, height: 1.35)),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color == brandYellow ? const Color(0xFFB45309) : color,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  onPressed: onPressed,
                  child: Text(button),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GwCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: const Color(0xFF1D4ED8), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: textDark)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: textGray, fontSize: 13.5)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: textGray),
        ]),
      );
}

// ---------------------------------------------------------------- Notifikasi (pengingat)
class AppNotification {
  const AppNotification(this.icon, this.title, this.text, this.route);
  final IconData icon;
  final String title;
  final String text;
  final String? route;
}

/// Pengingat jadwal kontrol dan jadwal timbang bulanan (ER-1.4, versi dalam aplikasi).
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.role != Role.parent) return const [];
  final users = ref.watch(usersProvider);
  final kids = ref.watch(childrenProvider).where((c) => c.parentId == user.id);
  final now = DateTime.now();
  final list = <AppNotification>[];
  for (final c in kids) {
    final a = ref.watch(nextAppointmentProvider(c.id));
    if (a != null) {
      final doc = users.where((u) => u.id == a.doctorId).firstOrNull;
      list.add(AppNotification(Icons.event_available, 'Jadwal kontrol ${c.name}',
          '${fmtDmy(a.date)} pukul ${fmtTime(a.date)} dengan ${doc?.name ?? 'dokter'}.', '/consult/${_threadOf(ref, user.id, a.doctorId) ?? ''}'));
    }
    final last = ref.watch(childMeasurementsProvider(c.id)).lastOrNull;
    if (c.ageDays <= maxAgeDays && (last == null || now.difference(last.date).inDays >= 30)) {
      list.add(AppNotification(Icons.monitor_weight_outlined, 'Waktunya menimbang ${c.name}',
          last == null ? 'Belum ada data pertumbuhan. Timbang & ukur di posyandu.' : 'Pengukuran terakhir ${fmtDate(last.date)}. Timbang & ukur bulan ini di ${c.posyandu}.',
          '/child/${c.id}/measure'));
    }
  }
  return list;
});

String? _threadOf(Ref ref, String parentId, String doctorId) =>
    ref.watch(consultProvider).where((t) => t.parentId == parentId && t.doctorId == doctorId).firstOrNull?.id;

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Notifikasi')),
      body: list.isEmpty
          ? const EmptyState(icon: Icons.notifications_none, text: 'Belum ada pengingat.')
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final n in list)
                GwCard(
                  onTap: n.route == null || n.route!.endsWith('/') ? null : () => context.push(n.route!),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: const Color(0xFFDBEAFE), child: Icon(n.icon, color: brandBlue)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700, color: textDark)),
                        const SizedBox(height: 2),
                        Text(n.text, style: const TextStyle(color: textGray)),
                      ]),
                    ),
                  ]),
                ),
              const SizedBox(height: 8),
              const Text('Prototype: pengingat tampil di dalam aplikasi. Notifikasi push (FCM) menyusul pada tahap Supabase.',
                  style: TextStyle(fontSize: 12, color: textGray)),
            ]),
    );
  }
}

// ---------------------------------------------------------------- Beranda remaja
class TeenHome extends ConsumerWidget {
  const TeenHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final lb = ref.watch(leaderboardProvider);
    final rank = (lb.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).indexWhere((e) => e.key == user.name);
    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        decoration: const BoxDecoration(gradient: headerGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
        child: Row(children: [
          const CircleAvatar(radius: 32, backgroundColor: Colors.white, child: Icon(Icons.school_rounded, color: brandBlue, size: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Halo, ${user.name.split(' ').first} 👋', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
              const Text('Remaja • Edukasi & Kuis', style: TextStyle(color: Colors.white, fontSize: 15)),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const TipsBox(
            title: 'Tahukah kamu?',
            items: ['Gizi remaja putri hari ini ikut menentukan kesehatan bayinya kelak. Mencegah stunting bisa dimulai sejak remaja.'],
          ),
          const SizedBox(height: 10),
          GwCard(
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.emoji_events, color: Color(0xFFD97706), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kuis kesehatan multiplayer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(rank >= 0 ? 'Peringkat mingguanmu: #${rank + 1}' : 'Main kuis bareng teman dan kumpulkan poin',
                      style: const TextStyle(color: textGray)),
                ]),
              ),
              FilledButton(onPressed: () => context.push('/quiz/create'), child: const Text('Main')),
            ]),
          ),
          const SectionTitle('Artikel untuk remaja'),
          for (final a in articles.where((a) => a.audience.contains(Role.teen))) ArticleTile(article: a),
        ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Tambah data anak
class AddChildPage extends ConsumerStatefulWidget {
  const AddChildPage({super.key});
  @override
  ConsumerState<AddChildPage> createState() => _AddChildPageState();
}

class _AddChildPageState extends ConsumerState<AddChildPage> {
  final _name = TextEditingController();
  Sex? _sex;
  DateTime? _birth;
  String _posyandu = posyanduList.first;

  void _save() {
    final user = ref.read(currentUserProvider)!;
    if (_name.text.trim().isEmpty) return showError(context, ArgumentError('Nama anak wajib diisi.'));
    if (_birth == null) return showError(context, ArgumentError('Pilih tanggal lahir anak.'));
    if (_sex == null) return showError(context, ArgumentError('Pilih jenis kelamin anak.'));
    final days = ageInDays(_birth!, DateTime.now());
    if (days > maxAgeDays) {
      return showError(context, ArgumentError('GroWell memantau baduta 0–24 bulan. Anak ini berusia ${fmtAge(days)}.'));
    }
    final c = ref.read(childrenProvider.notifier).add(parentId: user.id, name: _name.text, sex: _sex!, birthDate: _birth!, posyandu: _posyandu);
    ref.read(selectedChildProvider.notifier).select(c.id);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app');
    }
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: brandBlue, width: 2)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    Widget label(String t) =>
        Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Text(t, style: const TextStyle(color: Color(0xFF374151), fontSize: 15)));
    Widget sexBtn(Sex s, String t) {
      final sel = _sex == s;
      return Expanded(
        child: SizedBox(
          height: 52,
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: sel ? brandBlue : Colors.white,
              foregroundColor: sel ? Colors.white : textDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: sel ? brandBlue : const Color(0xFFD1D5DB)),
              ),
              textStyle: const TextStyle(fontSize: 16),
            ),
            onPressed: () => setState(() => _sex = s),
            child: Text(t),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(title: const Text('Tambah Data Anak')),
      body: ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 32), children: [
        label('Nama Anak'),
        TextField(controller: _name, decoration: _dec('Isi nama anak')),
        label('Tanggal Lahir Anak'),
        TextField(
          readOnly: true,
          controller: TextEditingController(text: _birth == null ? '' : fmtDmy(_birth!)),
          decoration: _dec('dd/mm/yyyy', suffix: const Icon(Icons.calendar_today_outlined)),
          onTap: () async {
            final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 3), lastDate: now, initialDate: _birth ?? now);
            if (d != null) setState(() => _birth = d);
          },
        ),
        label('Jenis Kelamin'),
        Row(children: [sexBtn(Sex.female, 'Perempuan'), const SizedBox(width: 12), sexBtn(Sex.male, 'Laki-laki')]),
        label('Posyandu'),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _posyandu,
          decoration: _dec(''),
          items: [for (final p in posyanduList) DropdownMenuItem(value: p, child: Text('$p (${regionOfPosyandu[p]})'))],
          onChanged: (v) => setState(() => _posyandu = v!),
        ),
        const SizedBox(height: 8),
        const Text('Cakupan pemantauan: baduta usia 0–24 bulan.', style: TextStyle(fontSize: 12.5, color: textGray)),
        const SizedBox(height: 28),
        PrimaryButton('Simpan Anak', onPressed: _save),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Profil
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(currentUserProvider)!;
    final badges = ref.watch(badgesProvider)[u.id] ?? const <String>{};
    final kids = ref.watch(childrenProvider).where((c) => c.parentId == u.id).toList();
    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        decoration: const BoxDecoration(gradient: headerGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
        child: Column(children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Text(u.name.characters.first, style: const TextStyle(fontSize: 34, color: brandBlue, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Text(u.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
          Text('${u.role.label} • ${u.email}', style: const TextStyle(color: Colors.white70)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (u.role == Role.health)
            GwCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(u.verified ? Icons.verified : Icons.hourglass_top, color: u.verified ? brandBlue : Colors.orange),
                title: Text(u.title ?? 'Tenaga kesehatan'),
                subtitle: Text('STR ${u.strNumber ?? '-'} • ${u.verified ? 'terverifikasi' : 'menunggu verifikasi'}'),
              ),
            ),
          if (u.role == Role.parent) ...[
            SectionTitle('Data Anak',
                trailing: TextButton.icon(onPressed: () => context.push('/child/new'), icon: const Icon(Icons.add), label: const Text('Tambah'))),
            for (final c in kids) _KidTile(child: c),
          ],
          if (badges.isNotEmpty) ...[
            const SectionTitle('Lencana'),
            Wrap(spacing: 8, children: [for (final b in badges) Chip(avatar: const Icon(Icons.military_tech, size: 18), label: Text(b))]),
          ],
          const SectionTitle('Tentang prototype'),
          const GwCard(
            child: Text(
              'GroWell v0.2 – tampilan mengikuti desain Figma. Mode lokal: data disimpan di memori dan kembali ke data contoh '
              'saat halaman dimuat ulang. Z-score memakai tabel resmi WHO Child Growth Standards (dasar Permenkes 2/2020). '
              'Fitur foto AI, panggilan suara/video, dan asisten gizi masih simulasi. $draftNotice Nama pengguna dan anak fiktif.',
              style: TextStyle(height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          SecondaryButton('Keluar', icon: Icons.logout, outlined: true, onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Anda yakin ingin keluar?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Tidak')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ya')),
                ],
              ),
            );
            if (ok == true) ref.read(sessionProvider.notifier).logout();
          }),
        ]),
      ),
    ]);
  }
}

class _KidTile extends ConsumerWidget {
  const _KidTile({required this.child});
  final Child child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(childMeasurementsProvider(child.id)).lastOrNull;
    return GwCard(
      onTap: () => context.push('/child/${child.id}'),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFDBEAFE),
          child: Icon(child.sex == Sex.female ? Icons.face_3 : Icons.face, color: brandBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(child.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('${fmtAge(child.ageDays)} • ${child.posyandu}', style: const TextStyle(color: textGray, fontSize: 13)),
          ]),
        ),
        if (last != null && child.ageDays <= maxAgeDays) StatusPill(statusOf(last.result).status),
      ]),
    );
  }
}
