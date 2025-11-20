import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/bot_chat_controller.dart';
import '../state/bots_state.dart';
import '../../../app_theme.dart';

class BotChatPage extends ConsumerStatefulWidget {
  const BotChatPage({super.key, required this.bot});

  final Bot bot;

  @override
  ConsumerState<BotChatPage> createState() => _BotChatPageState();
}

class _BotChatPageState extends ConsumerState<BotChatPage> {
  final _scrollController = ScrollController();
  int _lastCount = 0;

  void _scrollToBottom(List<BotChatMessage> messages) {
    if (messages.length == _lastCount) return;
    _lastCount = messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(botChatControllerProvider(widget.bot.id));
    final controller = ref.read(
      botChatControllerProvider(widget.bot.id).notifier,
    );
    _scrollToBottom(state.messages);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bot.name),
        backgroundColor: colors.surface,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(Theme.of(context).colorScheme),
        ),
        child: Column(
          children: [
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final m = state.messages[index];
                        final isUser = m.isUser;
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? colors.primary.withValues(alpha: 0.2)
                                  : colors.onSurface.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colors.onSurface.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Text(
                              m.text,
                              style: TextStyle(
                                color: colors.onSurface.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _BotChatInput(onSend: controller.send),
          ],
        ),
      ),
    );
  }
}

class _BotChatInput extends StatefulWidget {
  const _BotChatInput({required this.onSend});
  final Future<void> Function(String) onSend;

  @override
  State<_BotChatInput> createState() => _BotChatInputState();
}

class _BotChatInputState extends State<_BotChatInput> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend(ColorScheme colors) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await widget.onSend(text);
    } catch (_) {
      _controller.text = text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          top: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Message this bot...',
                filled: true,
                fillColor: colors.onSurface.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colors.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.primary),
                ),
              ),
              style: TextStyle(color: colors.onSurface),
              onSubmitted: (_) => _handleSend(colors),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: colors.primary,
            child: IconButton(
              icon: _sending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onSurface,
                      ),
                    )
                  : Icon(Icons.send_rounded, color: colors.onSurface),
              onPressed: _sending ? null : () => _handleSend(colors),
            ),
          ),
        ],
      ),
    );
  }
}
