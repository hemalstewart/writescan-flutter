import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/bots_api.dart';
import '../data/bots_local_data_source.dart';
import '../../home/data/home_api.dart';
import '../../home/state/home_state.dart';

class Bot {
  Bot({
    required this.id,
    required this.name,
    this.source = '',
    this.tags = const [],
    this.documentId,
    this.documentName,
    this.summary,
  });

  final String id;
  final String name;
  final String source;
  final List<String> tags;
  final String? documentId;
  final String? documentName;
  final String? summary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source,
        'tags': tags,
        'document_id': documentId,
        'document_name': documentName,
        'summary': summary,
      };

  factory Bot.fromJson(Map<String, dynamic> json) {
    final document = json['document'] as Map<String, dynamic>?;
    final docName =
        document?['name'] ?? document?['title'] ?? json['document_name'];
    return Bot(
      id: _string(json['id'] ?? json['bot_id']),
      name: _string(json['name'] ?? document?['name'] ?? 'Bot'),
      source: _string(
        json['source'] ??
            document?['source'] ??
            docName ??
            json['description'] ??
            '',
      ),
      tags: (json['tags'] as List<dynamic>? ?? document?['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      documentId: _nullableString(
        json['document_id'] ?? document?['id'] ?? document?['document_id'],
      ),
      documentName: _nullableString(docName),
      summary: _nullableString(json['summary'] ?? document?['summary']),
    );
  }
}

class BotsState {
  BotsState({
    required this.bots,
    this.isLoading = true,
    this.isImporting = false,
  });

  final List<Bot> bots;
  final bool isLoading;
  final bool isImporting;

  BotsState copyWith({
    List<Bot>? bots,
    bool? isLoading,
    bool? isImporting,
  }) {
    return BotsState(
      bots: bots ?? this.bots,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
    );
  }
}

final botsControllerProvider =
    StateNotifierProvider<BotsController, BotsState>((ref) {
  return BotsController();
});

class BotsController extends StateNotifier<BotsState> {
  BotsController() : super(BotsState(bots: const [], isLoading: true)) {
    _load();
  }

  final _api = BotsApi();
  final _homeApi = HomeApi();
  final _local = BotsLocalDataSource();

  Future<void> importFromPath(String path, {String? name}) async {
    final file = _resolveFile(path);
    if (!file.existsSync()) {
      throw BotsException('File not found on device');
    }
    final label = name ?? _friendlyName(file.path);
    state = state.copyWith(isImporting: true);
    try {
      final upload = await _homeApi.uploadDocument(
        name: label,
        type: _typeForUpload(file.path),
        file: file,
      );
      final documentId = _nullableString(
        upload['document_id'] ?? upload['id'] ?? upload['uuid'],
      );
      if (documentId == null) {
        throw BotsException('Upload succeeded but document ID missing');
      }
      await _api.createBot(documentId: documentId, name: label);
      await _loadRemote();
      state = state.copyWith(isImporting: false);
    } catch (error) {
      state = state.copyWith(isImporting: false);
      throw BotsException(_messageFromError(error));
    }
  }

  Future<Bot> createBotFromDocument(String documentId, {String? name}) async {
    state = state.copyWith(isImporting: true);
    try {
      final response = await _api.createBot(documentId: documentId, name: name);
      final bot = Bot.fromJson(Map<String, dynamic>.from(response));
      await _loadRemote();
      return bot;
    } catch (error) {
      throw BotsException(_messageFromError(error));
    } finally {
      state = state.copyWith(isImporting: false);
    }
  }

  Future<void> deleteBot(String id) async {
    final current = List<Bot>.from(state.bots);
    final idx = current.indexWhere((b) => b.id == id);
    if (idx == -1) return;
    final removed = current.removeAt(idx);
    state = state.copyWith(bots: current);
    await _save(current);
    try {
      await _api.deleteBot(id);
    } catch (error) {
      final reverted = List<Bot>.from(state.bots);
      final insertIndex = idx <= reverted.length ? idx : reverted.length;
      reverted.insert(insertIndex, removed);
      state = state.copyWith(bots: reverted);
      await _save(reverted);
      throw BotsException(_messageFromError(error));
    }
  }

  Future<void> _load() async {
    try {
      await _loadRemote();
    } catch (_) {
      await _loadLocal();
    }
  }

  Future<void> _loadRemote() async {
    try {
      final remote = await _api.fetchBots();
      final bots = remote
          .map((e) => Bot.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(bots: bots, isLoading: false);
      await _save(bots);
    } catch (error) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> _loadLocal() async {
    try {
      final cached = await _local.loadBots();
      if (cached.isEmpty) {
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(bots: cached, isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _save(List<Bot> bots) => _local.saveBots(bots);

  File _resolveFile(String rawPath) {
    if (rawPath.startsWith('file://')) {
      return File(Uri.parse(rawPath).toFilePath());
    }
    return File(rawPath);
  }
}

class BotsException implements Exception {
  BotsException(this.message);
  final String message;

  @override
  String toString() => message;
}

String _friendlyName(String path) {
  final base = p.basename(path);
  return base.isEmpty ? 'Document' : base;
}

String _typeForUpload(String path) {
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
  return 'pdf';
}

String _string(dynamic value) => value?.toString() ?? '';

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  if (str.isEmpty) return null;
  return str;
}

String _messageFromError(Object error) {
  if (error is BotsException) return error.message;
  if (error is BotsApiException) return error.message;
  if (error is HomeException) return error.message;
  if (error is HomeApiException) return error.message;
  return error.toString();
}
