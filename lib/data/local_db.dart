import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../features/home/state/home_state.dart';

class LocalDb {
  static const _dbName = 'writescan.db';
  static const _docsTable = 'documents';

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_docsTable(
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<List<DocumentItem>> loadDocuments() async {
    final db = await _open();
    final rows = await db.query(_docsTable);
    final docs = <DocumentItem>[];
    for (final row in rows) {
      final data = row['data'] as String?;
      if (data == null) continue;
      final map = jsonDecode(data) as Map<String, dynamic>;
      docs.add(DocumentItem.fromJson(map));
    }
    return docs;
  }

  Future<void> saveDocuments(List<DocumentItem> docs) async {
    final db = await _open();
    final batch = db.batch();
    await db.delete(_docsTable);
    for (final doc in docs) {
      batch.insert(
        _docsTable,
        {
          'id': doc.id,
          'data': jsonEncode(doc.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertDocument(DocumentItem doc) async {
    final db = await _open();
    await db.insert(
      _docsTable,
      {
        'id': doc.id,
        'data': jsonEncode(doc.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
