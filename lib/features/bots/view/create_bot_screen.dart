import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/state/home_state.dart';
import '../state/bots_state.dart';

class CreateBotScreen extends ConsumerStatefulWidget {
  const CreateBotScreen({super.key});

  @override
  ConsumerState<CreateBotScreen> createState() => _CreateBotScreenState();
}

class _CreateBotScreenState extends ConsumerState<CreateBotScreen> {
  String? _selectedDocumentId;
  final _nameController = TextEditingController();
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    // Refresh documents so the list is up to date.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeControllerProvider.notifier).refresh().catchError((_) {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final homeState = ref.watch(homeControllerProvider);
    final docs = homeState.documents;
    final hasDocs = docs.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Bot'),
        backgroundColor: colors.surface,
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick a document',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: hasDocs
                      ? ListView.separated(
                          itemCount: docs.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final selected = doc.id == _selectedDocumentId;
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              tileColor: selected
                                  ? colors.primary.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              leading: Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selected
                                    ? colors.primary
                                    : Colors.white70,
                              ),
                              title: Text(
                                doc.title,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${doc.size} • ${doc.dateLabel}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              onTap: () {
                                setState(() => _selectedDocumentId = doc.id);
                                if (_nameController.text.isEmpty) {
                                  _nameController.text = doc.title;
                                }
                              },
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_off,
                                  color: Colors.white54, size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                'No documents yet',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => GoRouter.of(context)
                                    .push('/scan', extra: DocumentKind.normal),
                                icon: const Icon(Icons.document_scanner_rounded),
                                label: const Text('Scan now'),
                              ),
                            ],
                          ),
                        ),
                ),
                if (hasDocs) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Bot name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creating ? null : _handleCreate,
                      icon: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.smart_toy_outlined),
                      label: const Text('Create bot'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreate() async {
    final docId = _selectedDocumentId;
    if (docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document first.')),
      );
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a bot name.')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final bot = await ref
          .read(botsControllerProvider.notifier)
          .createBotFromDocument(docId, name: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bot "$name" created')),
      );
      GoRouter.of(context).go('/botChat', extra: {
        'id': bot.id,
        'name': bot.name,
        'source': bot.source,
        'tags': bot.tags,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }
}
