import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/general_chat_state.dart';
import '../../../app_theme.dart';

class GeneralChatScreen extends ConsumerStatefulWidget {
  const GeneralChatScreen({super.key});

  @override
  ConsumerState<GeneralChatScreen> createState() => _GeneralChatScreenState();
}

class _GeneralChatScreenState extends ConsumerState<GeneralChatScreen> {
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;
  bool _clearing = false;

  void _scrollToBottom(List<ChatMessage> messages) {
    if (messages.length == _lastMessageCount) return;
    _lastMessageCount = messages.length;
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
    final state = ref.watch(generalChatControllerProvider);
    final controller = ref.read(generalChatControllerProvider.notifier);
    _scrollToBottom(state.messages);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(Theme.of(context).colorScheme),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'General Chat',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    _clearing
                        ? SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),
                          )
                        : PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),
                            onSelected: (value) {
                              if (value == 'clear') {
                                _confirmClear(controller);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'clear',
                                child: Text('Clear conversation'),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                  color: colors.onSurface.withValues(
                                    alpha: 0.06,
                                  ),
                                ),
                              ),
                              child: Text(
                                m.text,
                                style: TextStyle(
                                  color: colors.onSurface.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (state.isSending)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Assistant is replying...',
                          style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _ChatInput(onSend: controller.send),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(GeneralChatController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('All general chat messages will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _clearing = true);
    try {
      await controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat cleared')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }
}

class _ChatInput extends StatefulWidget {
  const _ChatInput({required this.onSend});
  final Future<void> Function(String) onSend;

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
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
        color: AppTheme.panelColor(colors),
        border: Border(top: BorderSide(color: AppTheme.panelBorder(colors))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask anything...',
                filled: true,
                fillColor: AppTheme.panelColor(colors),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.panelBorder(colors)),
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
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.send_rounded, color: colors.onPrimary),
              onPressed: _sending ? null : () => _handleSend(colors),
            ),
          ),
        ],
      ),
    );
  }
}
