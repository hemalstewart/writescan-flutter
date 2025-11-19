import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final items = _moreItems;

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
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: Colors.white.withValues(alpha: 0.04),
                leading: CircleAvatar(
                  backgroundColor: item.color.withValues(alpha: 0.2),
                  child: Icon(item.icon, color: item.color),
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  item.subtitle,
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  if (item.title == 'Unsubscribe') {
                    ref.read(authControllerProvider.notifier).unsubscribe();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.title} coming soon')),
                    );
                  }
                },
              );
            },
            separatorBuilder: (context, _) => const SizedBox(height: 12),
            itemCount: items.length,
          ),
        ),
      ),
    );
  }
}

class _MoreItem {
  _MoreItem(this.icon, this.title, this.subtitle, this.color);
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

final _moreItems = <_MoreItem>[
  _MoreItem(
    Icons.rocket_launch_rounded,
    'Upgrade to Premium',
    'Unlimited AI chats, OCR and edits',
    Colors.amber,
  ),
  _MoreItem(
    Icons.privacy_tip_rounded,
    'Privacy Policy',
    'View how we handle your data',
    Colors.lightBlueAccent,
  ),
  _MoreItem(
    Icons.description_rounded,
    'Terms & Conditions',
    'All the important legal bits',
    Colors.purpleAccent,
  ),
  _MoreItem(
    Icons.cancel_schedule_send_rounded,
    'Unsubscribe',
    'Deactivate the service anytime',
    Colors.redAccent,
  ),
  _MoreItem(
    Icons.feedback_rounded,
    'Feedback',
    'Tell us how we are doing',
    Colors.greenAccent,
  ),
];
