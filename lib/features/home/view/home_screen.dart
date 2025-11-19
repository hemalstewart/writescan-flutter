import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/home_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateFolderDialog(context, controller),
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('Folder'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0F25), Color(0xFF1B1740)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(colors: colors),
                const SizedBox(height: 18),
                _QuickActions(
                  colors: colors,
                  onAction: (kind) {
                    GoRouter.of(context).push('/scan', extra: kind);
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Recent documents',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                if (state.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (state.documents.isEmpty)
                  _emptyBlock(
                    colors,
                    'No documents yet',
                    'Use quick actions to scan or import files.',
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: state.documents
                        .map(
                          (doc) => GestureDetector(
                            onTap: (doc.path != null || doc.fileUrl != null)
                                ? () => _openFile(context, doc)
                                : null,
                            child: _DocCard(doc: doc, colors: colors),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Folders',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: colors.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showCreateFolderDialog(
                        context,
                        controller,
                      ),
                      child: const Text('New folder'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: state.folders.isEmpty
                      ? _emptyBlock(colors, 'No folders', 'Create one to organize files.')
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.folders.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) => _FolderCard(
                            folder: state.folders[index],
                            colors: colors,
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

  void _showCreateFolderDialog(
    BuildContext context,
    HomeController controller,
  ) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New folder'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Folder name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  await controller.addFolder(name);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  final message = e is HomeException
                      ? e.message
                      : 'Failed to create folder';
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors});
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: colors.primary.withValues(alpha: 0.2),
          child: const Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello!',
                style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
              ),
              Text(
                'Welcome back to WriteScan',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined, color: Colors.white70),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.colors, required this.onAction});

  final ColorScheme colors;
  final void Function(DocumentKind kind) onAction;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.document_scanner_rounded,
        label: 'Scan',
        accent: colors.primary,
        kind: DocumentKind.normal,
      ),
      _QuickAction(
        icon: Icons.image_search_rounded,
        label: 'Extract text',
        accent: colors.secondary,
        kind: DocumentKind.ocr,
      ),
      _QuickAction(
        icon: Icons.draw_rounded,
        label: 'Handwriting',
        accent: colors.tertiary,
        kind: DocumentKind.handwriting,
      ),
      _QuickAction(
        icon: Icons.table_chart_rounded,
        label: 'CSV',
        accent: Colors.tealAccent.shade400,
        kind: DocumentKind.csv,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _ActionTile(
          action: action,
          colors: colors,
          onTap: () => onAction(action.kind),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(
      {required this.action, required this.colors, required this.onTap});

  final _QuickAction action;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: action.accent.withValues(alpha: 0.2),
              child: Icon(action.icon, color: action.accent),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.colors});

  final DocumentItem doc;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
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
              Icon(_iconForKind(doc.kind), color: colors.primary),
              const Spacer(),
              Text(
                doc.size,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            doc.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                doc.dateLabel,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const Icon(Icons.more_vert, color: Colors.white54, size: 18),
            ],
          )
        ],
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.folder, required this.colors});

  final Folder folder;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final accent = _folderColor(folder.color, colors.secondary);
    return Container(
      width: 140,
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
              Icon(Icons.folder_rounded, color: accent),
              const Spacer(),
              Text(
                '${folder.count} files',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            folder.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _emptyBlock(ColorScheme colors, String title, String subtitle) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );
}

IconData _iconForKind(DocumentKind kind) {
  switch (kind) {
    case DocumentKind.normal:
      return Icons.picture_as_pdf_rounded;
    case DocumentKind.ocr:
      return Icons.text_snippet_rounded;
    case DocumentKind.handwriting:
      return Icons.brush_rounded;
    case DocumentKind.csv:
      return Icons.table_chart_rounded;
  }
}

class _QuickAction {
  _QuickAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.kind,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final DocumentKind kind;
}

Color _folderColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  final value = int.tryParse(
    'FF${hex.replaceFirst('#', '').padLeft(6, '0')}',
    radix: 16,
  );
  if (value == null) return fallback;
  return Color(value);
}

Future<void> _openFile(BuildContext context, DocumentItem doc) async {
  final target = doc.fileUrl ?? doc.path;
  if (target == null) return;
  if (target.startsWith('http')) {
    final uri = Uri.parse(target);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the document link')),
      );
    }
    return;
  }
  final result = await OpenFilex.open(target);
  if (result.type != ResultType.done && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open file: ${result.message}')),
    );
  }
}
