import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/session_provider.dart';

class HistoryFeed extends StatelessWidget {
  const HistoryFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, provider, child) {
        final logs = provider.gameLog;
        if (logs.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          height: 100,
          width: 250,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
            ),
          ),
          child: ListView.builder(
            itemCount: logs.length,
            padding: EdgeInsets.zero,
            physics:
                const NeverScrollableScrollPhysics(), // Scroll handled by view or small count
            itemBuilder: (context, index) {
              // Dim older logs
              final opacity = (1.0 - (index * 0.2)).clamp(0.2, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        logs[index],
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: opacity),
                          fontSize: 12,
                          fontWeight: index == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          shadows: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
