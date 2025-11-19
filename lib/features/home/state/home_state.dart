import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/home_local_data_source.dart';

class Folder {
  Folder({
    required this.id,
    required this.name,
    this.count = 0,
  });

  final String id;
  final String name;
  final int count;

  Folder copyWith({String? name, int? count}) {
    return Folder(
      id: id,
      name: name ?? this.name,
      count: count ?? this.count,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'count': count,
      };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as String,
        name: json['name'] as String,
        count: json['count'] as int? ?? 0,
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
  });

  final String id;
  final String title;
  final String size;
  final String dateLabel;
  final String? folderId;
  final DocumentKind kind;
  final String? path;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'size': size,
        'dateLabel': dateLabel,
        'folderId': folderId,
        'kind': kind.name,
        'path': path,
      };

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
        id: json['id'] as String,
        title: json['title'] as String,
        size: json['size'] as String,
        dateLabel: json['dateLabel'] as String,
        folderId: json['folderId'] as String?,
        kind: DocumentKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => DocumentKind.normal,
        ),
        path: json['path'] as String?,
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
  HomeController() : super(HomeState(documents: const [], folders: const [], isLoading: true)) {
    _load();
  }

  final _store = HomeLocalDataSource();
  void addDocument(String title, DocumentKind kind,
      {String? folderId, String? path, String? sizeOverride}) {
    final computedSize = sizeOverride ??
        (path != null ? _fileSize(path) : '${_randomSize()} MB');
    final newDoc = DocumentItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      size: computedSize,
      dateLabel: 'Just now',
      kind: kind,
      folderId: folderId,
      path: path,
    );

    state = state.copyWith(
      documents: [newDoc, ...state.documents],
      folders: state.folders
          .map(
            (f) => f.id == folderId ? f.copyWith(count: f.count + 1) : f,
          )
          .toList(),
    );
    _persist();
  }

  void addFolder(String name) {
    final folder = Folder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      count: 0,
    );
    state = state.copyWith(folders: [folder, ...state.folders]);
    _persist();
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
      final (docs, folders) = await _store.load();
      if (docs.isEmpty && folders.isEmpty) {
        // seed default data
        state = HomeState(
          documents: [
            DocumentItem(
              id: '1',
              title: 'Welcome.pdf',
              size: '0.4 MB',
              dateLabel: 'Just now',
              kind: DocumentKind.normal,
            ),
            DocumentItem(
              id: '2',
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

  Future<void> _persist() async {
    await _store.save(state.documents, state.folders);
  }
}
