import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/home_api.dart';
import '../data/home_local_data_source.dart';

class Folder {
  Folder({
    required this.id,
    required this.name,
    this.count = 0,
    this.color,
  });

  final String id;
  final String name;
  final int count;
  final String? color;

  Folder copyWith({String? name, int? count, String? color}) {
    return Folder(
      id: id,
      name: name ?? this.name,
      count: count ?? this.count,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'count': count,
        'color': color,
      };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: _idFrom(json['id'] ?? json['folder_id'] ?? json['uuid']),
        name: (json['name'] ?? json['title'] ?? 'Untitled').toString(),
        count: _countFrom(
          json['count'] ??
              json['documents_count'] ??
              json['document_count'],
        ),
        color: json['color'] as String? ?? json['colour'] as String?,
      );
}

class DocumentItem {
  DocumentItem({
    required this.id,
    required this.title,
    required this.size,
    required this.dateLabel,
    this.folderId,
    this.kind = DocumentKind.normal,
    this.path,
    this.fileUrl,
  });

  final String id;
  final String title;
  final String size;
  final String dateLabel;
  final String? folderId;
  final DocumentKind kind;
  final String? path;
  final String? fileUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'size': size,
        'dateLabel': dateLabel,
        'folderId': folderId,
        'kind': kind.name,
        'path': path,
        'fileUrl': fileUrl,
      };

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
        id: _idFrom(json['id'] ?? json['document_id'] ?? json['uuid']),
        title: (json['title'] ?? json['name'] ?? 'Untitled').toString(),
        size: _sizeLabel(
          json['size'] ??
              json['size_label'] ??
              json['sizeLabel'] ??
              json['size_bytes'] ??
              json['file_size'] ??
              json['filesize'],
        ),
        dateLabel: _dateLabelFromRaw(
          json['dateLabel'] ??
              json['created_at'] ??
              json['createdAt'] ??
              json['updated_at'] ??
              json['timestamp'],
        ),
        folderId: _nullableString(json['folderId'] ?? json['folder_id']),
        kind: _kindFromRaw(json['kind'] ?? json['type'] ?? json['document_type']),
        path: json['path'] as String? ?? json['local_path'] as String?,
        fileUrl: json['fileUrl'] as String? ?? json['file_url'] as String?,
      );
}

enum DocumentKind { normal, ocr, handwriting, csv }

class HomeState {
  HomeState({
    required this.documents,
    required this.folders,
    this.isLoading = false,
  });

  final List<DocumentItem> documents;
  final List<Folder> folders;
  final bool isLoading;

  HomeState copyWith({
    List<DocumentItem>? documents,
    List<Folder>? folders,
    bool? isLoading,
  }) {
    return HomeState(
      documents: documents ?? this.documents,
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final homeControllerProvider =
    StateNotifierProvider<HomeController, HomeState>((ref) {
  return HomeController();
});

class HomeController extends StateNotifier<HomeState> {
  HomeController()
      : super(
          HomeState(
            documents: const [],
            folders: const [],
            isLoading: true,
          ),
        ) {
    _load();
  }

  final _store = HomeLocalDataSource();
  final _api = HomeApi();

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      await _syncFromRemote();
    } catch (error) {
      state = state.copyWith(isLoading: false);
      throw HomeException(_messageFromError(error));
    }
  }

  Future<void> uploadDocument(
    String title,
    DocumentKind kind, {
    required String path,
    String? folderId,
  }) async {
    final file = _resolveFile(path);
    if (!file.existsSync()) {
      throw HomeException('File not found on device');
    }

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimistic = DocumentItem(
      id: tempId,
      title: title,
      size: _fileSize(file.path),
      dateLabel: 'Uploading...',
      folderId: folderId,
      kind: kind,
      path: file.path,
    );
    state = state.copyWith(documents: [optimistic, ...state.documents]);
    await _persist();

    try {
      final response = await _api.uploadDocument(
        name: title,
        type: _typeForUpload(kind, file.path),
        file: file,
        folderId: folderId,
      );
      final created =
          DocumentItem.fromJson(Map<String, dynamic>.from(response));
      final remaining =
          state.documents.where((doc) => doc.id != tempId).toList();
      state = state.copyWith(documents: [created, ...remaining]);
      await _persist();
      await _syncFromRemoteSilently();
    } catch (error) {
      state = state.copyWith(
        documents: state.documents.where((doc) => doc.id != tempId).toList(),
      );
      await _persist();
      throw HomeException(_messageFromError(error));
    }
  }

  Future<void> addFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw HomeException('Folder name cannot be empty');
    }
    try {
      final response = await _api.createFolder(trimmed);
      final folder =
          Folder.fromJson(Map<String, dynamic>.from(response));
      state = state.copyWith(folders: [folder, ...state.folders]);
      await _persist();
    } catch (error) {
      throw HomeException(_messageFromError(error));
    }
  }

  void deleteDocument(String id) {
    state = state.copyWith(
      documents: state.documents.where((d) => d.id != id).toList(),
    );
    _persist();
  }

  double _randomSize() {
    final value = 0.4 + (DateTime.now().millisecond % 12) / 10;
    return double.parse(value.toStringAsFixed(1));
  }

  String _fileSize(String path) {
    try {
      final file = File(path);
      final bytes = file.lengthSync();
      final kb = bytes / 1024;
      final mb = kb / 1024;
      if (mb >= 1) {
        return '${mb.toStringAsFixed(1)} MB';
      }
      return '${kb.toStringAsFixed(0)} KB';
    } catch (_) {
      return '${_randomSize()} MB';
    }
  }

  Future<void> _load() async {
    try {
      await _syncFromRemote();
      return;
    } catch (_) {
      // fall back to locally cached content
    }
    await _loadFromLocal();
  }

  Future<void> _loadFromLocal() async {
    try {
      final (docs, folders) = await _store.load();
      if (docs.isEmpty && folders.isEmpty) {
        state = HomeState(
          documents: [
            DocumentItem(
              id: 'welcome',
              title: 'Welcome.pdf',
              size: '0.4 MB',
              dateLabel: 'Just now',
              kind: DocumentKind.normal,
            ),
            DocumentItem(
              id: 'handwriting',
              title: 'Handwriting sample',
              size: '0.6 MB',
              dateLabel: 'Today',
              kind: DocumentKind.handwriting,
            ),
          ],
          folders: [
            Folder(id: 'f1', name: 'Work', count: 2),
            Folder(id: 'f2', name: 'Receipts', count: 5),
          ],
          isLoading: false,
        );
        await _persist();
      } else {
        state = state.copyWith(
          documents: docs,
          folders: folders,
          isLoading: false,
        );
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _syncFromRemote() async {
    final docsRaw = await _api.fetchDocuments();
    final foldersRaw = await _api.fetchFolders();
    final documents = docsRaw
        .map((e) => DocumentItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final folders = foldersRaw
        .map((e) => Folder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    state = state.copyWith(
      documents: documents,
      folders: folders,
      isLoading: false,
    );
    await _persist();
  }

  Future<void> _syncFromRemoteSilently() async {
    try {
      await _syncFromRemote();
    } catch (_) {
      // ignore if sync fails after optimistic update
    }
  }

  Future<void> _persist() async {
    await _store.save(state.documents, state.folders);
  }

  File _resolveFile(String rawPath) {
    if (rawPath.startsWith('file://')) {
      return File(Uri.parse(rawPath).toFilePath());
    }
    return File(rawPath);
  }

  String _typeForUpload(DocumentKind kind, String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.csv' || ext == '.tsv') return 'csv';
    if (ext == '.txt') return 'text';
    if (ext == '.xls' || ext == '.xlsx') return 'sheet';
    if (ext == '.png' ||
        ext == '.jpg' ||
        ext == '.jpeg' ||
        ext == '.heic' ||
        ext == '.heif') {
      return 'image';
    }
    if (ext == '.pdf') return 'pdf';

    switch (kind) {
      case DocumentKind.csv:
        return 'csv';
      case DocumentKind.ocr:
        return 'text';
      case DocumentKind.handwriting:
        return 'image';
      case DocumentKind.normal:
        return 'pdf';
    }
  }

  String _messageFromError(Object error) {
    if (error is HomeException) return error.message;
    if (error is HomeApiException) return error.message;
    return error.toString();
  }
}

class HomeException implements Exception {
  HomeException(this.message);
  final String message;

  @override
  String toString() => message;
}

String _sizeLabel(dynamic raw) {
  if (raw == null) return '—';
  if (raw is String) {
    final parsed = double.tryParse(raw);
    if (parsed != null) {
      return _sizeLabel(parsed);
    }
    if (raw.trim().isNotEmpty) return raw;
    return '—';
  }
  if (raw is num) {
    final bytes = raw.toDouble();
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
  return raw.toString();
}

String _dateLabelFromRaw(dynamic raw) {
  if (raw == null) return 'Just now';
  if (raw is DateTime) {
    return _formatRelative(raw.toLocal());
  }
  if (raw is int) {
    final date = DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
    return _formatRelative(date.toLocal());
  }
  if (raw is String && raw.isNotEmpty) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return _formatRelative(parsed.toLocal());
    }
    return raw;
  }
  return 'Just now';
}

String _formatRelative(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final other = DateTime(date.year, date.month, date.day);
  final diff = today.difference(other).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

DocumentKind _kindFromRaw(dynamic raw) {
  final type = raw?.toString().toLowerCase();
  switch (type) {
    case 'ocr':
    case 'text':
    case 'text_extraction':
      return DocumentKind.ocr;
    case 'handwriting':
    case 'note':
      return DocumentKind.handwriting;
    case 'csv':
    case 'tsv':
    case 'sheet':
    case 'excel':
    case 'table':
      return DocumentKind.csv;
    default:
      return DocumentKind.normal;
  }
}

String _idFrom(dynamic value) {
  if (value == null) {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  return value.toString();
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final asString = value.toString();
  if (asString.isEmpty) return null;
  return asString;
}

int _countFrom(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
