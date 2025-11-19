import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/app_config.dart';
import '../../../data/local_storage.dart';

class BotsApi {
  BotsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Map<String, dynamic>>> fetchBots() async {
    final uri = Uri.parse('${AppConfig.apiBase}/bots');
    final cookie = await LocalStorage().getSessionCookie();
    final res = await _client.get(uri, headers: {
      if (cookie != null) 'Cookie': cookie,
    });
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data.whereType<Map<String, dynamic>>().toList();
    }
    throw BotsApiException('Failed to load bots (${res.statusCode})');
  }

  Future<Map<String, dynamic>> createBot({
    required String documentId,
    String? name,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/bots');
    final cookie = await LocalStorage().getSessionCookie();
    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (cookie != null) 'Cookie': cookie,
      },
      body: jsonEncode({
        'document_id': documentId,
        if (name != null && name.isNotEmpty) 'name': name,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? {};
    }
    throw BotsApiException('Failed to create bot (${res.statusCode})');
  }

  Future<void> deleteBot(String botId) async {
    final uri = Uri.parse('${AppConfig.apiBase}/bots/$botId');
    final cookie = await LocalStorage().getSessionCookie();
    final res = await _client.delete(uri, headers: {
      if (cookie != null) 'Cookie': cookie,
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw BotsApiException('Failed to delete bot (${res.statusCode})');
  }
}

class BotsApiException implements Exception {
  BotsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
