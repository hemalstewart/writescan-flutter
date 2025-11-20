import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/app_config.dart';
import '../../../data/local_storage.dart';

class GeneralChatApi {
  final _client = http.Client();

  Future<List<Map<String, dynamic>>> fetchMessages() async {
    final uri = Uri.parse('${AppConfig.apiBase}/general-chat');
    final cookie = await LocalStorage().getSessionCookie();
    final res = await _client.get(
      uri,
      headers: {if (cookie != null) 'Cookie': cookie},
    );
    // ignore: avoid_print
    print('[api:generalChat.fetch] status=${res.statusCode} body=${res.body}');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      return data.whereType<Map<String, dynamic>>().toList();
    }
    throw GeneralChatApiException('Failed to load chat (${res.statusCode})');
  }

  Future<Map<String, dynamic>> sendMessage(
    String content, {
    bool isUser = true,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/general-chat');
    final cookie = await LocalStorage().getSessionCookie();
    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (cookie != null) 'Cookie': cookie,
      },
      body: jsonEncode({
        'role': isUser ? 'user' : 'assistant',
        'type': 'text',
        'content': content,
      }),
    );
    // ignore: avoid_print
    print('[api:generalChat.send] status=${res.statusCode} body=${res.body}');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? {};
    }
    throw GeneralChatApiException('Failed to send (${res.statusCode})');
  }

  Future<void> clearConversation() async {
    final uri = Uri.parse('${AppConfig.apiBase}/general-chat');
    final cookie = await LocalStorage().getSessionCookie();
    final res = await _client.delete(
      uri,
      headers: {if (cookie != null) 'Cookie': cookie},
    );
    // ignore: avoid_print
    print('[api:generalChat.clear] status=${res.statusCode} body=${res.body}');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw GeneralChatApiException('Failed to clear (${res.statusCode})');
  }
}

class GeneralChatApiException implements Exception {
  GeneralChatApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
