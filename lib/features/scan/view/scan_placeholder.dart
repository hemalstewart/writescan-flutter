import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../home/state/home_state.dart';

class ScanPlaceholderPage extends ConsumerWidget {
  const ScanPlaceholderPage({super.key, required this.kind});

  final DocumentKind kind;

  String get _title {
    switch (kind) {
      case DocumentKind.normal:
        return 'Document Scan';
      case DocumentKind.ocr:
        return 'Text Extraction';
      case DocumentKind.handwriting:
        return 'Handwriting Scan';
      case DocumentKind.csv:
        return 'Table/CSV Extraction';
    }
  }

  String get _description {
    switch (kind) {
      case DocumentKind.normal:
        return 'Capture pages and save them as a PDF.';
      case DocumentKind.ocr:
        return 'Turn photos into editable text.';
      case DocumentKind.handwriting:
        return 'Recognize handwriting and save it as text.';
      case DocumentKind.csv:
        return 'Detect table data and export to CSV.';
    }
  }

  IconData get _icon {
    switch (kind) {
      case DocumentKind.normal:
        return Icons.document_scanner_rounded;
      case DocumentKind.ocr:
        return Icons.text_snippet_rounded;
      case DocumentKind.handwriting:
        return Icons.draw_rounded;
      case DocumentKind.csv:
        return Icons.table_chart_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_title), backgroundColor: colors.surface),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0F25), Color(0xFF1B1740)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: colors.primary.withValues(alpha: 0.2),
                  child: Icon(_icon, color: colors.primary, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  _title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await _scanWithCamera(kind);
                    if (result != null && context.mounted) {
                      await _uploadResult(context, ref, kind, result);
                    }
                  },
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Scan with camera'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await _pickFileOrImage(kind);
                    if (result != null && context.mounted) {
                      await _uploadResult(context, ref, kind, result);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Choose file or image'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _uploadResult(
    BuildContext context,
    WidgetRef ref,
    DocumentKind kind,
    _PickResult result,
  ) async {
    final controller = ref.read(homeControllerProvider.notifier);
    try {
      await controller.uploadDocument(
        result.title,
        kind,
        path: result.path,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded "${result.title}"')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      final message =
          e is HomeException ? e.message : 'Failed to upload document';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }
}

class _PickResult {
  _PickResult(this.title, this.path);
  final String title;
  final String path;
}

Future<_PickResult?> _scanWithCamera(DocumentKind kind) async {
  final scanner = DocumentScanner(
    options: DocumentScannerOptions(
      documentFormat: DocumentFormat.pdf,
      pageLimit: 12,
      mode: ScannerMode.full,
      isGalleryImport: true,
    ),
  );
  try {
    final result = await scanner.scanDocument();
    if (result.pdf != null) {
      return _PickResult(_friendlyName(result.pdf!.uri), result.pdf!.uri);
    }
    if (result.images.isNotEmpty) {
      final first = result.images.first;
      return _PickResult(_friendlyName(first), first);
    }
  } catch (_) {
    // fallback to camera image picker
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      return _PickResult(_friendlyName(picked.path), picked.path);
    }
  }
  return null;
}

Future<_PickResult?> _pickFileOrImage(DocumentKind kind) async {
  if (kind == DocumentKind.csv) {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xls', 'xlsx', 'tsv', 'txt', 'pdf'],
    );
    if (res != null && res.files.single.path != null) {
      final path = res.files.single.path!;
      return _PickResult(_friendlyName(path), path);
    }
    return null;
  }

  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery);
  if (picked == null) return null;
  return _PickResult(_friendlyName(picked.path), picked.path);
}

String _friendlyName(String path) {
  final base = p.basename(path);
  if (base.isEmpty) return 'Untitled';
  return base;
}
