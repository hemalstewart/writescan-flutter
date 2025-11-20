import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/local_storage.dart';
import '../../home/state/home_state.dart';
import '../../../app_theme.dart';

class DocumentViewerPage extends ConsumerStatefulWidget {
  const DocumentViewerPage({super.key, required this.document});

  final DocumentItem document;

  @override
  ConsumerState<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends ConsumerState<DocumentViewerPage> {
  PdfControllerPinch? _controller;
  bool _loading = true;
  String? _error;
  late DocumentItem _doc;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
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
    if (_doc.path != null) {
      return File(_doc.path!);
    }
    final url = _doc.fileUrl;
    if (url == null || url.isEmpty) {
      throw Exception('Document file not available');
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/doc-${_doc.id}.pdf');

    final cookie = await LocalStorage().getSessionCookie();
    final response = await http.get(
      Uri.parse(url),
      headers: {if (cookie != null) 'Cookie': cookie},
    );
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
        title: Text(_doc.title),
        backgroundColor: colors.surface,
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _working ? null : _shareCurrent,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  _renameDocument();
                  break;
                case 'move':
                  _moveDocument();
                  break;
                case 'delete':
                  _deleteDocument();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'move', child: Text('Move to folder')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(Theme.of(context).colorScheme),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : PdfViewPinch(controller: _controller!),
      ),
    );
  }

  Future<void> _shareCurrent() async {
    setState(() => _working = true);
    try {
      final file = await _resolveFile();
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? const Rect.fromLTWH(0, 0, 0, 0)
          : box.localToGlobal(Offset.zero) & box.size;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _doc.title,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _renameDocument() async {
    final controller = TextEditingController(text: _doc.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Document name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    setState(() => _working = true);
    try {
      await ref
          .read(homeControllerProvider.notifier)
          .renameDocument(_doc.id, newName);
      setState(() {
        _doc = _doc.copyWith(title: newName);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document renamed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rename failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _moveDocument() async {
    final state = ref.read(homeControllerProvider);
    final folders = state.folders;
    final colors = Theme.of(context).colorScheme;
    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'No folder',
                style: TextStyle(color: colors.onSurface),
              ),
              trailing: _doc.folderId == null
                  ? Icon(
                      Icons.check,
                      color: colors.onSurface.withValues(alpha: 0.7),
                    )
                  : null,
              onTap: () => Navigator.pop(context, null),
            ),
            ...folders.map(
              (folder) => ListTile(
                title: Text(
                  folder.name,
                  style: TextStyle(color: colors.onSurface),
                ),
                trailing: _doc.folderId == folder.id
                    ? Icon(
                        Icons.check,
                        color: colors.onSurface.withValues(alpha: 0.7),
                      )
                    : null,
                onTap: () => Navigator.pop(context, folder.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == _doc.folderId) return;
    setState(() => _working = true);
    try {
      await ref
          .read(homeControllerProvider.notifier)
          .moveDocument(_doc.id, folderId: result);
      setState(() {
        _doc = _doc.copyWith(folderId: result);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document moved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Move failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text('This will remove the document from your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _working = true);
    try {
      await ref.read(homeControllerProvider.notifier).deleteDocument(_doc.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
