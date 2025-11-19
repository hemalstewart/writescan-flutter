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
    this.createdAt,
    this.updatedAt,
    this.status,
    this.mimeType,
    this.geminiText,
    this.sizeBytes,
  });

  final String id;
  final String title;
  final String size;
  final String dateLabel;
  final String? folderId;
  final DocumentKind kind;
  final String? path;
  final String? fileUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? status;
  final String? mimeType;
  final String? geminiText;
  final int? sizeBytes;

  bool get isPdf {
    if (mimeType != null && mimeType!.toLowerCase().contains('pdf')) {
      return true;
    }
    bool hasPdf(String? value) => value?.toLowerCase().endsWith('.pdf') ?? false;
    return hasPdf(title) || hasPdf(path) || hasPdf(fileUrl);
  }

  DocumentItem copyWith({
    String? title,
    String? size,
    String? dateLabel,
    String? folderId,
    DocumentKind? kind,
    String? path,
    String? fileUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? mimeType,
    String? geminiText,
    int? sizeBytes,
  }) {
    return DocumentItem(
      id: id,
      title: title ?? this.title,
      size: size ?? this.size,
      dateLabel: dateLabel ?? this.dateLabel,
      folderId: folderId ?? this.folderId,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      fileUrl: fileUrl ?? this.fileUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      mimeType: mimeType ?? this.mimeType,
      geminiText: geminiText ?? this.geminiText,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'size': size,
        'dateLabel': dateLabel,
        'folderId': folderId,
        'kind': kind.name,
        'path': path,
        'fileUrl': fileUrl,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'status': status,
        'mimeType': mimeType,
        'geminiText': geminiText,
        'sizeBytes': sizeBytes,
      };

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    final rawSize = json['size'] ??
        json['size_label'] ??
        json['sizeLabel'] ??
        json['size_bytes'] ??
        json['file_size'] ??
        json['filesize'];
    final createdRaw =
        json['createdAt'] ?? json['created_at'] ?? json['timestamp'];
    final updatedRaw = json['updatedAt'] ?? json['updated_at'];

    return DocumentItem(
      id: _idFrom(json['id'] ?? json['document_id'] ?? json['uuid']),
      title: (json['title'] ?? json['name'] ?? 'Untitled').toString(),
      size: _sizeLabel(rawSize),
      dateLabel: _dateLabelFromRaw(
        json['dateLabel'] ??
            json['created_at'] ??
            json['createdAt'] ??
            json['updated_at'] ??
            json['timestamp'],
      ),
      folderId: _nullableString(json['folderId'] ?? json['folder_id']),
      kind:
          _kindFromRaw(json['kind'] ?? json['type'] ?? json['document_type']),
      path: json['path'] as String? ?? json['local_path'] as String?,
      fileUrl: json['fileUrl'] as String? ?? json['file_url'] as String?,
      createdAt: _dateFromRaw(createdRaw),
      updatedAt: _dateFromRaw(updatedRaw),
      status: json['status'] as String?,
      mimeType:
          json['mimeType'] as String? ?? json['mime_type'] as String?,
      geminiText: json['geminiText'] as String? ??
          json['gemini_text'] as String? ??
          json['summary'] as String?,
      sizeBytes: _sizeBytes(rawSize),
    );
  }
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

  Future<void> renameFolder(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw HomeException('Folder name cannot be empty');
    }
    final idx = state.folders.indexWhere((f) => f.id == id);
    if (idx == -1) throw HomeException('Folder not found');
    final prev = state.folders[idx];
    final updatedFolders = List<Folder>.from(state.folders);
    updatedFolders[idx] = prev.copyWith(name: trimmed);
    state = state.copyWith(folders: updatedFolders);
    await _persist();
    try {
      final response = await _api.updateFolder(id, trimmed);
      final folder = Folder.fromJson(Map<String, dynamic>.from(response));
      final refreshed = List<Folder>.from(state.folders);
      final newIdx = refreshed.indexWhere((f) => f.id == folder.id);
      if (newIdx != -1) {
        refreshed[newIdx] = folder;
        state = state.copyWith(folders: refreshed);
        await _persist();
      }
    } catch (error) {
      final reverted = List<Folder>.from(state.folders);
      final revertIdx = reverted.indexWhere((f) => f.id == prev.id);
      if (revertIdx != -1) {
        reverted[revertIdx] = prev;
        state = state.copyWith(folders: reverted);
        await _persist();
      }
      throw HomeException(_messageFromError(error));
    }
  }

  Future<void> deleteFolder(String id) async {
    final idx = state.folders.indexWhere((f) => f.id == id);
    if (idx == -1) throw HomeException('Folder not found');
    final removed = state.folders[idx];
    final remaining = List<Folder>.from(state.folders)..removeAt(idx);
    state = state.copyWith(folders: remaining);
    await _persist();
    try {
      await _api.deleteFolder(id);
      await _syncFromRemoteSilently();
    } catch (error) {
      final reverted = List<Folder>.from(state.folders);
      reverted.insert(idx <= reverted.length ? idx : reverted.length, removed);
      state = state.copyWith(folders: reverted);
      await _persist();
      throw HomeException(_messageFromError(error));
    }
  }

  Future<void> renameDocument(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw HomeException('Name cannot be empty');
    }
    final idx = state.documents.indexWhere((d) => d.id == id);
    if (idx == -1) throw HomeException('Document not found');
    final previous = state.documents[idx];
    final docs = List<DocumentItem>.from(state.documents);
    docs[idx] = previous.copyWith(title: trimmed);
    state = state.copyWith(documents: docs);
    await _persist();
    try {
      final response = await _api.updateDocument(id, name: trimmed);
      final updated =
          DocumentItem.fromJson(Map<String, dynamic>.from(response));
      await _replaceDocument(updated);
      await _syncFromRemoteSilently();
    } catch (error) {
      await _restoreDocument(previous);
      throw HomeException(_messageFromError(error));
    }
  }

  Future<void> moveDocument(String id, {String? folderId}) async {
    final idx = state.documents.indexWhere((d) => d.id == id);
    if (idx == -1) throw HomeException('Document not found');
    final previous = state.documents[idx];
    final docs = List<DocumentItem>.from(state.documents);
    docs[idx] = previous.copyWith(folderId: folderId);
    state = state.copyWith(documents: docs);
    await _persist();
    try {
      final response =
          await _api.updateDocument(id, folderId: folderId ?? '');
      final updated =
          DocumentItem.fromJson(Map<String, dynamic>.from(response));
      await _replaceDocument(updated);
      await _syncFromRemoteSilently();
    } catch (error) {
      await _restoreDocument(previous);
      throw HomeException(_messageFromError(error));
    }
  }

  Future<void> deleteDocument(String id) async {
    final docs = List<DocumentItem>.from(state.documents);
    final idx = docs.indexWhere((d) => d.id == id);
    if (idx == -1) throw HomeException('Document not found');
    final removed = docs.removeAt(idx);
    state = state.copyWith(documents: docs);
    await _persist();
    try {
      await _api.deleteDocument(id);
      await _syncFromRemoteSilently();
    } catch (error) {
      final reverted = List<DocumentItem>.from(state.documents);
      final insertIndex = idx <= reverted.length ? idx : reverted.length;
      reverted.insert(insertIndex, removed);
      state = state.copyWith(documents: reverted);
      await _persist();
      throw HomeException(_messageFromError(error));
    }
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

  Future<void> _replaceDocument(DocumentItem document) async {
    final docs = List<DocumentItem>.from(state.documents);
    final idx = docs.indexWhere((d) => d.id == document.id);
    if (idx == -1) {
      docs.insert(0, document);
    } else {
      docs[idx] = document;
    }
    state = state.copyWith(documents: docs);
    await _persist();
  }

  Future<void> _restoreDocument(DocumentItem document) async {
    final docs = List<DocumentItem>.from(state.documents);
    final idx = docs.indexWhere((d) => d.id == document.id);
    if (idx == -1) {
      docs.insert(0, document);
    } else {
      docs[idx] = document;
    }
    state = state.copyWith(documents: docs);
    await _persist();
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

DateTime? _dateFromRaw(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is int) {
    final millis = raw < 1000000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
        .toLocal();
  }
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
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

int? _sizeBytes(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is double) return raw.toInt();
  if (raw is num) return raw.toInt();
  if (raw is String) {
    final trimmed = raw.trim().toLowerCase();
    final numeric = double.tryParse(trimmed);
    if (numeric != null) return numeric.toInt();
    final match = RegExp(r'([0-9.]+)\s*(kb|mb|gb|bytes)')
        .firstMatch(trimmed);
    if (match != null) {
      final value = double.tryParse(match.group(1) ?? '');
      final unit = match.group(2);
      if (value != null && unit != null) {
        final multiplier = switch (unit) {
          'kb' => 1024,
          'mb' => 1024 * 1024,
          'gb' => 1024 * 1024 * 1024,
          _ => 1,
        };
        return (value * multiplier).toInt();
      }
    }
  }
  return null;
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
