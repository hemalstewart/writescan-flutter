import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local_storage.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_state.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  static final _slides = [
    _OnboardingSlide(
      title: 'Smart OCR scan',
      description:
          'Capture crisp documents, enhance the pages, and convert them to searchable PDFs or text.',
      icon: Icons.document_scanner_rounded,
    ),
    _OnboardingSlide(
      title: 'Handwriting capture',
      description:
          'Point the camera at handwritten notes and let WriteScan turn them into editable text.',
      icon: Icons.draw_rounded,
    ),
    _OnboardingSlide(
      title: 'Organize everything',
      description:
          'Store scans in folders, create custom bots and chat about your documents anywhere.',
      icon: Icons.folder_special_rounded,
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  Future<void> _finish() async {
    final storage = LocalStorage();
    await storage.setOnboardingSeen();
    if (!mounted) return;
    final stage = ref.read(authControllerProvider).stage;
    if (stage == AuthStage.loggedIn) {
      context.go('/home');
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0F25), Color(0xFF1B1740)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (value) =>
                        setState(() => _index = value.clamp(0, _slides.length - 1)),
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return _SlideCard(slide: slide, color: colors.primary);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 10,
                      width: i == _index ? 36 : 10,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? colors.primary
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (_isLast) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    child: Text(_isLast ? 'Get started' : 'Next'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide, required this.color});

  final _OnboardingSlide slide;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: color.withValues(alpha: 0.25),
          child: Icon(slide.icon, size: 56, color: color),
        ),
        const SizedBox(height: 32),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          slide.description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
        ),
      ],
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
