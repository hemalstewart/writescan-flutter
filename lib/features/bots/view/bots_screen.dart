import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/bots_state.dart';
import '../../home/state/home_state.dart';
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0F25), Color(0xFF1B1740)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI Bots',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: state.isImporting
                          ? null
                          : () async {
                              final picked =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: [
                                  'pdf',
                                  'txt',
                                  'doc',
                                  'docx',
                                  'csv',
                                  'jpeg',
                                  'jpg',
                                  'png'
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Created bot from $name'),
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
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                      label: Text(state.isImporting ? 'Uploading...' : 'Upload'),
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
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () {
                              final bot = state.bots[index];
                              GoRouter.of(context).push('/botChat', extra: {
                                'id': bot.id,
                                'name': bot.name,
                                'source': bot.source,
                                'tags': bot.tags,
                              });
                            },
                            child:
                                _BotCard(bot: state.bots[index], colors: colors),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotCard extends StatelessWidget {
  const _BotCard({required this.bot, required this.colors});

  final Bot bot;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                onPressed: () {},
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: bot.tags
                .map(
                  (tag) => Chip(
                    visualDensity:
                        const VisualDensity(horizontal: -4, vertical: -2),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    labelStyle: const TextStyle(color: Colors.white70),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    label: Text(tag, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
          ),
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
