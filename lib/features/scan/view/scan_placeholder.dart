import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../home/state/home_state.dart';
import 'scan_review_page.dart';
import '../../../app_theme.dart';

class ScanPlaceholderPage extends ConsumerStatefulWidget {
  const ScanPlaceholderPage({super.key, required this.kind});

  final DocumentKind kind;

  @override
  ConsumerState<ScanPlaceholderPage> createState() =>
      _ScanPlaceholderPageState();
}

class _ScanPlaceholderPageState extends ConsumerState<ScanPlaceholderPage> {
  bool _isProcessing = false;

  String get _title {
    switch (widget.kind) {
      case DocumentKind.normal:
        return 'Document Scan';
      case DocumentKind.ocr:
        return 'Text Extraction';
      case DocumentKind.handwriting:
        return 'Hand writing Scan';
      case DocumentKind.csv:
        return 'Table/CSV Extraction';
    }
  }

  String get _description {
    switch (widget.kind) {
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
    switch (widget.kind) {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_title), backgroundColor: colors.surface),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(Theme.of(context).colorScheme),
        ),
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: colors.primary.withValues(
                            alpha: 0.2,
                          ),
                          child: Icon(_icon, color: colors.primary, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _title,
                          textAlign: TextAlign.center,
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
                          style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () async {
                                  await _handleScan(ref);
                                },
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Scan with camera'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () async {
                                  await _handlePick(ref);
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('Choose file or image'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () {
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
            ),
            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleScan(WidgetRef ref) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final result = await _scanWithCamera(widget.kind);
      if (result != null && mounted) {
        if (result.path.toLowerCase().endsWith('.pdf')) {
          await _directUpload(ref, widget.kind, result.title, result.path);
        } else {
          await _reviewAndSave(ref, widget.kind, [result.path], result.title);
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handlePick(WidgetRef ref) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final result = await _pickFileOrImage(widget.kind);
      if (result != null && mounted) {
        if (result.path.toLowerCase().endsWith('.pdf')) {
          await _directUpload(ref, widget.kind, result.title, result.path);
        } else {
          await _reviewAndSave(ref, widget.kind, [result.path], result.title);
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reviewAndSave(
    WidgetRef ref,
    DocumentKind kind,
    List<String> paths,
    String title,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScanReviewPage(paths: paths, kind: kind),
      ),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _directUpload(
    WidgetRef ref,
    DocumentKind kind,
    String title,
    String path,
  ) async {
    final controller = ref.read(homeControllerProvider.notifier);
    try {
      await controller.uploadDocument(title, kind, path: path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded "$title"')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      await controller.addOfflineDocument(title, kind, path: path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Saved offline. We will sync when you are back online.'),
        ),
      );
      Navigator.of(context).pop();
    }
  }
}

const MethodChannel _visionScannerChannel = MethodChannel(
  'writescan/vision_scanner',
);

class _PickResult {
  _PickResult(this.title, this.path);
  final String title;
  final String path;
}

Future<_PickResult?> _scanWithCamera(DocumentKind kind) async {
  if (Platform.isIOS) {
    final vision = await _scanWithVisionKit();
    if (vision != null) {
      return vision;
    }
  }

  if (Platform.isAndroid) {
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
    } catch (e) {
      debugPrint('Document scanner failed: $e');
    }
  }

  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.camera);
  if (picked != null) {
    return _PickResult(_friendlyName(picked.path), picked.path);
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

Future<_PickResult?> _scanWithVisionKit() async {
  if (!Platform.isIOS) return null;
  try {
    final path = await _visionScannerChannel.invokeMethod<String>(
      'scanDocument',
    );
    if (path == null || path.isEmpty) return null;
    return _PickResult(_friendlyName(path), path);
  } on PlatformException catch (e) {
    debugPrint('VisionKit scanner error: $e');
    return null;
  }
}
