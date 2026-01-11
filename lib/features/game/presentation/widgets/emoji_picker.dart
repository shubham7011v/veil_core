import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../features/session/presentation/bloc/session_bloc.dart';
import '../../../../features/session/presentation/bloc/session_event.dart';

class EmojiPicker extends StatelessWidget {
  final VoidCallback onClose;

  const EmojiPicker({super.key, required this.onClose});

  final List<String> emojis = const [
    '👍',
    '👎',
    '😂',
    '🔥',
    '❤️',
    '🎉',
    '😎',
    '🤔',
    '👀',
    '😡',
    '😮',
    '💯',
  ];

  void _onEmojiSelected(BuildContext context, String emoji) {
    context.read<SessionBloc>().add(SendEmojiMessage(emoji));
    onClose();
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xCC0F172A);
    const surfaceColor = Color(0xFF1E293B);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reaction',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Color(0xFFF1F5F9),
                    size: 20,
                  ),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                final emoji = emojis[index];
                return InkWell(
                  onTap: () => _onEmojiSelected(context, emoji),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
