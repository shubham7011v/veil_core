import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../features/session/presentation/bloc/session_bloc.dart';
import '../../../../features/session/presentation/bloc/session_event.dart';
import '../../../../features/session/presentation/bloc/session_state.dart';
import '../../../../core/di/service_locator.dart' as di;

class ChatWidget extends StatefulWidget {
  final VoidCallback onClose;

  const ChatWidget({super.key, required this.onClose});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final bool _isAutoScrolling = true;
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String value) {
    if (!_isTyping && value.trim().isNotEmpty) {
      _isTyping = true;
      context.read<SessionBloc>().add(const SendTypingStatus(true));
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        context.read<SessionBloc>().add(const SendTypingStatus(false));
      }
    });

    if (value.trim().isEmpty && _isTyping) {
      _isTyping = false;
      context.read<SessionBloc>().add(const SendTypingStatus(false));
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      context.read<SessionBloc>().add(SendChatMessage(text));
      _controller.clear();
      _scrollToBottom();

      // Reset typing status
      if (_isTyping) {
        _isTyping = false;
        _typingTimer?.cancel();
        context.read<SessionBloc>().add(const SendTypingStatus(false));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100, // Add explicit offset
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xCC0F172A);
    const surfaceColor = Color(0xFF1E293B);
    const textColor = Color(0xFFF1F5F9);
    const hintColor = Color(0xFF94A3B8);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 320,
        height: 400,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryDim.withValues(alpha: 0.5),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Game Chat',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: textColor, size: 20),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Message List
            Expanded(
              child: BlocBuilder<SessionBloc, SessionBlocState>(
                builder: (context, state) {
                  final messages = state.chatMessages
                      .where((m) => m['type'] == 'chat')
                      .toList();

                  final typingUsers = state.typingStatus.entries
                      .where(
                        (e) =>
                            e.value &&
                            e.key != di.sl.authRepository.currentUser?.uid,
                      )
                      .map((e) => state.getPlayerName(e.key))
                      .toList();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_isAutoScrolling) {
                      _scrollToBottom();
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount:
                        messages.length + (typingUsers.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            '${typingUsers.join(", ")} ${typingUsers.length > 1 ? "are" : "is"} typing...',
                            style: TextStyle(
                              color: hintColor.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }

                      final msg = messages[index];
                      final myId = di.sl.authRepository.currentUser?.uid;
                      final bool isFromMe =
                          msg['isMe'] == true ||
                          msg['senderId'] == 'me' ||
                          msg['senderId'] == myId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: isFromMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: isFromMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              children: [
                                Text(
                                  msg['senderName'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatTime(msg['time']),
                                  style: TextStyle(
                                    color: hintColor,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isFromMe
                                    ? AppColors.primaryDim
                                    : surfaceColor,
                                borderRadius: BorderRadius.circular(12)
                                    .copyWith(
                                      topLeft: isFromMe
                                          ? const Radius.circular(12)
                                          : const Radius.circular(2),
                                      bottomRight: isFromMe
                                          ? const Radius.circular(2)
                                          : const Radius.circular(12),
                                    ),
                              ),
                              child: Text(
                                msg['message'] ?? '',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Input Area
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: textColor, fontSize: 14),
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: hintColor),
                        filled: true,
                        fillColor: bgColor,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _sendMessage,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch((timestamp as int) * 1000);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}
