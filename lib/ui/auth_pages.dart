import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/seed.dart';
import '../models.dart';
import '../state/providers.dart';
import 'common.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Kerangka layar autentikasi (desain "Register"): logo di atas, panel biru membulat di bawah.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.fromLTRB(32, 48, 32, 28), child: AppLogo(height: 190)),
            Container(
              constraints: BoxConstraints(minHeight: (box.maxHeight - 266).clamp(0, double.infinity)),
              decoration: const BoxDecoration(
                color: brandBlue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 22),
                ...children,
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
      );
}

InputDecoration _panelInput(String hint, {Widget? suffix}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8A8F98)),
      filled: true,
      fillColor: Colors.white,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffix,
      errorStyle: const TextStyle(color: Color(0xFFFFE4E6), fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 2)),
    );

class _PanelField extends StatefulWidget {
  const _PanelField({required this.controller, required this.hint, this.password = false, this.validator, this.keyboard});
  final TextEditingController controller;
  final String hint;
  final bool password;
  final String? Function(String?)? validator;
  final TextInputType? keyboard;
  @override
  State<_PanelField> createState() => _PanelFieldState();
}

class _PanelFieldState extends State<_PanelField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: widget.password && _hidden,
        validator: widget.validator,
        keyboardType: widget.keyboard,
        style: const TextStyle(fontSize: 16),
        decoration: _panelInput(
          widget.hint,
          suffix: widget.password
              ? IconButton(
                  tooltip: _hidden ? 'Tampilkan password' : 'Sembunyikan password',
                  icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black87),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
      );
}

/// Tombol putih pada panel biru ("Daftar", "Masuk").
class _PanelButton extends StatelessWidget {
  const _PanelButton(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: SizedBox(
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFFAFA),
              foregroundColor: Colors.black,
              elevation: 3,
              shadowColor: Colors.black38,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            onPressed: onPressed,
            child: Text(label),
          ),
        ),
      );
}

class _SwitchLink extends StatelessWidget {
  const _SwitchLink(this.question, this.action, this.onTap);
  final String question;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$question ', style: const TextStyle(color: Colors.white, fontSize: 15)),
          InkWell(
            onTap: onTap,
            child: Text(action, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(color: Color(0xFF9F1239))),
      );
}

// ---------------------------------------------------------------- Login
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    final err = await ref.read(sessionProvider.notifier).login(_email.text, _pass.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  void _demo(String email) {
    _email.text = email;
    _pass.text = demoPassword;
    _login();
  }

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label, String email) => ActionChip(
          avatar: Icon(icon, size: 18, color: brandBlue),
          label: Text(label),
          labelStyle: const TextStyle(color: brandBlue, fontWeight: FontWeight.w600),
          backgroundColor: Colors.white,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          onPressed: () => _demo(email),
        );
    return _AuthScaffold(title: 'Masuk Ke Growell', children: [
      const _Label('Email'),
      _PanelField(controller: _email, hint: 'Masukkan Email', keyboard: TextInputType.emailAddress),
      const _Label('Password'),
      _PanelField(controller: _pass, hint: 'Masukkan Password', password: true),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => context.push('/forgot'),
          child: const Text('Lupa Password?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
      if (_error != null) _ErrorText(_error!),
      _PanelButton(_busy ? 'Memuat data...' : 'Masuk', _busy ? () {} : _login),
      _SwitchLink('Belum Punya Akun?', 'Daftar', () => context.push('/register')),
      const SizedBox(height: 26),
      const Text('Akun demo (prototype – data contoh):', style: TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip(Icons.family_restroom, 'Orang tua', 'rani@demo.id'),
        chip(Icons.school, 'Remaja', 'dina@demo.id'),
        chip(Icons.medical_services, 'Tenaga kesehatan', 'sarah@demo.id'),
        chip(Icons.hourglass_top, 'Nakes belum terverifikasi', 'candra@demo.id'),
        chip(Icons.admin_panel_settings, 'Admin', 'admin@demo.id'),
      ]),
      const SizedBox(height: 8),
      Text(
        ref.watch(backendProvider) == null
            ? 'Semua akun demo memakai password: demo123 • Mode lokal (data di memori)'
            : 'Semua akun demo memakai password: demo123 • Terhubung ke database ${ref.watch(backendProvider)!.url}',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Registrasi
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _str = TextEditingController();
  Role _role = Role.parent;
  String _profession = 'Dokter umum';
  bool _strUploaded = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_role == Role.health && !_strUploaded) {
      showError(context, ArgumentError('Unggah dokumen STR terlebih dahulu.'));
      return;
    }
    final err = await ref.read(sessionProvider.notifier).register(
          name: '${_first.text.trim()} ${_last.text.trim()}'.trim(),
          email: _email.text,
          password: _pass.text,
          role: _role,
          strNumber: _role == Role.health ? _str.text : null,
          title: _role == Role.health ? _profession : null,
        );
    if (err != null && mounted) showError(context, ArgumentError(err));
  }

  @override
  Widget build(BuildContext context) {
    String? req(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;
    Widget roleChip(Role r, String label) {
      final sel = _role == r;
      return Material(
        color: sel ? Colors.white : Colors.white.withValues(alpha: 0.12),
        shape: const StadiumBorder(side: BorderSide(color: Colors.white)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => setState(() => _role = r),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(label, style: TextStyle(color: sel ? brandBlue : Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    return Form(
      key: _form,
      child: _AuthScaffold(title: 'Daftar Ke Growell', children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Nama Depan'),
              _PanelField(controller: _first, hint: 'Masukkan Nama', validator: req),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Nama Belakang'),
              _PanelField(controller: _last, hint: 'Masukkan Nama'),
            ]),
          ),
        ]),
        const _Label('Daftar Sebagai'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          roleChip(Role.parent, 'Orang Tua'),
          roleChip(Role.teen, 'Remaja'),
          roleChip(Role.health, 'Tenaga Kesehatan'),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            switch (_role) {
              Role.parent => 'Semua fitur: pemantauan anak, gizi harian, edukasi, konsultasi, dan kuis.',
              Role.teen => 'Edukasi (Reels & artikel) dan kuis kesehatan.',
              _ => 'Dashboard monitoring & konsultasi, aktif setelah STR diverifikasi admin.',
            },
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ),
        const _Label('Email'),
        _PanelField(
          controller: _email,
          hint: 'Masukkan Email',
          keyboard: TextInputType.emailAddress,
          validator: (v) => _emailRe.hasMatch(v?.trim() ?? '') ? null : 'Format email tidak valid, contoh: nama@email.com',
        ),
        if (_role == Role.health) ...[
          const _Label('Profesi'),
          DropdownButtonFormField<String>(
          isExpanded: true,
            initialValue: _profession,
            decoration: _panelInput(''),
            items: const ['Dokter umum', 'Dokter spesialis anak', 'Ahli gizi (dietisien)', 'Bidan', 'Perawat']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _profession = v!),
          ),
          const _Label('Nomor STR'),
          _PanelField(controller: _str, hint: 'Masukkan Nomor STR', validator: req),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: Icon(_strUploaded ? Icons.check_circle : Icons.upload_file),
            label: Text(_strUploaded ? 'dokumen_STR.pdf (simulasi)' : 'Unggah Dokumen STR'),
            onPressed: () => setState(() => _strUploaded = true),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Prototype: unggahan disimulasikan. Akun aktif setelah admin memverifikasi STR.',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
        const _Label('Password'),
        _PanelField(
          controller: _pass,
          hint: 'Masukkan Password',
          password: true,
          validator: (v) => (v ?? '').length < 8 ? 'Minimal 8 karakter' : null,
        ),
        const _Label('Konfirmasi Password'),
        _PanelField(
          controller: _pass2,
          hint: 'Masukkan Ulang Password',
          password: true,
          validator: (v) => v != _pass.text ? 'Konfirmasi tidak sama dengan password' : null,
        ),
        _PanelButton('Daftar', _submit),
        _SwitchLink('Sudah Punya Akun?', 'Masuk', () => context.go('/login')),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Lupa password
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  int _step = 0;
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String? _error;

  Future<void> _next() async {
    setState(() => _error = null);
    final session = ref.read(sessionProvider.notifier);
    final remote = ref.read(backendProvider) != null;
    switch (_step) {
      case 0:
        final err = await session.requestPasswordReset(_email.text);
        if (!mounted) return;
        if (err != null) return setState(() => _error = err);
        showInfo(
          context,
          remote
              ? 'Kode OTP dikirim ke email. Database lokal: buka Mailpit http://127.0.0.1:54324'
              : 'Kode OTP terkirim ke email (mode lokal: ${SessionNotifier.demoOtp})',
        );
        setState(() => _step = 1);
      case 1:
        final err = await session.verifyResetCode(_email.text, _otp.text);
        if (!mounted) return;
        if (err != null) return setState(() => _error = err);
        setState(() => _step = 2);
      default:
        if (_pass.text.length < 8) {
          setState(() => _error = 'Password baru minimal 8 karakter.');
          return;
        }
        if (_pass.text != _pass2.text) {
          setState(() => _error = 'Konfirmasi tidak sama dengan password baru.');
          return;
        }
        final err = await session.setNewPassword(_email.text, _pass.text);
        if (!mounted) return;
        if (err != null) return setState(() => _error = err);
        showInfo(context, 'Password berhasil diperbarui. Silakan masuk.');
        context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(title: _step == 1 ? 'Verifikasi Kode' : 'Reset Password', children: [
      Text(
        switch (_step) {
          0 => 'Masukkan email untuk menerima kode verifikasi (OTP).',
          1 => 'Masukkan 6 digit kode verifikasi yang dikirim ke ${_email.text}.',
          _ => 'Masukkan password baru dan konfirmasinya.',
        },
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      if (_step == 0) ...[const _Label('Email'), _PanelField(controller: _email, hint: 'Masukkan Email')],
      if (_step == 1) ...[const _Label('Kode OTP'), _PanelField(controller: _otp, hint: '6 digit kode', keyboard: TextInputType.number)],
      if (_step == 2) ...[
        const _Label('Password Baru'),
        _PanelField(controller: _pass, hint: 'Masukkan Password', password: true),
        const _Label('Konfirmasi Password'),
        _PanelField(controller: _pass2, hint: 'Masukkan Ulang Password', password: true),
      ],
      if (_error != null) _ErrorText(_error!),
      _PanelButton(_step == 2 ? 'Simpan' : 'Kirim', _next),
      _SwitchLink('Ingat password?', 'Masuk', () => context.go('/login')),
    ]);
  }
}

// ---------------------------------------------------------------- Menunggu verifikasi STR
class PendingVerificationPage extends ConsumerWidget {
  const PendingVerificationPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFEFF5FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GwCard(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(children: [
              const AppLogo(height: 130),
              const SizedBox(height: 18),
              const Text('Menunggu verifikasi STR',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textDark), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Akun ${u?.name ?? ''} (STR ${u?.strNumber ?? '-'}) sedang diverifikasi admin. '
                'Dashboard monitoring dan layanan konsultasi aktif setelah verifikasi selesai.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: textGray, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 8),
              const Text('Demo: keluar lalu masuk sebagai Admin untuk memverifikasi akun ini.',
                  textAlign: TextAlign.center, style: TextStyle(color: textGray, fontSize: 12)),
              const SizedBox(height: 22),
              PrimaryButton('Keluar', onPressed: () => ref.read(sessionProvider.notifier).logout()),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Login cepat untuk demo
/// `/demo/<userId>?next=/rute` — mode lokal langsung masuk; mode database login
/// dengan email akun demo dan password demo123.
class DemoLoginPage extends ConsumerStatefulWidget {
  const DemoLoginPage({super.key, required this.userId, required this.next});
  final String userId;
  final String next;
  @override
  ConsumerState<DemoLoginPage> createState() => _DemoLoginPageState();
}

class _DemoLoginPageState extends ConsumerState<DemoLoginPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    final session = ref.read(sessionProvider.notifier);
    if (ref.read(backendProvider) == null) {
      session.loginAs(widget.userId);
    } else {
      final email = demoEmails[widget.userId] ?? widget.userId;
      final err = await session.login(email, demoPassword);
      if (err != null) {
        if (mounted) setState(() => _error = err);
        return;
      }
    }
    if (mounted) context.go(widget.next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: _error == null
              ? const Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Masuk ke akun demo...'),
                ])
              : Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)),
        ),
      );
}
