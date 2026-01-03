import 'package:flutter/material.dart';

class SessionHistoryList extends StatelessWidget {
  const SessionHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    // This would normally come from the bloc/handler
    // For now, keeping it as a placeholder or implementing simple log
    return const Center(
      child: Text(
        "NO HISTORY YET",
        style: TextStyle(color: Colors.white24, fontSize: 12),
      ),
    );
  }
}
