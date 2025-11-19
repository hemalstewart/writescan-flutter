import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/app_config.dart';
import '../../../data/local_storage.dart';

class BotsApi {
  final _client = http.Client();

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
}

class BotsApiException implements Exception {
  BotsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
