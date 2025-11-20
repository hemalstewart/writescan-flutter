import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app_theme.dart';
import '../auth_controller.dart';
import '../auth_state.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  bool _autoSentPhone = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    if (state.stage == AuthStage.enterPhone &&
        _mobileController.text.trim().length < 10) {
      _autoSentPhone = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.message != null && state.message!.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.message!),
              behavior: SnackBarBehavior.floating,
            ),
          );
        controller.clearMessage();
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.backgroundGradient(
                Theme.of(context).colorScheme,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'WriteScan',
                      style: GoogleFonts.manrope(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in with your mobile number',
                      style: GoogleFonts.manrope(
                        color: colors.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: state.stage == AuthStage.enterPhone
                          ? _PhoneCard(
                              colors: colors,
                              controller: _mobileController,
                              onSend: (value) =>
                                  controller.sendOtp(value.trim()),
                              onChanged: (value) {
                                final trimmed = value.trim();
                                if (trimmed.length >= 10 && !_autoSentPhone) {
                                  _autoSentPhone = true;
                                  controller.sendOtp(trimmed);
                                } else if (trimmed.length < 10) {
                                  _autoSentPhone = false;
                                }
                              },
                            )
                          : _OtpCard(
                              colors: colors,
                              mobile: state.mobile,
                              otpController: _otpController,
                              onSubmit: (code) =>
                                  controller.verifyOtp(code.trim()),
                              onResend: controller.resendOtp,
                              onEditNumber: controller.editNumber,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (state.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({
    required this.colors,
    required this.controller,
    required this.onSend,
    this.onChanged,
  });

  final ColorScheme colors;
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('phone-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Step 1 • Verify your number',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Enter your mobile number',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll send a 6-digit code to confirm it\'s you.',
            style: GoogleFonts.manrope(
              color: colors.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              LengthLimitingTextInputFormatter(10),
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              prefixText: '+94 ',
              hintText: '07XXXXXXXX',
            ),
            style: const TextStyle(color: Colors.white),
            onSubmitted: onSend,
            onChanged: onChanged,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => onSend(controller.text),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_open_rounded, size: 18),
                SizedBox(width: 8),
                Text('Send OTP'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpCard extends StatelessWidget {
  const _OtpCard({
    required this.colors,
    required this.mobile,
    required this.otpController,
    required this.onSubmit,
    required this.onResend,
    required this.onEditNumber,
  });

  final ColorScheme colors;
  final String mobile;
  final TextEditingController otpController;
  final ValueChanged<String> onSubmit;
  final VoidCallback onResend;
  final VoidCallback onEditNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('otp-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.secondary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Step 2 • Enter OTP',
              style: TextStyle(
                color: colors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'We sent a 6-digit code',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '+94 ${mobile.replaceFirst('07', '7')}',
                style: GoogleFonts.manrope(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              TextButton(onPressed: onEditNumber, child: const Text('edit')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '6-digit code',
              counterText: '',
            ),
            style: const TextStyle(color: Colors.white, letterSpacing: 4),
            onSubmitted: onSubmit,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => onSubmit(otpController.text),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 18),
                SizedBox(width: 8),
                Text('Confirm'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onResend,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Resend code'),
          ),
        ],
      ),
    );
  }
}
