import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/app_config.dart';
import '../../../data/local_storage.dart';

class BotMessagesApi {
  final _client = http.Client();

  Future<List<Map<String, dynamic>>> fetchMessages(String botId) async {
    final cookie = await LocalStorage().getSessionCookie();
    final uri = Uri.parse('${AppConfig.apiBase}/bots/$botId/messages');
    final res = await _client.get(uri, headers: {
      if (cookie != null) 'Cookie': cookie,
    });
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data.whereType<Map<String, dynamic>>().toList();
    }
    throw BotMessagesApiException('Failed to load messages (${res.statusCode})');
  }

  Future<Map<String, dynamic>> sendMessage(String botId, String message) async {
    final cookie = await LocalStorage().getSessionCookie();
    final uri = Uri.parse('${AppConfig.apiBase}/bots/$botId/messages');
    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (cookie != null) 'Cookie': cookie,
      },
      body: jsonEncode({'message': message}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? {};
    }
    throw BotMessagesApiException('Failed to send (${res.statusCode})');
  }
}

class BotMessagesApiException implements Exception {
  BotMessagesApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
