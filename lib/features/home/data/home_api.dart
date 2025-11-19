import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../config/app_config.dart';
import '../../../data/local_storage.dart';

class HomeApi {
  HomeApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _storage = LocalStorage();

  Future<List<Map<String, dynamic>>> fetchDocuments({String? folderId}) async {
    final base = Uri.parse('${AppConfig.apiBase}/documents');
    final uri = folderId == null || folderId.isEmpty
        ? base
        : base.replace(queryParameters: {'folder_id': folderId});
    final cookie = await _storage.getSessionCookie();
    final res = await _client.get(uri, headers: _headers(cookie));
    _debugLog('documents.fetch', res);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data.whereType<Map<String, dynamic>>().toList();
    }
    throw HomeApiException(
      'Failed to load documents (${res.statusCode})',
    );
  }

  Future<List<Map<String, dynamic>>> fetchFolders() async {
    final uri = Uri.parse('${AppConfig.apiBase}/folders');
    final cookie = await _storage.getSessionCookie();
    final res = await _client.get(uri, headers: _headers(cookie));
    _debugLog('folders.fetch', res);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data.whereType<Map<String, dynamic>>().toList();
    }
    throw HomeApiException('Failed to load folders (${res.statusCode})');
  }

  Future<Map<String, dynamic>> createFolder(String name,
      {String? color}) async {
    final uri = Uri.parse('${AppConfig.apiBase}/folders');
    final cookie = await _storage.getSessionCookie();
    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ..._headers(cookie),
      },
      body: jsonEncode({
        'name': name,
        if (color != null && color.isNotEmpty) 'color': color,
      }),
    );
    _debugLog('folders.create', res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? {};
    }
    throw HomeApiException('Failed to create folder (${res.statusCode})');
  }

  Future<Map<String, dynamic>> uploadDocument({
    required String name,
    required String type,
    required File file,
    String? folderId,
    String? geminiText,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/documents');
    final cookie = await _storage.getSessionCookie();
    final request = http.MultipartRequest('POST', uri);
    if (cookie != null) {
      request.headers['Cookie'] = cookie;
    }
    request.fields['name'] = name;
    request.fields['type'] = type;
    if (folderId != null && folderId.isNotEmpty) {
      request.fields['folder_id'] = folderId;
    }
    if (geminiText != null && geminiText.isNotEmpty) {
      request.fields['gemini_text'] = geminiText;
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    _debugLog('documents.upload', res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? {};
    }
    throw HomeApiException('Failed to upload (${res.statusCode})');
  }

  Future<Map<String, dynamic>> updateFolder(String id, String name) async {
    final uri = Uri.parse('${AppConfig.apiBase}/folders/$id');
    final cookie = await _storage.getSessionCookie();
    final res = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ..._headers(cookie),
      },
      body: jsonEncode({'name': name}),
    );
    _debugLog('folders.update', res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return decoded['data'] as Map<String, dynamic>? ?? {};
    }
    throw HomeApiException('Failed to update folder (${res.statusCode})');
  }

  Future<void> deleteFolder(String id) async {
    final uri = Uri.parse('${AppConfig.apiBase}/folders/$id');
    final cookie = await _storage.getSessionCookie();
    final res = await _client.delete(uri, headers: _headers(cookie));
    _debugLog('folders.delete', res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw HomeApiException('Failed to delete folder (${res.statusCode})');
  }

  Future<Map<String, dynamic>> updateDocument(
    String documentId, {
    String? name,
    String? folderId,
    String? geminiText,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/documents/$documentId');
    final cookie = await _storage.getSessionCookie();
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (folderId != null) 'folder_id': folderId,
      if (geminiText != null) 'gemini_text': geminiText,
    };
    final res = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ..._headers(cookie),
      },
      body: jsonEncode(body),
    );
    _debugLog('documents.update', res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return decoded['data'] as Map<String, dynamic>? ?? {};
    }
    throw HomeApiException('Failed to update (${res.statusCode})');
  }

  Future<void> deleteDocument(String documentId) async {
    final uri = Uri.parse('${AppConfig.apiBase}/documents/$documentId');
    final cookie = await _storage.getSessionCookie();
    final res = await _client.delete(uri, headers: _headers(cookie));
    _debugLog('documents.delete', res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw HomeApiException('Failed to delete (${res.statusCode})');
  }

  Future<Map<String, dynamic>> fetchDocument(String documentId) async {
    final uri = Uri.parse('${AppConfig.apiBase}/documents/$documentId');
    final cookie = await _storage.getSessionCookie();
    final res = await _client.get(uri, headers: _headers(cookie));
    _debugLog('documents.show', res);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? {};
    }
    throw HomeApiException('Failed to load document (${res.statusCode})');
  }

  Map<String, String> _headers(String? cookie) {
    return {
      if (cookie != null) 'Cookie': cookie,
    };
  }

  void _debugLog(String tag, http.Response response) {
    // ignore: avoid_print
    print(
      '[api:$tag] status=${response.statusCode} body=${response.body}',
    );
  }
}

class HomeApiException implements Exception {
  HomeApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
