import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/general_chat_api.dart';

class ChatMessage {
  ChatMessage({
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

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final text = json['text'] ?? json['content'] ?? '';
    final createdAt = json['created_at'] ?? json['timestamp'];
    final role = json['role'] as String?;
    final isUser = json['isUser'] as bool? ?? (role == 'user');
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      text: text as String,
      isUser: isUser,
      timestamp:
          DateTime.tryParse((createdAt ?? '') as String) ?? DateTime.now(),
    );
  }
}

class GeneralChatState {
  const GeneralChatState({
    required this.messages,
    this.isLoading = true,
    this.isSending = false,
  });
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;

  GeneralChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
  }) {
    return GeneralChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
    );
  }
}

final generalChatControllerProvider =
    StateNotifierProvider<GeneralChatController, GeneralChatState>((ref) {
      return GeneralChatController();
    });

class GeneralChatController extends StateNotifier<GeneralChatState> {
  GeneralChatController()
    : super(const GeneralChatState(messages: [], isLoading: true)) {
    _load();
  }

  static const _messagesKey = 'general_chat_messages';
  final _api = GeneralChatApi();

  Future<void> _load() async {
    try {
      try {
        final remote = await _api.fetchMessages();
        final msgs = remote
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = state.copyWith(messages: msgs, isLoading: false);
        await _save(msgs);
        return;
      } catch (_) {
        // ignore and fallback
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_messagesKey);
      if (raw == null) {
        final seed = [
          ChatMessage(
            id: 'seed1',
            text: 'Hi! What can you do?',
            isUser: true,
            timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          ChatMessage(
            id: 'seed2',
            text: 'I can summarize scans, draft emails, and answer questions.',
            isUser: false,
            timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
          ),
        ];
        state = GeneralChatState(messages: seed, isLoading: false);
        await _save(seed);
      } else {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final msgs = decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = state.copyWith(messages: msgs, isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMsg = ChatMessage(
      id: tempId,
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, tempMsg],
      isSending: true,
    );
    await _save(state.messages);
    // ignore: avoid_print
    print('[generalChat] send -> "${text.trim()}"');

    try {
      final apiMsg = await _api.sendMessage(text.trim());
      final created = apiMsg.isNotEmpty
          ? ChatMessage.fromJson(Map<String, dynamic>.from(apiMsg))
          : null;

      var msgs = List<ChatMessage>.from(state.messages);
      msgs.removeWhere((m) => m.id == tempId);
      if (created != null) msgs.add(created);
      state = state.copyWith(messages: msgs, isSending: false);
      await _save(msgs);
      // pull latest from backend to catch assistant replies
      await _load();
      // ignore: avoid_print
      print('[generalChat] send success (messages=${msgs.length})');
    } catch (e) {
      // keep optimistic message
      // ignore: avoid_print
      print('[generalChat] send error: $e');
      state = state.copyWith(isSending: false);
    }
  }

  Future<void> clear() async {
    final previous = List<ChatMessage>.from(state.messages);
    state = state.copyWith(messages: []);
    await _save(const []);
    try {
      await _api.clearConversation();
    } catch (e) {
      state = state.copyWith(messages: previous);
      await _save(previous);
      rethrow;
    }
  }

  Future<void> _save(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _messagesKey,
      jsonEncode(messages.map((m) => m.toJson()).toList()),
    );
  }
}
