import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../home/state/home_state.dart';
import '../../../app_theme.dart';

class EmptyDocumentPage extends ConsumerStatefulWidget {
  const EmptyDocumentPage({super.key});

  @override
  ConsumerState<EmptyDocumentPage> createState() => _EmptyDocumentPageState();
}

class _EmptyDocumentPageState extends ConsumerState<EmptyDocumentPage> {
  final List<TextEditingController> _pages = [TextEditingController()];
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _pages) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empty Document'),
        backgroundColor: colors.surface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPage,
        icon: const Icon(Icons.add),
        label: const Text('Add page'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(Theme.of(context).colorScheme),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _PageEditor(
                      controller: _pages[index],
                      index: index,
                      onRemove: _pages.length == 1
                          ? null
                          : () => _removePage(index),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveDocument,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_alt_rounded),
                    label: const Text('Save document'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addPage() {
    setState(() {
      _pages.add(TextEditingController());
    });
  }

  void _removePage(int index) {
    setState(() {
      _pages.removeAt(index).dispose();
    });
  }

  Future<void> _saveDocument() async {
    final entries = _pages
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some content before saving.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final pdf = pw.Document();
      final font = pw.Font.helvetica();
      for (final page in entries) {
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Container(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Text(
                page,
                style: pw.TextStyle(font: font, fontSize: 12),
              ),
            ),
          ),
        );
      }
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(
          dir.path,
          'EmptyDoc-${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      final home = ref.read(homeControllerProvider.notifier);
      final name = 'Empty Document ${DateTime.now().millisecondsSinceEpoch}';
      try {
        await home.uploadDocument(
          name,
          DocumentKind.normal,
          path: file.path,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Empty document saved.')));
        Navigator.pop(context);
      } catch (_) {
        await home.addOfflineDocument(
          name,
          DocumentKind.normal,
          path: file.path,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Saved offline. We will sync when you are back online.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PageEditor extends StatelessWidget {
  const _PageEditor({
    required this.controller,
    required this.index,
    this.onRemove,
  });

  final TextEditingController controller;
  final int index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: null,
            decoration: const InputDecoration(hintText: 'Start typing...'),
          ),
        ],
      ),
    );
  }
}
