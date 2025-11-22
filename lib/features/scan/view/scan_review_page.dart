import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../home/state/home_state.dart';
import '../../home/state/home_state.dart' show DocumentKind, homeControllerProvider;

class ScanReviewPage extends ConsumerStatefulWidget {
  const ScanReviewPage({
    super.key,
    required this.paths,
    required this.kind,
  });

  final List<String> paths;
  final DocumentKind kind;

  @override
  ConsumerState<ScanReviewPage> createState() => _ScanReviewPageState();
}

class _ScanReviewPageState extends ConsumerState<ScanReviewPage> {
  late List<_PageItem> _pages;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pages = widget.paths.map((e) => _PageItem(file: File(e))).toList();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final dir = await getTemporaryDirectory();
      final merged = File(
        p.join(dir.path, 'scan-${DateTime.now().millisecondsSinceEpoch}.pdf'),
      );
      final doc = pw.Document();
      for (final page in _pages) {
        final data = await page.file.readAsBytes();
        final decoded = img.decodeImage(data);
        if (decoded != null) {
          final png = img.encodePng(decoded);
          final image = pw.MemoryImage(png);
          doc.addPage(
            pw.Page(
              margin: const pw.EdgeInsets.all(16),
              build: (_) => pw.Center(child: pw.Image(image)),
            ),
          );
        }
      }
      await merged.writeAsBytes(await doc.save());

      final title = 'scan-${DateTime.now().millisecondsSinceEpoch}.pdf';
      await ref.read(homeControllerProvider.notifier).uploadDocument(
            title,
            widget.kind,
            path: merged.path,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "$title"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyFilter(_PageItem page, _Filter filter) async {
    try {
      final data = await page.file.readAsBytes();
      var image = img.decodeImage(data);
      if (image == null) return;
      switch (filter) {
        case _Filter.rotateLeft:
          image = img.copyRotate(image, angle: -90);
          break;
        case _Filter.rotateRight:
          image = img.copyRotate(image, angle: 90);
          break;
        case _Filter.bw:
          image = img.grayscale(image);
          image = img.adjustColor(image, contrast: 1.2, brightness: 0.05);
          break;
        case _Filter.enhance:
          image = img.adjustColor(
            image,
            contrast: 1.15,
            saturation: 1.05,
            brightness: 0.05,
          );
          break;
      }
      final temp = await _writeTemp(image);
      setState(() {
        page.file = temp;
      });
    } catch (_) {}
  }

  Future<File> _writeTemp(img.Image image) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'page-${DateTime.now().millisecondsSinceEpoch}.png'),
    );
    await file.writeAsBytes(img.encodePng(image));
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review pages')),
        body: Center(
          child: Text(
            'No pages to review',
            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review pages'),
        actions: [
          TextButton.icon(
            onPressed: _saving || _pages.isEmpty ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pages.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _pages.removeAt(oldIndex);
            _pages.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final page = _pages[index];
          return Card(
            key: ValueKey(page.file.path),
            elevation: 2,
            child: Column(
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      page.file,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Rotate left',
                            onPressed: () => _applyFilter(
                              page,
                              _Filter.rotateLeft,
                            ),
                            icon: const Icon(Icons.rotate_left),
                          ),
                          IconButton(
                            tooltip: 'Rotate right',
                            onPressed: () => _applyFilter(
                              page,
                              _Filter.rotateRight,
                            ),
                            icon: const Icon(Icons.rotate_right),
                          ),
                          IconButton(
                            tooltip: 'B/W',
                            onPressed: () => _applyFilter(page, _Filter.bw),
                            icon: const Icon(Icons.filter_b_and_w),
                          ),
                          IconButton(
                            tooltip: 'Enhance',
                            onPressed: () => _applyFilter(page, _Filter.enhance),
                            icon: const Icon(Icons.auto_fix_high_rounded),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () {
                          setState(() => _pages.removeAt(index));
                        },
                        icon: Icon(Icons.delete_outline,
                            color: colors.error.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _Filter { rotateLeft, rotateRight, bw, enhance }

class _PageItem {
  _PageItem({required this.file});
  File file;
}
