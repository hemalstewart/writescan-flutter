import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bots_api.dart';

class Bot {
  Bot({
    required this.id,
    required this.name,
    required this.source,
    required this.tags,
  });

  final String id;
  final String name;
  final String source;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source,
        'tags': tags,
      };

  factory Bot.fromJson(Map<String, dynamic> json) => Bot(
        id: json['id'] as String,
        name: json['name'] as String,
        source: json['source'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class BotsState {
  BotsState({required this.bots, this.isLoading = true});
  final List<Bot> bots;
  final bool isLoading;

  BotsState copyWith({List<Bot>? bots, bool? isLoading}) {
    return BotsState(
      bots: bots ?? this.bots,
      isLoading: isLoading ?? this.isLoading,
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

  static const _botsKey = 'bots_data';
  final _api = BotsApi();

  Future<void> _load() async {
    try {
      // Try remote first; if unauthorized or fails, fall back to local cache.
      try {
        final remote = await _api.fetchBots();
        final bots = remote
            .map((e) => Bot.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = state.copyWith(bots: bots, isLoading: false);
        await _save(bots);
        return;
      } catch (_) {
        // ignore and fallback to local
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_botsKey);
      if (raw == null) {
        final defaults = [
          Bot(
            id: 'b1',
            name: 'Legal assistant',
            source: 'Based on Contract.pdf',
            tags: ['law', 'drafting'],
          ),
          Bot(
            id: 'b2',
            name: 'Research digest',
            source: 'Research summary',
            tags: ['summaries', 'study'],
          ),
          Bot(
            id: 'b3',
            name: 'Support FAQ',
            source: 'FAQ.pdf',
            tags: ['support', 'faq'],
          ),
          Bot(
            id: 'b4',
            name: 'Product notes',
            source: 'PRD_v2.pdf',
            tags: ['product', 'release'],
          ),
        ];
        state = BotsState(bots: defaults, isLoading: false);
        await _save(defaults);
      } else {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final bots = decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => Bot.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = state.copyWith(bots: bots, isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addBot(String name, String source, List<String> tags) async {
    final bot = Bot(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      source: source,
      tags: tags,
    );
    final updated = [bot, ...state.bots];
    state = state.copyWith(bots: updated);
    await _save(updated);
  }

  Future<void> _save(List<Bot> bots) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _botsKey,
      jsonEncode(bots.map((b) => b.toJson()).toList()),
    );
  }
}
