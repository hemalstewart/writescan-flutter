import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../state/bots_state.dart';

class BotsLocalDataSource {
  static const _botsKey = 'bots_data';

  Future<List<Bot>> loadBots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_botsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => Bot.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveBots(List<Bot> bots) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _botsKey,
      jsonEncode(bots.map((b) => b.toJson()).toList()),
    );
  }
}
