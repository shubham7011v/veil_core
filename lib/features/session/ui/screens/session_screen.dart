import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as dart_math;
import '../../../../core/utils/responsive.dart';
import '../../state/session_provider.dart';
import '../../models/unit.dart';
import '../../widgets/unit_card.dart';
import '../../widgets/participant_avatar.dart';
import '../../widgets/doc_viewer.dart';
import '../../widgets/bluff_reveal_overlay.dart';
import '../../widgets/flying_cards_layer.dart';

import '../../models/session_state.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late ScrollController _carouselController;

  final Map<String, GlobalKey> _avatarKeys = {
    'me': GlobalKey(),
    'p1': GlobalKey(),
    'p2': GlobalKey(),
    'p3': GlobalKey(),
    'p4': GlobalKey(),
    'p5': GlobalKey(),
    'p6': GlobalKey(),
    'p7': GlobalKey(),
    'p8': GlobalKey(),
    'p9': GlobalKey(),
  };
  final GlobalKey _pileKey = GlobalKey();
  final List<FlyingCard> _flyingCards = [];
  Color? _flashColor;
  final Map<String, int> _lastKnownCounts = {};

  @override
  void initState() {
    super.initState();
    _carouselController = ScrollController();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  // Animation State
  final List<Widget> _particles = []; // Overlay particles for discard effect

  void _triggerPileDiscardEffect() {
    if (mounted) {
      setState(() {
        _particles.add(
          const ParticleExplosionOverlay(
            key: ValueKey('discard'),
            color: Color(0xFFFFD700),
          ),
        );
        _particles.add(
          Positioned.fill(
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.5 + (value * 0.5),
                      child: child,
                    ),
                  );
                },
                child: const Text(
                  "PILE DISCARDED",
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    shadows: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 20,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _particles.clear();
          });
        }
      });
    }
  }

  void _handleGameEvents(SessionEventType event) {
    debugPrint("===== EVENT RECEIVED: $event =====");
    final provider = context.read<SessionProvider>();
    if (event == SessionEventType.pileDiscarded) {
      _triggerPileDiscardEffect();
    } else if (event == SessionEventType.cardsPlayed) {
      debugPrint(
        "Cards played by: ${provider.lastEventActorId}, count: ${provider.lastCountClaimed}",
      );
      // Add a small delay to ensure widgets are fully rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _triggerCardAnimation(
            sourceId: provider.lastEventActorId ?? 'me',
            targetId: 'pile',
            count: provider.lastCountClaimed,
          );
        }
      });
    } else if (event == SessionEventType.bluffResolved) {
      _triggerFlash(
        provider.isBluffSuccessful == true
            ? Colors.green.withValues(alpha: 0.4)
            : Colors.red.withValues(alpha: 0.4),
      );
    }
  }

  void _triggerFlash(Color color) {
    if (!mounted) return;
    setState(() {
      _flashColor = color;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _flashColor = null;
        });
      }
    });
  }

  void _triggerCardAnimation({
    required String sourceId,
    required String targetId,
    required int count,
  }) {
    if (!mounted) return;

    // 1. Get Start Position
    Offset startPos;
    if (sourceId == 'pile') {
      if (_pileKey.currentContext == null) return;
      final box = _pileKey.currentContext!.findRenderObject() as RenderBox;
      startPos =
          box.localToGlobal(Offset.zero) +
          Offset(box.size.width / 2, box.size.height / 2);
    } else {
      final key = _avatarKeys[sourceId];
      if (key == null || key.currentContext == null) return;
      final box = key.currentContext!.findRenderObject() as RenderBox;
      startPos =
          box.localToGlobal(Offset.zero) +
          Offset(box.size.width / 2, box.size.height / 2);
    }

    // 2. Get End Position
    Offset endPos;
    if (targetId == 'pile') {
      if (_pileKey.currentContext == null) return;
      final box = _pileKey.currentContext!.findRenderObject() as RenderBox;
      endPos =
          box.localToGlobal(Offset.zero) +
          Offset(box.size.width / 2, box.size.height / 2);
    } else {
      final key = _avatarKeys[targetId];
      if (key == null || key.currentContext == null) return;
      final box = key.currentContext!.findRenderObject() as RenderBox;
      endPos =
          box.localToGlobal(Offset.zero) +
          Offset(box.size.width / 2, box.size.height / 2);
    }

    debugPrint("Flying $count cards from $sourceId to $targetId");

    setState(() {
      _flyingCards.add(FlyingCard(start: startPos, end: endPos, count: count));
    });

    // Cleanup after animation duration
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          if (_flyingCards.isNotEmpty) _flyingCards.removeAt(0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<SessionProvider>();

    // --- Card Pickup Detection (State Diffing) ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final totalCards = provider.state.participants.fold<int>(
        0,
        (sum, p) => sum + p.unitCount,
      );

      // If everyone has 0 cards, we are likely in the "shuffle" phase of a new game.
      // Reset trackers so the subsequent "deal" triggers an increase animation.
      if (totalCards == 0 && provider.state.participants.isNotEmpty) {
        if (_lastKnownCounts.isNotEmpty) {
          debugPrint("RESETTING card count trackers for new game.");
          _lastKnownCounts.clear();
        }
        return;
      }

      for (var p in provider.state.participants) {
        final oldCount = _lastKnownCounts[p.id] ?? 0;
        final newCount = p.unitCount;

        if (newCount > oldCount) {
          final diff = newCount - oldCount;
          debugPrint(
            "DETECTED INCREASE for ${p.id}: $oldCount -> $newCount. Flying $diff cards.",
          );
          _triggerCardAnimation(sourceId: 'pile', targetId: p.id, count: diff);
        }

        if (newCount != oldCount) {
          _lastKnownCounts[p.id] = newCount;
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          _EventListenerWrapper(provider: provider, onEvent: _handleGameEvents),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [Color(0xFF2A1E17), Color(0xFF0D0D0D)],
                ),
              ),
            ),
          ),
          if (_flashColor != null)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: _flashColor,
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                // Top Bar (0.0 - 0.4)
                SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, -0.5),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _entryController,
                          curve: const Interval(
                            0.0,
                            0.4,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _entryController,
                      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
                    ),
                    child: _buildTopBar(provider),
                  ),
                ),

                // Opponents (0.1 - 0.5)
                SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, -0.2),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _entryController,
                          curve: const Interval(
                            0.1,
                            0.5,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _entryController,
                      curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
                    ),
                    child: _buildOpponentCarousel(context, provider),
                  ),
                ),
                const SizedBox(height: 10),

                // Center Pile + Claim Badge
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          ScaleTransition(
                            scale: CurvedAnimation(
                              parent: _entryController,
                              curve: const Interval(
                                0.2,
                                0.7,
                                curve: Curves.elasticOut,
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: provider.shouldShowRankSelector
                                  ? _buildRankSelector(provider)
                                  : _buildCenterPile(provider),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Staging Area (0.4 - 0.8)
                SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _entryController,
                          curve: const Interval(
                            0.4,
                            0.8,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _entryController,
                      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
                    ),
                    child: _buildStagingArea(context, provider),
                  ),
                ),
                const SizedBox(height: 4),

                // Bottom Controls (0.5 - 1.0)
                SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _entryController,
                          curve: const Interval(
                            0.5,
                            1.0,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _entryController,
                      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                    ),
                    child: _buildBottomControls(context, provider),
                  ),
                ),
              ],
            ),
          ),

          if (provider.state.currentPhase == SessionPhase.finished)
            _buildWinOverlay(context, provider),

          // Action Overlays (Flying Cards, Badges)
          Positioned.fill(
            child: IgnorePointer(
              child: FlyingCardsLayer(
                activeAnimations: _flyingCards,
                onComplete: () {},
              ),
            ),
          ),

          // Particle Layer
          ..._particles,

          if (provider.isRevealingBluff && provider.lastMove != null)
            BluffRevealOverlay(
              cards: provider.lastMove!.actualUnits,
              declaredRank: provider.lastMove!.declaredRank,
            ),
        ],
      ),
    );
  }

  Widget _buildWinOverlay(BuildContext context, SessionProvider provider) {
    final winnerName = provider.pNames[provider.state.winnerId] ?? "Someone";
    final isMe = provider.state.winnerId == 'me';

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMe ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
              size: 100,
              color: const Color(0xFFFFD700),
            ),
            const SizedBox(height: 24),
            Text(
              isMe ? "VICTORY!" : "GAME OVER",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isMe
                  ? "You have cleared all your cards!"
                  : "$winnerName has won the game.",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  "BACK TO HOME",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(SessionProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(
            Icons.menu,
            () => _showGameMenu(context, provider),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "VEIL CORE",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              Container(
                height: 2,
                width: 20,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
          _buildCircleButton(Icons.chat_bubble_outline, () {}),
        ],
      ),
    );
  }

  Widget _buildOpponentCarousel(
    BuildContext context,
    SessionProvider provider,
  ) {
    final participants = provider.state.participants
        .where((p) => p.id != 'me')
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_carouselController.hasClients) {
        final activeIdx = participants.indexWhere((p) => p.isActive);
        if (activeIdx != -1) {
          const double itemWidth = 85.0;
          final double screenWidth = MediaQuery.of(context).size.width;
          final double offset =
              (activeIdx * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
          _carouselController.animateTo(
            offset.clamp(0.0, _carouselController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    });

    return SizedBox(
      height: 100,
      child: ListView.builder(
        controller: _carouselController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final p = participants[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ParticipantAvatar(
              key: _avatarKeys[p.id],
              participant: p,
              size: 65,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCenterPile(SessionProvider provider) {
    final rankName = provider.currentRank?.name.toUpperCase() ?? "???";
    final roundStatus = provider.isRoundSet ? "${rankName}S" : "WAITING";

    return AnimatedPileView(
      key: _pileKey,
      pileCount: provider.pileCount,
      roundStatus: roundStatus,
      onTap: () {
        if (!provider.isRoundSet && provider.isMyTurn) {
          provider.toggleRankSelectionMode();
        }
      },
    );
  }

  Widget _buildRankSelector(SessionProvider provider) {
    final ranks = UnitRank.values.toList();
    String getRankSymbol(UnitRank rank) {
      switch (rank) {
        case UnitRank.ace:
          return "A";
        case UnitRank.jack:
          return "J";
        case UnitRank.queen:
          return "Q";
        case UnitRank.king:
          return "K";
        default:
          return (rank.index + 1).toString();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "SELECT ROUND RANK",
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: ranks.map((rank) {
                final isStaged = provider.stagedRank == rank;
                return GestureDetector(
                  onTap: () => provider.stageRank(rank),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isStaged
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isStaged ? Colors.white : Colors.white10,
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        getRankSymbol(rank),
                        style: TextStyle(
                          color: isStaged ? Colors.black : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => provider.toggleRankSelectionMode(),
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, SessionProvider provider) {
    final selectionCount = provider.selectedUnitIds.length;
    final hasSelection = selectionCount > 0;
    final isMyTurn = provider.isMyTurn;
    final isRoundSet = provider.isRoundSet;
    final canSubmit = provider.canSubmit();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.95),
            Colors.black,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Anchor for flying cards animation
          SizedBox(
            height: 130,
            child: _buildHandArea(
              context,
              provider.state.myHand
                  .where((u) => !provider.selectedUnitIds.contains(u.id))
                  .toList(),
              provider,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: isMyTurn ? () => provider.passTurn() : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "PASS",
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: canSubmit
                        ? const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
                          ),
                  ),
                  child: ElevatedButton(
                    onPressed: canSubmit
                        ? () => provider.submitSelectedUnits()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      hasSelection ? "PLAY $selectionCount" : "PLAY",
                      style: TextStyle(
                        color: canSubmit ? Colors.black : Colors.white24,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (isRoundSet && isMyTurn)
                        ? () => provider.raiseChallenge()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRoundSet
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      "BLUFF",
                      style: TextStyle(
                        color: isRoundSet ? Colors.white : Colors.white10,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStagingArea(BuildContext context, SessionProvider provider) {
    final selectedUnits = provider.state.myHand
        .where((u) => provider.selectedUnitIds.contains(u.id))
        .toList();

    return SizedBox(
      key: _avatarKeys['me'],
      height: 75,
      child: selectedUnits.isEmpty
          ? const SizedBox.shrink()
          : Center(
              child: Stack(
                alignment: Alignment.center,
                children: List.generate(selectedUnits.length, (index) {
                  final unit = selectedUnits[index];
                  const double overlap = 30.0;
                  final double totalWidth =
                      70 + (selectedUnits.length - 1) * overlap;
                  final double startX = -(totalWidth / 2) + 35;

                  return Positioned(
                    left:
                        (MediaQuery.of(context).size.width / 2) +
                        startX +
                        (index * overlap) -
                        35,
                    child: UnitCard(
                      unit: unit,
                      onTap: () => provider.toggleUnitSelection(unit.id),
                      isSelected: true,
                      width: 50,
                      height: 70,
                    ),
                  );
                }),
              ),
            ),
    );
  }

  Widget _buildHandArea(
    BuildContext context,
    List<Unit> hand,
    SessionProvider provider,
  ) {
    if (hand.isEmpty) {
      return const Center(
        child: Text("EMPTY HAND", style: TextStyle(color: Colors.white24)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double cardWidth = 70;
        const double overlap = 25;

        if (hand.length <= 10) {
          return _buildRowContent(hand, provider, width, cardWidth, overlap);
        } else {
          final int mid = (hand.length / 2).ceil();
          final backRow = hand.sublist(0, mid);
          final frontRow = hand.sublist(mid);
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 30,
                child: _buildRowContent(
                  backRow,
                  provider,
                  width,
                  cardWidth,
                  overlap,
                ),
              ),
              Positioned(
                bottom: 0,
                child: _buildRowContent(
                  frontRow,
                  provider,
                  width,
                  cardWidth,
                  overlap,
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildRowContent(
    List<Unit> handSlice,
    SessionProvider provider,
    double maxWidth,
    double cardWidth,
    double overlap,
  ) {
    final double scrollWidth = cardWidth + (handSlice.length - 1) * overlap;

    return SizedBox(
      height: 100,
      width: maxWidth,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: scrollWidth + 40, // padding for drag
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: true,
              itemCount: handSlice.length,
              onReorder: (oldIndex, newIndex) {
                // Adjust for global index if in two rows
                int globalOld = -1;
                int globalNew = -1;

                final fullHand = provider.state.myHand;
                final id = handSlice[oldIndex].id;
                globalOld = fullHand.indexWhere((u) => u.id == id);

                if (newIndex >= handSlice.length) {
                  // Dragged to end of slice
                  if (handSlice.length == fullHand.length) {
                    globalNew = fullHand.length;
                  } else {
                    // Complex case: find neighbor in full hand
                    final neighborId = handSlice.last.id;
                    globalNew =
                        fullHand.indexWhere((u) => u.id == neighborId) + 1;
                  }
                } else {
                  final targetId = handSlice[newIndex].id;
                  globalNew = fullHand.indexWhere((u) => u.id == targetId);
                }

                if (globalOld != -1 && globalNew != -1) {
                  provider.reorderHand(globalOld, globalNew);
                }
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (animation.value * 0.1),
                      child: Material(color: Colors.transparent, child: child),
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final unit = handSlice[index];
                return SizedBox(
                  key: ValueKey(unit.id),
                  width: index == handSlice.length - 1 ? cardWidth : overlap,
                  child: OverflowBox(
                    maxWidth: cardWidth,
                    minWidth: cardWidth,
                    alignment: Alignment.centerLeft,
                    child: UnitCard(
                      unit: unit,
                      isSelected: false,
                      onTap: () => provider.toggleUnitSelection(unit.id),
                      width: cardWidth,
                      height: 100,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        onPressed: onTap,
      ),
    );
  }

  void _showGameMenu(BuildContext context, SessionProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.history, color: Color(0xFFFFD700)),
            title: const Text(
              "MATCH HISTORY",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showHistory(context);
            },
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.menu_book, color: Colors.white70),
            title: const Text(
              "GAME RULES",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showRules(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sort, color: Colors.blueAccent),
            title: const Text(
              "SORT CARDS (ASC)",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              provider.sortHand();
            },
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: const Text(
              "EXIT GAME",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (r) => false);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              "MATCH LOG",
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    // Re-use HistoryFeed here but unrestricted?
                    // HistoryFeed is designed to be small and dim.
                    // We can stick to using HistoryFeed or wrap it.
                    // Actually, HistoryFeed has fixed height/width.
                    // We should modify HistoryFeed to be flexible or create a new view.
                    // For speed, let's just use HistoryFeed but maybe allow it to expand?
                    // The existing HistoryFeed has fixed size. I'll modify HistoryFeed to be better suited for full view
                    // OR just let it act as a list source.
                    // Let's assume for now I will fix HistoryFeed to be responsive or use a custom list here.
                    // Actually, let's just use a simple list builder here for the log since we have access to provider.
                    child: _FullHistoryList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRules(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (context) => DocViewer(
        title: "GAME RULES",
        sections: [
          DocSection(
            heading: "Core Rules",
            bulletPoints: [
              "Standard 52-card deck. Suits are ignored.",
              "Play 1-4 cards or Pass.",
              "Only the NEXT player can call a Bluff.",
              "Bluff correct (Lie) -> Liar picks pile.",
              "Bluff wrong (Truth) -> Caller picks pile.",
            ],
          ),
          DocSection(
            heading: "Pass-Cycle Rule",
            bulletPoints: [
              "If everyone passes and turn comes back to the last player:",
              "1. Entire pile is DISCARDED.",
              "2. That player starts a NEW round.",
            ],
          ),
        ],
      ),
    );
  }
}

class _EventListenerWrapper extends StatefulWidget {
  final SessionProvider provider;
  final Function(SessionEventType) onEvent;

  const _EventListenerWrapper({required this.provider, required this.onEvent});

  @override
  State<_EventListenerWrapper> createState() => _EventListenerWrapperState();
}

class _EventListenerWrapperState extends State<_EventListenerWrapper> {
  SessionEventType _lastHandled = SessionEventType.none;
  String? _lastActor = "";

  @override
  Widget build(BuildContext context) {
    final currentEvent = widget.provider.lastEvent;
    final currentActor = widget.provider.lastEventActorId;

    if (currentEvent != SessionEventType.none &&
        (currentEvent != _lastHandled || currentActor != _lastActor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onEvent(currentEvent);
      });
      _lastHandled = currentEvent;
      _lastActor = currentActor;
    }
    return const SizedBox.shrink();
  }
}

class ParticleExplosionOverlay extends StatefulWidget {
  final Color color;
  const ParticleExplosionOverlay({super.key, required this.color});

  @override
  State<ParticleExplosionOverlay> createState() =>
      _ParticleExplosionOverlayState();
}

class _ParticleExplosionOverlayState extends State<ParticleExplosionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle());
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _particles.map((p) {
            final progress = _controller.value;
            final double x =
                (MediaQuery.of(context).size.width / 2) +
                (p.dx * progress * 300);
            final double y =
                (MediaQuery.of(context).size.height / 2) -
                50 +
                (p.dy * progress * 300) +
                (progress * progress * 150);

            return Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: (1.0 - progress).clamp(0.0, 1.0),
                child: Container(
                  width: 6 + (1 - progress) * 4,
                  height: 6 + (1 - progress) * 4,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Particle {
  late double dx;
  late double dy;
  _Particle() {
    final rnd = dart_math.Random();
    final angle = rnd.nextDouble() * 2 * dart_math.pi;
    final speed = 0.3 + rnd.nextDouble() * 0.7;
    dx = dart_math.cos(angle) * speed;
    dy = dart_math.sin(angle) * speed;
  }
}

class AnimatedPileView extends StatefulWidget {
  final int pileCount;
  final String roundStatus;
  final VoidCallback onTap;
  const AnimatedPileView({
    super.key,
    required this.pileCount,
    required this.roundStatus,
    required this.onTap,
  });

  @override
  State<AnimatedPileView> createState() => _AnimatedPileViewState();
}

class _AnimatedPileViewState extends State<AnimatedPileView>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pressureController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pressureAnimation;
  int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _prevCount = widget.pileCount;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _pressureController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pressureAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_pressureController);
    _pressureController.repeat();
    _updatePressureSpeed();
  }

  void _updatePressureSpeed() {
    // Intensity based on pileCount
    final speedMultiplier = 1.0 + (widget.pileCount / 10).clamp(0.0, 4.0);
    _pressureController.duration = Duration(
      milliseconds: (2000 / speedMultiplier).toInt(),
    );
    _pressureController.repeat();
  }

  @override
  void didUpdateWidget(AnimatedPileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pileCount > _prevCount) {
      _controller.forward(from: 0.0);
      _updatePressureSpeed();
    }
    _prevCount = widget.pileCount;
  }

  @override
  void dispose() {
    _controller.dispose();
    _pressureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pressureColor = Color.lerp(
      const Color(0xFFFFD700),
      const Color(0xFFD32F2F),
      (widget.pileCount / 30).clamp(0.0, 1.0),
    )!;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pressure Ring (Static or Pulsing)
          if (widget.pileCount > 0)
            AnimatedBuilder(
              animation: _pressureAnimation,
              builder: (context, child) {
                return Container(
                  width: 190 + (20 * _pressureAnimation.value),
                  height: 190 + (20 * _pressureAnimation.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: pressureColor.withValues(
                        alpha: 0.3 * (1 - _pressureAnimation.value),
                      ),
                      width: 4,
                    ),
                  ),
                );
              },
            ),
          ScaleTransition(
            scale: _scaleAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.pileCount > 0
                          ? pressureColor
                          : Colors.white24,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: pressureColor.withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Icon(
                        Icons.style,
                        size: 60,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
                if (widget.pileCount > 1)
                  ...List.generate(
                    dart_math.min(widget.pileCount, 5),
                    (i) => Positioned(
                      top: i * 2.0,
                      left: i * 2.0,
                      child: Container(
                        width: 140,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10, width: 1),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 20,
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFFECB3),
                        Color(0xFFB8860B),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      widget.roundStatus.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
                // "PILE" label in Bottom Right
                Positioned(
                  bottom: 15,
                  right: 15,
                  child: Text(
                    'PILE',
                    style: TextStyle(
                      color: pressureColor.withValues(alpha: 0.5),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                // Pile Count (Number) in Bottom Middle
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: pressureColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Text(
                        '${widget.pileCount}',
                        key: ValueKey(widget.pileCount),
                        style: TextStyle(
                          color: pressureColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullHistoryList extends StatelessWidget {
  const _FullHistoryList();

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, provider, child) {
        final logs = provider.gameLog;
        if (logs.isEmpty) {
          return const Center(
            child: Text(
              "NO RECORDS YET",
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD700),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      logs[index],
                      style: TextStyle(
                        color: index == 0 ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: index == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
