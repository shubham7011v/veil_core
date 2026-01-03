import 'package:flutter/material.dart';
import '../bloc/session_state.dart';
import 'participant_avatar.dart';

class OpponentCarousel extends StatefulWidget {
  final SessionBlocState state;
  final Map<String, GlobalKey> avatarKeys;

  const OpponentCarousel({
    super.key,
    required this.state,
    required this.avatarKeys,
  });

  @override
  State<OpponentCarousel> createState() => _OpponentCarouselState();
}

class _OpponentCarouselState extends State<OpponentCarousel> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(OpponentCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollToActive();
  }

  void _scrollToActive() {
    final participants = widget.state.engineState.participants
        .where((p) => p.id != 'me')
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final activeIdx = participants.indexWhere((p) => p.isActive);
        if (activeIdx != -1) {
          const double itemWidth = 85.0; // 65 size + padding
          final double screenWidth = MediaQuery.of(context).size.width;
          final double offset =
              (activeIdx * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

          _scrollController.animateTo(
            offset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final participants = widget.state.engineState.participants
        .where((p) => p.id != 'me')
        .toList();

    return SizedBox(
      height: 100,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final p = participants[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ParticipantAvatar(
              key: widget.avatarKeys[p.id],
              participant: p,
              size: 65,
            ),
          );
        },
      ),
    );
  }
}
