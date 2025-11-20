import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../auth/auth_controller.dart';
import '../../home/state/home_state.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final quickActions = [
      _QuickAction(
        icon: Icons.document_scanner_rounded,
        title: 'Normal scan',
        subtitle: 'Capture documents and save as PDF.',
        color: colors.primary,
        onTap: () => _openScanner(context, DocumentKind.normal),
      ),
      _QuickAction(
        icon: Icons.text_snippet_rounded,
        title: 'Extract text',
        subtitle: 'Turn any page into editable text.',
        color: Colors.purpleAccent,
        onTap: () => _openScanner(context, DocumentKind.ocr),
      ),
    ];
    final settings = [
      _SettingItem(
        icon: Icons.privacy_tip_rounded,
        title: 'Privacy Policy',
        subtitle: 'View how we handle your data.',
        color: Colors.lightBlueAccent,
        onTap: () => _openExternal(
          context,
          brightness == Brightness.dark
              ? AppConfig.privacyPolicyDark
              : AppConfig.privacyPolicyLight,
        ),
      ),
      _SettingItem(
        icon: Icons.description_rounded,
        title: 'Terms & Conditions',
        subtitle: 'Read the legal bits.',
        color: Colors.purpleAccent,
        onTap: () => _openExternal(
          context,
          brightness == Brightness.dark
              ? AppConfig.termsDark
              : AppConfig.termsLight,
        ),
      ),
      _SettingItem(
        icon: Icons.apps_rounded,
        title: 'More apps',
        subtitle: 'Discover more tools from AppMixer.',
        color: Colors.orangeAccent,
        onTap: () => _openExternal(context, AppConfig.moreAppsUrl),
      ),
      _SettingItem(
        icon: Icons.ios_share_rounded,
        title: 'Share WriteScan',
        subtitle: 'Invite friends to try the app.',
        color: Colors.greenAccent,
        onTap: () => _shareApp(context),
      ),
      _SettingItem(
        icon: Icons.cancel_schedule_send_rounded,
        title: 'Unsubscribe',
        subtitle: 'Deactivate the service anytime.',
        color: Colors.redAccent,
        onTap: () => _confirmUnsubscribe(context, ref),
      ),
    ];

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
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More features',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...quickActions.map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _QuickActionCard(action: action),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...settings.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SettingTile(item: item),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _openScanner(BuildContext context, DocumentKind kind) {
    GoRouter.of(context).push('/scan', extra: kind);
  }

  static Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  static Future<void> _shareApp(BuildContext context) async {
    try {
      await Share.share(
        'Check out Write Scan: ${AppConfig.playStoreLink}',
        subject: 'Write Scan',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to share: $e')));
      }
    }
  }

  static Future<void> _confirmUnsubscribe(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = ref.read(authControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsubscribe from WriteScan?'),
        content: const Text('You can rejoin anytime by signing up again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await controller.unsubscribe();
      messenger.showSnackBar(
        const SnackBar(content: Text('You have been unsubscribed.')),
      );
      router.go('/auth');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to unsubscribe: $e')),
      );
    }
  }
}

class _QuickAction {
  _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              action.color.withValues(alpha: 0.25),
              action.color.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: action.color.withValues(alpha: 0.2),
              child: Icon(action.icon, color: action.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _SettingItem {
  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.item});
  final _SettingItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: item.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      tileColor: Colors.white.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: CircleAvatar(
        backgroundColor: item.color.withValues(alpha: 0.2),
        child: Icon(item.icon, color: item.color),
      ),
      title: Text(
        item.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
    );
  }
}
