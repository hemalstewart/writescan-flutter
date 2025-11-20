import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/bots_state.dart';
import '../../home/state/home_state.dart';
import '../../../app_theme.dart';
import 'package:path/path.dart' as p;

class BotsScreen extends ConsumerWidget {
  const BotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(botsControllerProvider);
    final controller = ref.read(botsControllerProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(Theme.of(context).colorScheme),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AI Bots',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    Flexible(
                      child: OverflowBar(
                        spacing: 12,
                        overflowSpacing: 8,
                        alignment: MainAxisAlignment.end,
                        children: [
                          FilledButton.icon(
                            onPressed: state.isImporting
                                ? null
                                : () async {
                                    final picked = await FilePicker.platform
                                        .pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: [
                                            'pdf',
                                            'txt',
                                            'doc',
                                            'docx',
                                            'csv',
                                            'jpeg',
                                            'jpg',
                                            'png',
                                          ],
                                        );
                                    if (picked != null &&
                                        picked.files.single.path != null) {
                                      final path = picked.files.single.path!;
                                      final name = _friendlyName(path);
                                      try {
                                        await controller.importFromPath(
                                          path,
                                          name: name,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Created bot from $name',
                                              ),
                                            ),
                                          );
                                        }
                                        // refresh documents so the new upload appears on Home
                                        try {
                                          await ref
                                              .read(
                                                homeControllerProvider.notifier,
                                              )
                                              .refresh();
                                        } catch (_) {}
                                      } catch (e) {
                                        final message = e is BotsException
                                            ? e.message
                                            : 'Failed to import bot';
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(content: Text(message)),
                                          );
                                        }
                                      }
                                    }
                                  },
                            icon: state.isImporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.upload_rounded),
                            label: Text(
                              state.isImporting ? 'Uploading...' : 'Upload',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              GoRouter.of(context).push('/bots/create');
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('From documents'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.7,
                              ),
                          itemCount: state.bots.length,
                          itemBuilder: (context, index) {
                            final bot = state.bots[index];
                            return GestureDetector(
                              onTap: () {
                                GoRouter.of(context).push(
                                  '/botChat',
                                  extra: {
                                    'id': bot.id,
                                    'name': bot.name,
                                    'source': bot.source,
                                    'tags': bot.tags,
                                  },
                                );
                              },
                              child: _BotCard(
                                bot: bot,
                                colors: colors,
                                onDelete: () =>
                                    _confirmDeleteBot(context, controller, bot),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteBot(
    BuildContext context,
    BotsController controller,
    Bot bot,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete bot?'),
        content: Text('"${bot.name}" and its chat history will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.deleteBot(bot.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${bot.name} deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _BotCard extends StatelessWidget {
  const _BotCard({
    required this.bot,
    required this.colors,
    required this.onDelete,
  });

  final Bot bot;
  final ColorScheme colors;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.panelColor(colors),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.panelBorder(colors)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.primary.withValues(alpha: 0.16),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete bot')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bot.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bot.source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          if (bot.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: bot.tags
                  .map(
                    (tag) => Chip(
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -2,
                      ),
                      backgroundColor: colors.onSurface.withValues(alpha: 0.04),
                      labelStyle: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.7),
                      ),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      label: Text(tag, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

String _friendlyName(String path) {
  final base = p.basename(path);
  if (base.isEmpty) return 'Untitled';
  return base;
}
