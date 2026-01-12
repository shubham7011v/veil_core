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

    return Container(
      constraints: BoxConstraints(
        maxHeight: _isExpanded ? 200 : 60,
        maxWidth: 280,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textTertiary.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 14, color: Color(0xFFFFD700)),
                  const SizedBox(width: 6),
                  Text(
                    _isExpanded ? "MATCH LOG" : "LAST ACTION",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 16,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),

          // Content
          if (_isExpanded)
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
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Text(
                widget.gameLog.first,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
