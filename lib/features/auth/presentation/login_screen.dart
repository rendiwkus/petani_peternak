import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../data/auth_repository.dart';

/// Layar masuk: OTP nomor HP (utama) dan email/password (mitra kios/testing).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.repository});

  final AuthRepository? repository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginMode { phone, email }

class _LoginScreenState extends State<LoginScreen> {
  late final AuthRepository _repository =
      widget.repository ?? AuthRepository();

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _LoginMode _mode = _LoginMode.phone;
  bool _otpSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({bool resend = false}) async {
    FocusScope.of(context).unfocus();
    final phoneError = AppFormatters.validatePhone(_phoneController.text);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _repository.requestPhoneOtp(_phoneController.text);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _secondsLeft = 60;
      });
      _startCountdown();
      if (resend) {
        _showMessage('Kode masuk baru sudah dikirim.');
      }
    } catch (error) {
      _showError(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    final error = AppFormatters.validateOtp(_otpController.text);
    if (error != null) {
      _showError(error);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _repository.verifyPhoneOtp(
        rawPhone: _phoneController.text,
        otpCode: _otpController.text,
      );
      // AuthGate mendengarkan perubahan sesi Supabase dan membuka beranda.
    } catch (error) {
      _showError(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginEmail() async {
    FocusScope.of(context).unfocus();
    final emailError = AppFormatters.validateEmail(_emailController.text);
    if (emailError != null) {
      _showError(emailError);
      return;
    }
    if (_passwordController.text.length < 6) {
      _showError('Password minimal 6 karakter');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _repository.loginWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (error) {
      _showError(SupabaseService.friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.dangerRed,
          content: Text(message),
        ),
      );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      _buildBrandHeader(),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _mode == _LoginMode.phone
                                ? _buildPhoneFlow()
                                : _buildEmailFlow(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _mode = _mode == _LoginMode.phone
                                      ? _LoginMode.email
                                      : _LoginMode.phone;
                                  _otpSent = false;
                                  _timer?.cancel();
                                });
                              },
                        icon: Icon(
                          _mode == _LoginMode.phone
                              ? Icons.email_rounded
                              : Icons.phone_android_rounded,
                          size: 22,
                        ),
                        label: Text(
                          _mode == _LoginMode.phone
                              ? 'Masuk dengan Email (Mitra Kios / Testing)'
                              : 'Kembali ke Nomor HP',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Data Anda dilindungi. Kode OTP hanya berlaku sekali dan '
                        'tidak pernah kami minta lewat telepon.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppTheme.surfaceTintGreen,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.cardBorder, width: 1.5),
          ),
          child: const Icon(
            Icons.agriculture_rounded,
            size: 48,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Masuk ke Aplikasi TaniTernak',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Masukkan nomor HP atau WhatsApp Anda untuk menerima kode masuk',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneFlow() {
    if (_otpSent) return _buildOtpStep();
    return Column(
      key: const ValueKey('phone-step-1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nomor HP / WhatsApp',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
            LengthLimitingTextInputFormatter(18),
          ],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          decoration: const InputDecoration(
            hintText: '812 3456 7890',
            prefixText: '+62  ',
            prefixStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        BigActionButton(
          label: 'Kirim Kode Masuk (OTP)',
          icon: Icons.sms_rounded,
          isLoading: _isLoading,
          onPressed: _sendOtp,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('phone-step-2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Ganti nomor HP',
              onPressed: _isLoading
                  ? null
                  : () {
                      _timer?.cancel();
                      setState(() {
                        _otpSent = false;
                        _otpController.clear();
                      });
                    },
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Kode dikirim ke ${AppFormatters.displayPhone(_phoneController.text)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Masukkan 6 angka kode masuk',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          decoration: const InputDecoration(hintText: '••••••'),
        ),
        const SizedBox(height: 16),
        BigActionButton(
          label: 'Verifikasi & Masuk',
          icon: Icons.check_circle_rounded,
          isLoading: _isLoading,
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isLoading || _secondsLeft > 0
              ? null
              : () => _sendOtp(resend: true),
          child: Text(
            _secondsLeft > 0
                ? 'Kirim Ulang Kode ($_secondsLeft detik)'
                : 'Kirim Ulang Kode',
          ),
        ),
      ],
    );
  }

  Widget _buildEmailFlow() {
    return Column(
      key: const ValueKey('email-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Email Mitra Kios / Testing',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'nama@email.com',
            prefixIcon: Icon(Icons.email_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _loginEmail(),
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(Icons.lock_rounded),
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Tampilkan password' : 'Sembunyikan',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        BigActionButton(
          label: 'Masuk dengan Email',
          icon: Icons.login_rounded,
          isLoading: _isLoading,
          onPressed: _loginEmail,
        ),
        const SizedBox(height: 8),
        const Text(
          'Khusus akun mitra kios yang terdaftar dan pengujian internal.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
