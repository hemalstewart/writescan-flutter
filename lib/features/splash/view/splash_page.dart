import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local_storage.dart';
import '../../auth/auth_controller.dart';
import '../../../app_theme.dart';
import '../../auth/auth_state.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 200), _bootstrap);
  }

  Future<void> _bootstrap() async {
    final storage = LocalStorage();
    final auth = ref.read(authControllerProvider.notifier);
    final stopwatch = Stopwatch()..start();
    await auth.initialize();
    final seen = await storage.isOnboardingSeen();
    final minDelay = const Duration(milliseconds: 800);
    final remaining = minDelay - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;
    if (!seen) {
      context.go('/onboarding');
      return;
    }
    final stage = ref.read(authControllerProvider).stage;
    if (stage == AuthStage.loggedIn) {
      context.go('/home');
    } else {
      context.go('/auth');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(Theme.of(context).colorScheme),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/app_icon.png',
                width: 140,
                height: 140,
              ),
              const SizedBox(height: 18),
              const Text(
                'WriteScan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading your workspace…',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
