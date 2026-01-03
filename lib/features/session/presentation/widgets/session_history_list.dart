import 'package:flutter/material.dart';

class SessionHistoryList extends StatelessWidget {
  final List<String> gameLog;

  const SessionHistoryList({super.key, required this.gameLog});

  @override
  Widget build(BuildContext context) {
    if (gameLog.isEmpty) {
      return const Center(
        child: Text(
          "NO HISTORY YET",
          style: TextStyle(color: Colors.white24, fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: gameLog.length,
      separatorBuilder: (context, index) =>
          const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final entry = gameLog[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6, right: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  entry,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
