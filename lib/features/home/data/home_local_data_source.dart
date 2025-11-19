import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../state/home_state.dart';

class HomeLocalDataSource {
  static const _docsKey = 'home_documents';
  static const _foldersKey = 'home_folders';

  Future<void> save(List<DocumentItem> docs, List<Folder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _docsKey,
      jsonEncode(docs.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _foldersKey,
      jsonEncode(folders.map((e) => e.toJson()).toList()),
    );
  }

  Future<(List<DocumentItem>, List<Folder>)> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDocs = prefs.getString(_docsKey);
    final rawFolders = prefs.getString(_foldersKey);

    final docs = <DocumentItem>[];
    final folders = <Folder>[];

    if (rawDocs != null) {
      final decoded = jsonDecode(rawDocs) as List<dynamic>;
      docs.addAll(
        decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => DocumentItem.fromJson(
                  Map<String, dynamic>.from(e),
                )),
      );
    }

    if (rawFolders != null) {
      final decoded = jsonDecode(rawFolders) as List<dynamic>;
      folders.addAll(
        decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => Folder.fromJson(Map<String, dynamic>.from(e))),
      );
    }

    return (docs, folders);
  }
}
