import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../home/state/home_state.dart';
import '../../../utils/open_document.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key, this.folderId, this.folderName});

  final String? folderId;
  final String? folderName;

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleQueryChange);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleQueryChange);
    _searchController.dispose();
    super.dispose();
  }

  void _handleQueryChange() {
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);
    final folderMap = {
      for (final folder in state.folders) folder.id: folder.name,
    };
    var docs = state.documents;
    if (widget.folderId != null) {
      docs = docs.where((d) => d.folderId == widget.folderId).toList();
    }
    if (_query.isNotEmpty) {
      docs = docs
          .where(
            (d) =>
                d.title.toLowerCase().contains(_query) ||
                (folderMap[d.folderId]?.toLowerCase().contains(_query) ?? false),
          )
          .toList();
    }
    docs.sort((a, b) {
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime.now();
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime.now();
      return bDate.compareTo(aDate);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderId == null
            ? 'Documents'
            : widget.folderName ?? 'Folder'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
          ),
          if (widget.folderId != null)
            PopupMenuButton<String>(
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename folder')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete folder'),
                ),
              ],
              onSelected: (value) {
                if (value == 'rename') {
                  _renameCurrentFolder();
                } else if (value == 'delete') {
                  _deleteCurrentFolder();
                }
              },
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0F25), Color(0xFF1B1740)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            if (_showSearch)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search documents',
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: docs.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No documents found',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final subtitle = [
                            if (doc.size.isNotEmpty) doc.size,
                            doc.dateLabel,
                            if (folderMap[doc.folderId] != null)
                              folderMap[doc.folderId]!,
                          ].join(' • ');

                          return Card(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    colors.primary.withValues(alpha: 0.16),
                                child: Icon(
                                  _iconForKind(doc.kind),
                                  color: colors.primary,
                                ),
                              ),
                              title: Text(
                                doc.title,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                subtitle,
                                style:
                                    const TextStyle(color: Colors.white70),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white70),
                                onPressed: () => _showActions(context, doc),
                              ),
                              onTap: () => openDocument(context, doc),
                            ),
                          );
                        },
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 8),
                        itemCount: docs.length,
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.folderId == null
          ? FloatingActionButton.extended(
              onPressed: () {
                GoRouter.of(context)
                    .push('/scan', extra: DocumentKind.normal);
              },
              icon: const Icon(Icons.document_scanner_rounded),
              label: const Text('Scan'),
            )
          : null,
    );
  }

  Future<void> _showActions(BuildContext context, DocumentItem doc) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline,
                    color: Colors.white),
                title: const Text('Rename',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _promptRename(doc);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.folder_open, color: Colors.white),
                title: const Text('Move to folder',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showMoveSheet(doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(doc);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _promptRename(DocumentItem doc) async {
    final controller = TextEditingController(text: doc.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref
          .read(homeControllerProvider.notifier)
          .renameDocument(doc.id, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document renamed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _showMoveSheet(DocumentItem doc) async {
    final folders = ref.read(homeControllerProvider).folders;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.clear_all, color: Colors.white),
                title: const Text('No folder',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, null),
              ),
              for (final folder in folders)
                ListTile(
                  leading: const Icon(Icons.folder, color: Colors.white),
                  title: Text(folder.name,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, folder.id),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null && doc.folderId == null) return;
    try {
      await ref
          .read(homeControllerProvider.notifier)
          .moveDocument(doc.id, folderId: selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _confirmDelete(DocumentItem doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text(
            'This will move the document to the archive on the server.'),
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
    if (confirmed != true) return;
    try {
      await ref.read(homeControllerProvider.notifier).deleteDocument(doc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _renameCurrentFolder() async {
    final id = widget.folderId;
    if (id == null) return;
    final controller = TextEditingController(text: widget.folderName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Folder name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref.read(homeControllerProvider.notifier).renameFolder(id, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder renamed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deleteCurrentFolder() async {
    final id = widget.folderId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this folder?'),
        content: const Text('Documents will remain in your library.'),
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
    if (confirmed != true) return;
    try {
      await ref.read(homeControllerProvider.notifier).deleteFolder(id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
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
