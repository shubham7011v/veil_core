import 'package:flutter/material.dart';

class DocViewer extends StatelessWidget {
  final String title;
  final String content;

  const DocViewer({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFE5A043),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Text(
                content,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
