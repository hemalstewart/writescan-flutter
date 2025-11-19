import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../../data/local_storage.dart';
import '../../home/state/home_state.dart';

class DocumentViewerPage extends StatefulWidget {
  const DocumentViewerPage({super.key, required this.document});

  final DocumentItem document;

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  PdfControllerPinch? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareDocument();
  }

  Future<void> _prepareDocument() async {
    try {
      final file = await _resolveFile();
      final controller = PdfControllerPinch(
        document: PdfDocument.openFile(file.path),
      );
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<File> _resolveFile() async {
    if (widget.document.path != null) {
      return File(widget.document.path!);
    }
    final url = widget.document.fileUrl;
    if (url == null || url.isEmpty) {
      throw Exception('Document file not available');
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/doc-${widget.document.id}.pdf');

    final cookie = await LocalStorage().getSessionCookie();
    final response = await http.get(Uri.parse(url), headers: {
      if (cookie != null) 'Cookie': cookie,
    });
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await file.writeAsBytes(response.bodyBytes);
      return file;
    }
    throw Exception('Failed to download document (${response.statusCode})');
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : PdfViewPinch(controller: _controller!),
      ),
    );
  }
}
