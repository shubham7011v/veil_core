import 'dart:async';
import 'package:flutter/material.dart';
import 'intro_mood_page.dart';
import 'intro_hint_page.dart';
import 'intro_entry_page.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 3000), () {
      if (_currentPage < 2) {
        // Advance from page 0 and 1 only
        _pageController.nextPage(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
          if (index < 2) {
            // Only auto-advance if not on the last page
            _startAutoAdvance();
          } else {
            _autoAdvanceTimer?.cancel();
          }
        },
        children: const [IntroMoodPage(), IntroHintPage(), IntroEntryPage()],
      ),
    );
  }
}
