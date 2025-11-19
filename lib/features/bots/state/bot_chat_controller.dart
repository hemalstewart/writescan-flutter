import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bot_messages_api.dart';

class BotChatMessage {
  BotChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory BotChatMessage.fromJson(Map<String, dynamic> json) {
    final text = json['text'] ?? json['content'] ?? '';
    final createdAt = json['created_at'] ?? json['timestamp'];
    final role = json['role'] as String?;
    final isUser = json['isUser'] as bool? ?? (role == 'user');
    return BotChatMessage(
      id: (json['id'] ?? '').toString(),
      text: text as String,
      isUser: isUser,
      timestamp:
          DateTime.tryParse((createdAt ?? '') as String) ?? DateTime.now(),
    );
  }
}

class BotChatState {
  const BotChatState({required this.messages, this.isLoading = true});
  final List<BotChatMessage> messages;
  final bool isLoading;

  BotChatState copyWith({
    List<BotChatMessage>? messages,
    bool? isLoading,
  }) {
    return BotChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final botChatControllerProvider = StateNotifierProviderFamily<
    BotChatController,
    BotChatState,
    String>((ref, botId) {
  return BotChatController(botId);
});

class BotChatController extends StateNotifier<BotChatState> {
  BotChatController(this.botId)
      : super(const BotChatState(messages: [], isLoading: true)) {
    _load();
  }

  final String botId;
  late final String _storageKey = 'bot_chat_$botId';
  final _api = BotMessagesApi();

  Future<void> _load() async {
    try {
      try {
        final remote = await _api.fetchMessages(botId);
        final msgs = remote
            .map((e) => BotChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = state.copyWith(messages: msgs, isLoading: false);
        await _save(msgs);
        return;
      } catch (_) {
        // ignore and fallback to local cache
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      final msgs = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => BotChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(messages: msgs, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMsg = BotChatMessage(
      id: tempId,
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, tempMsg]);
    await _save(state.messages);

    try {
      final result = await _api.sendMessage(botId, text.trim());
      final assistant = result['assistant'] as Map<String, dynamic>?;
      final userMap = result['user'] as Map<String, dynamic>?;

      final newMessages = <BotChatMessage>[];
      if (userMap != null) {
        newMessages.add(
            BotChatMessage.fromJson(Map<String, dynamic>.from(userMap)));
      }
      if (assistant != null) {
        newMessages.add(
            BotChatMessage.fromJson(Map<String, dynamic>.from(assistant)));
      }
      if (newMessages.isNotEmpty) {
        var msgs = List<BotChatMessage>.from(state.messages);
        msgs.removeWhere((m) => m.id == tempId);
        msgs.addAll(newMessages);
        state = state.copyWith(messages: msgs);
        await _save(msgs);
      }
    } catch (_) {
      // keep optimistic message if API fails
    }
  }

  Future<void> _save(List<BotChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(messages.map((m) => m.toJson()).toList()),
    );
  }
}
