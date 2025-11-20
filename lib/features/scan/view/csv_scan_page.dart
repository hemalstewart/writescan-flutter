import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../home/state/home_state.dart';

class CsvScanPage extends ConsumerStatefulWidget {
  const CsvScanPage({super.key});

  @override
  ConsumerState<CsvScanPage> createState() => _CsvScanPageState();
}

class _CsvScanPageState extends ConsumerState<CsvScanPage> {
  final _nameController = TextEditingController();
  String _status = 'Capture a table to convert it into CSV.';
  bool _processing = false;
  bool _saving = false;
  String? _imagePath;
  String? _csvContent;
  late final TextRecognizer _textRecognizer;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV Scanner'),
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
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewCard(imagePath: _imagePath),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _processing ? null : _captureFromCamera,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Capture'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _processing ? null : _pickFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_csvContent != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _csvContent!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 140),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'File name',
                        hintText: 'e.g. Quarterly Report',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (_csvContent == null || _saving)
                            ? null
                            : _saveCsvDocument,
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
                        label: const Text('Save to documents'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _captureFromCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      await _processImage(file.path);
    }
  }

  Future<void> _pickFromGallery() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res != null && res.files.single.path != null) {
      await _processImage(res.files.single.path!);
    }
  }

  Future<void> _processImage(String path) async {
    setState(() {
      _processing = true;
      _status = 'Processing scan...';
      _imagePath = path;
      _csvContent = null;
    });
    try {
      final input = InputImage.fromFilePath(path);
      final result = await _textRecognizer.processImage(input);
      final text = result.text.trim();
      if (text.isEmpty) {
        setState(() {
          _status =
              'No text detected. Try capturing again with better lighting.';
        });
      } else {
        final csv = _convertTextToCsv(text);
        setState(() {
          _csvContent = csv;
          _status = 'Review the generated CSV and tap save when ready.';
          if (_nameController.text.isEmpty) {
            _nameController.text = _defaultName(path);
          }
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Failed to process scan: $e';
      });
    } finally {
      setState(() => _processing = false);
    }
  }

  Future<void> _saveCsvDocument() async {
    final csv = _csvContent;
    if (csv == null || csv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan a document before saving.')),
      );
      return;
    }
    final name = _nameController.text.trim().isEmpty
        ? 'csv_document'
        : _nameController.text.trim();
    setState(() => _saving = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.csv'),
      );
      await file.writeAsString(csv);
      await ref
          .read(homeControllerProvider.notifier)
          .uploadDocument(name, DocumentKind.csv, path: file.path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved "$name" to Documents')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _convertTextToCsv(String text) {
    final buffer = StringBuffer();
    final lines = text.split(RegExp(r'\r?\n'));
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final tokens = line.split(RegExp(r'\s+'));
      for (var i = 0; i < tokens.length; i++) {
        buffer.write('"${tokens[i].replaceAll('"', '""')}"');
        if (i < tokens.length - 1) {
          buffer.write(',');
        }
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  String _defaultName(String path) {
    final base = p.basenameWithoutExtension(path);
    if (base.toLowerCase().startsWith('image')) {
      return 'CSV ${DateTime.now().millisecondsSinceEpoch}';
    }
    return base;
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: imagePath == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.table_chart_rounded,
                  color: Colors.white54,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text('No preview yet', style: TextStyle(color: Colors.white54)),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(imagePath!),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
    );
  }
}
