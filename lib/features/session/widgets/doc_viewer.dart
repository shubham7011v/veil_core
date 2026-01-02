import 'package:flutter/material.dart';
import '../../../../core/utils/responsive.dart';

class DocViewer extends StatelessWidget {
  final String title;
  final List<DocSection> sections;

  const DocViewer({super.key, required this.title, required this.sections});

  static void show(
    BuildContext context, {
    required String title,
    required List<DocSection> sections,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DocViewer(title: title, sections: sections),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Responsive.screenHeight * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          // Content
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: sections.length,
              itemBuilder: (context, index) =>
                  _SectionItem(section: sections[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class DocSection {
  final String heading;
  final List<String> bulletPoints;

  DocSection({required this.heading, required this.bulletPoints});
}

class _SectionItem extends StatelessWidget {
  final DocSection section;

  const _SectionItem({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.heading.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...section.bulletPoints.map(
          (point) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "• ",
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 18),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
