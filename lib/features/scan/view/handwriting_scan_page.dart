import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../home/state/home_state.dart';
import '../../../app_theme.dart';

class HandwritingScanPage extends ConsumerStatefulWidget {
  const HandwritingScanPage({super.key});

  @override
  ConsumerState<HandwritingScanPage> createState() =>
      _HandwritingScanPageState();
}

class _HandwritingScanPageState extends ConsumerState<HandwritingScanPage> {
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  String _status = 'Capture a handwritten note to convert it into text.';
  String? _imagePath;
  bool _processing = false;
  bool _saving = false;
  late final TextRecognizer _textRecognizer;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hand writing Scan'),
        backgroundColor: colors.surface,
        actions: [
          IconButton(
            tooltip: _textFocusNode.hasFocus ? 'Hide keyboard' : 'Edit text',
            icon: Icon(
              _textFocusNode.hasFocus
                  ? Icons.keyboard_hide_rounded
                  : Icons.edit_note_rounded,
            ),
            onPressed: () {
              if (_textFocusNode.hasFocus) {
                _textFocusNode.unfocus();
              } else {
                FocusScope.of(context).requestFocus(_textFocusNode);
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(Theme.of(context).colorScheme),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final baseHeight = media.size.height - media.padding.vertical;
              final editorHeight = math.max(220.0, baseHeight - 360);
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + media.viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PreviewCard(imagePath: _imagePath),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _processing ? null : _captureImage,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Capture'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _processing ? null : _pickImage,
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: editorHeight,
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Scrollbar(
                          child: TextField(
                            controller: _textController,
                            focusNode: _textFocusNode,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              hintText: 'Recognised text will appear here...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            (_textController.text.trim().isEmpty || _saving)
                            ? null
                            : _saveNote,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: const Text('Save to documents'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      await _processImage(file.path);
    }
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res != null && res.files.single.path != null) {
      await _processImage(res.files.single.path!);
    }
  }

  Future<void> _processImage(String path) async {
    setState(() {
      _processing = true;
      _status = 'Reading handwriting...';
      _imagePath = path;
      _textController.clear();
    });
    try {
      final input = InputImage.fromFilePath(path);
      final result = await _textRecognizer.processImage(input);
      final text = result.text.trim();
      setState(() {
        _textController.text = text;
        _status = text.isEmpty
            ? 'No handwriting detected. Try again with better lighting.'
            : 'Review the text, edit if needed, then save.';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to read handwriting: $e';
      });
    } finally {
      setState(() => _processing = false);
    }
  }

  Future<void> _saveNote() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to save yet.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.txt'),
      );
      await file.writeAsString(text);
      final name = 'Handwriting ${DateTime.now().millisecondsSinceEpoch}';
      final home = ref.read(homeControllerProvider.notifier);
      try {
        await home.uploadDocument(
          name,
          DocumentKind.handwriting,
          path: file.path,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved "$name" to Documents')));
        Navigator.pop(context);
      } catch (_) {
        await home.addOfflineDocument(
          name,
          DocumentKind.handwriting,
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: imagePath == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.draw_rounded, color: Colors.white54, size: 48),
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
