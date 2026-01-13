import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

class CompactMatchLog extends StatefulWidget {
  final List<String> gameLog;

  const CompactMatchLog({super.key, required this.gameLog});

  @override
  State<CompactMatchLog> createState() => _CompactMatchLogState();
}

class _CompactMatchLogState extends State<CompactMatchLog> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.gameLog.isEmpty) {
      return const SizedBox.shrink();
    }

    // ✅ FIX: Hide overlay when collapsed to not cover cards
    if (!_isExpanded) {
      return Positioned(
        bottom: 16,
        left: 16,
        child: IconButton(
          icon: const Icon(Icons.history, color: Color(0xFFFFD700), size: 20),
          onPressed: () => setState(() => _isExpanded = true),
          tooltip: 'Show Match Log',
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textTertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 14, color: Color(0xFFFFD700)),
                  const SizedBox(width: 6),
                  const Text(
                    "MATCH LOG",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              reverse: true, // Latest at bottom
              itemCount: widget.gameLog.length.clamp(0, 10),
              itemBuilder: (context, index) {
                final log = widget.gameLog[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    "• $log",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
