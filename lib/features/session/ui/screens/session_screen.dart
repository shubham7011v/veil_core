import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as dart_math;
import '../../../../core/animations/anim_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../models/unit.dart';
import '../../models/session_state.dart';
import '../../state/session_provider.dart';
import '../../widgets/unit_card.dart';
import '../../widgets/participant_avatar.dart';
import '../../widgets/doc_viewer.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late ScrollController _carouselController;

  @override
  void initState() {
    super.initState();
    _carouselController = ScrollController();
    _entryController = AnimationController(
      vsync: this,
      duration: AnimUtils.visual,
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Responsive.init(context);
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
    // Add particle explosion
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

      // Clear after animation
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _particles.clear();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    // Listen for One-Shot Events
    context.select<SessionProvider, void>((p) {
      if (p.lastEvent == SessionEventType.pileDiscarded) {
        // We need to trigger this only ONCE per event.
        // Since build runs often, we might need a better trigger mechanic or check ID.
        // A simple way is to trust the provider resets event to 'none' or we track last handled event ID.
        // For V1, we'll trigger and let the provider logic handle state.
        // Ideally: add a listener in initState/didChangeDependencies.
      }
    });

    final provider = context.watch<SessionProvider>();

    // Hacky trigger for V1: check if event is 'pileDiscarded' and local state hasn't fired recently?
    // Better: use a listener.

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
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

                // Center Pile (0.2 - 0.7)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ScaleTransition(
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

          // Particle Layer
          ..._particles,

          // Invisible Event Listener Wrapper
          _EventListenerWrapper(
            provider: provider,
            onEvent: (event) {
              if (event == SessionEventType.pileDiscarded) {
                _triggerPileDiscardEffect();
              }
            },
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
    final isRoundSet = provider.isRoundSet;
    final rankName = provider.currentRank?.name.toUpperCase() ?? "???";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(Icons.menu, () => _showGameMenu(context)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "👑 CURRENT ROUND",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFFECB3),
                    Color(0xFFB8860B),
                  ],
                ).createShader(bounds),
                child: Text(
                  isRoundSet ? "${rankName}S" : "WAITING...",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
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
    final participants = provider.state.participants;

    // Center logic
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
            child: ParticipantAvatar(participant: p, size: 65),
          );
        },
      ),
    );
  }

  Widget _buildCenterPile(SessionProvider provider) {
    return AnimatedPileView(
      pileCount: provider.pileCount,
      isRoundSet: provider.isRoundSet,
      currentRank: provider.currentRank,
      stagedRank: provider.stagedRank,
      isMyTurn: provider.isMyTurn,
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
        case UnitRank.two:
          return "2";
        case UnitRank.three:
          return "3";
        case UnitRank.four:
          return "4";
        case UnitRank.five:
          return "5";
        case UnitRank.six:
          return "6";
        case UnitRank.seven:
          return "7";
        case UnitRank.eight:
          return "8";
        case UnitRank.nine:
          return "9";
        case UnitRank.ten:
          return "10";
        case UnitRank.jack:
          return "J";
        case UnitRank.queen:
          return "Q";
        case UnitRank.king:
          return "K";
      }
    }

    return Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
        if (provider.stagedRank != null)
          TextButton(
            onPressed: () => provider.toggleRankSelectionMode(),
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.white54),
            ),
          ),
      ],
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
          SizedBox(
            height: 130, // Reduced from 140
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

    if (selectedUnits.isEmpty) {
      return const SizedBox(height: 75);
    }

    return SizedBox(
      height: 75,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: List.generate(selectedUnits.length, (index) {
            final unit = selectedUnits[index];
            final double overlap = 30.0;
            final double totalWidth = 70 + (selectedUnits.length - 1) * overlap;
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
        final double cardWidth = 70;
        final double overlap = 25;

        if (hand.length <= 10) {
          return _buildSingleRow(hand, provider, width, cardWidth, overlap);
        } else {
          // Split hand into two rows
          final int mid = (hand.length / 2).ceil();
          final backRow = hand.sublist(0, mid);
          final frontRow = hand.sublist(mid);

          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Back Row
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
              // Front Row
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

  Widget _buildSingleRow(
    List<Unit> hand,
    SessionProvider provider,
    double maxWidth,
    double cardWidth,
    double overlap,
  ) {
    return _buildRowContent(hand, provider, maxWidth, cardWidth, overlap);
  }

  Widget _buildRowContent(
    List<Unit> handSlice,
    SessionProvider provider,
    double maxWidth,
    double cardWidth,
    double overlap,
  ) {
    final int count = handSlice.length;
    final double totalWidth = cardWidth + (count - 1) * overlap;

    return SizedBox(
      width: totalWidth,
      height: 100,
      child: Stack(
        children: List.generate(count, (index) {
          final unit = handSlice[index];

          return Positioned(
            left: index * overlap,
            bottom: 0,
            child: UnitCard(
              unit: unit,
              isSelected: false,
              onTap: () => provider.toggleUnitSelection(unit.id),
              width: cardWidth,
              height: 100,
            ),
          );
        }),
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

  void _showGameMenu(BuildContext context) {
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

class AnimatedPileView extends StatefulWidget {
  final int pileCount;
  final bool isRoundSet;
  final UnitRank? currentRank;
  final UnitRank? stagedRank;
  final bool isMyTurn;
  final VoidCallback onTap;

  const AnimatedPileView({
    super.key,
    required this.pileCount,
    required this.isRoundSet,
    required this.currentRank,
    required this.stagedRank,
    required this.isMyTurn,
    required this.onTap,
  });

  @override
  State<AnimatedPileView> createState() => _AnimatedPileViewState();
}

class _AnimatedPileViewState extends State<AnimatedPileView>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
        );
  }

  @override
  void didUpdateWidget(AnimatedPileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pileCount > oldWidget.pileCount) {
      _bounceController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isRoundSet || widget.stagedRank != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFFECB3),
                    Color(0xFFB8860B),
                  ],
                ).createShader(bounds),
                child: Text(
                  (widget.isRoundSet ? widget.currentRank! : widget.stagedRank!)
                      .name
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1A1A),
                border: Border.all(
                  color: widget.isRoundSet
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF3E3E3E),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (widget.isRoundSet
                                ? const Color(0xFFFFD700)
                                : Colors.black)
                            .withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Text(
                        "${widget.pileCount}",
                        key: ValueKey(widget.pileCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Text(
                      "CARDS",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    // Check if event changed
    final currentEvent = widget.provider.lastEvent;
    final currentActor = widget.provider.lastEventActorId;

    if (currentEvent != SessionEventType.none &&
        (currentEvent != _lastHandled || currentActor != _lastActor)) {
      // Fire callback on next frame to avoid build conflicts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Prevent re-firing
        if (mounted) {
          widget.onEvent(currentEvent);
        }
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

    // Generate particles
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
                (p.dx * progress * 300); // Spread width
            final double y =
                (MediaQuery.of(context).size.height / 2) -
                50 + // Start slightly higher
                (p.dy * progress * 300) +
                (progress * progress * 150); // Gravity

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
    // Explosion pattern: full circle
    final angle = rnd.nextDouble() * 2 * dart_math.pi;
    // Speed variaiton
    final speed = 0.3 + rnd.nextDouble() * 0.7;
    dx = dart_math.cos(angle) * speed;
    dy = dart_math.sin(angle) * speed;
  }
}
