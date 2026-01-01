import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import '../../../../core/constants/dimens.dart';
import '../../../../core/animations/anim_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../models/unit.dart';
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
  final GlobalKey _pileKey = GlobalKey();

  // Flight Animation State
  final List<Unit> _flyingUnits = [];
  final Offset _pilePosition = Offset.zero;
  late AnimationController _flightController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: AnimUtils.visual,
    )..forward();

    _flightController =
        AnimationController(vsync: this, duration: AnimUtils.medium)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              final provider = context.read<SessionProvider>();
              provider.submitSelectedUnits();
              setState(() {
                _flyingUnits.clear();
              });
              _flightController.reset();
            }
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Responsive.init(context);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _flightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<SessionProvider>();

    // Dark Background with Gradient
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Deep Black/Brown
      body: Stack(
        children: [
          // Background Gradient (Subtle radial)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    Color(0xFF2A1E17), // Dark Warm Brown
                    Color(0xFF0D0D0D), // Black
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Top Bar (Menu, Info, Chat)
                _buildTopBar(),

                // 2. Game Area (Participants + Pile)
                Expanded(
                  child: Stack(
                    children: [
                      // Participants Arc
                      _buildOpponents(context, provider),

                      // Center Area (Rank Selection or Active Pile)
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: provider.isSelectingRank
                              ? _buildRankSelector(provider)
                              : _buildCenterPile(provider),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Bottom Controls (Hand + Buttons)
                _buildBottomControls(context, provider),
              ],
            ),
          ),

          // Flying Units Layer
          if (_flyingUnits.isNotEmpty) ..._buildFlyingUnits(context),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final provider = context.watch<SessionProvider>();
    final isRoundSet = provider.isRoundSet;
    final rankName = provider.currentRank?.name.toUpperCase() ?? "???";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(Icons.menu, () => _showGameMenu(context)),

          // Premium Round Indicator
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
                  isRoundSet ? rankName : "WAITING...",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
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

  void _showGameMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.rule, color: Color(0xFFFFD700)),
              title: const Text(
                "Game Rules",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                DocViewer.show(
                  context,
                  title: "Indian Bluff Rules",
                  sections: [
                    DocSection(
                      heading: "Objective",
                      bulletPoints: ["Be the first to discard all your cards."],
                    ),
                    DocSection(
                      heading: "Gameplay",
                      bulletPoints: [
                        "Play 1-4 cards and declare their rank (e.g., 'Three Kings').",
                        "The declared rank follows an Ace to King sequence.",
                        "You can bluff! The actual cards don't have to match the rank.",
                      ],
                    ),
                    DocSection(
                      heading: "Calling Bluff",
                      bulletPoints: [
                        "Anyone can challenge a play by clicking 'Bluff'.",
                        "The loser of the challenge picks up the whole center pile.",
                      ],
                    ),
                  ],
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.architecture, color: Color(0xFFFFD700)),
              title: const Text(
                "Project Architecture",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                DocViewer.show(
                  context,
                  title: "Veil Core Arch",
                  sections: [
                    DocSection(
                      heading: "Technology Stack",
                      bulletPoints: [
                        "Flutter for Cross-Platform UI.",
                        "Provider for State Management.",
                        "Standard 52-card deck logic.",
                      ],
                    ),
                    DocSection(
                      heading: "Internal Flow",
                      bulletPoints: [
                        "SessionProvider manages hand state and selection.",
                        "Custom Fan rendering for responsive card layout.",
                        "Staging system for card validation before play.",
                      ],
                    ),
                  ],
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.touch_app, color: Color(0xFFFFD700)),
              title: const Text(
                "App Flow",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                DocViewer.show(
                  context,
                  title: "How to Navigate",
                  sections: [
                    DocSection(
                      heading: "Controls",
                      bulletPoints: [
                        "Tap cards in your hand to move them to Staging.",
                        "Tap 'Play' to submit staged cards to the pile.",
                        "Use 'Pass' to skip your turn.",
                        "Click 'Bluff' to challenge the last player.",
                      ],
                    ),
                    DocSection(
                      heading: "Indicators",
                      bulletPoints: [
                        "Staging Banner: shows current selection count.",
                        "Glow Avatar: identifies the current active player.",
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF3E3E3E)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildOpponents(BuildContext context, SessionProvider provider) {
    // Exclude 'me'
    final opponents = provider.state.participants
        .where((p) => !p.isMe)
        .toList();
    if (opponents.isEmpty) return const SizedBox.shrink();

    // Layout Logic:
    // If <= 5, distribute evenly in a Row or Arc.
    // If > 5, we need a smarter Arc or multi-row.
    // Given the request for 10 players, an Arc around the top half is best.

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Ellipse Arc parameters
        final double centerX = w / 2;
        final double centerY = h * 0.4; // Center of the "Table" roughly
        final double radiusX = w * 0.42; // Horizontal radius
        final double radiusY = h * 0.35; // Vertical radius

        return Stack(
          children: List.generate(opponents.length, (index) {
            final p = opponents[index];

            // angle logic:
            // 0 is right (3 o'clock). Pi is left (9 o'clock). -Pi/2 is top.
            // We want to distribute from Left (PI) to Right (0) - actually usually Top-Left to Top-Right.
            // Let's go from -PI (Left) to 0 (Right) -> Top semi-circle is -PI to 0.
            // Wait, standard trig: 0 is Right, PI is Left, 3PI/2 (or -PI/2) is Top.
            // We want an arc from roughly 160 deg (Left-ish) to 20 deg (Right-ish).
            // in Radians: 160 = 2.8 rad. 20 = 0.35 rad.
            // Total span = 2.45 rad.
            // Step = Total / (count - 1).

            // Adjust for single opponent (place at top)
            double angle;
            if (opponents.length == 1) {
              angle = -math.pi / 2; // Top
            } else {
              const startAngle = -math.pi * 0.85; // ~ Bottom Left of top-half
              const endAngle = -math.pi * 0.15; // ~ Bottom Right of top-half
              final step = (endAngle - startAngle) / (opponents.length - 1);
              angle = startAngle + (step * index);
            }

            final x = centerX + radiusX * math.cos(angle);
            final y = centerY + radiusY * math.sin(angle);

            return Positioned(
              left: x - 28, // Centering avatar (assuming size ~56)
              top: y - 40,
              child: ParticipantAvatar(
                participant: p,
                size: 56, // Slightly smaller to fit 10
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildCenterPile(SessionProvider provider) {
    final state = provider.state;
    final isRoundSet = provider.isRoundSet;

    return GestureDetector(
      onTap: () {
        if (!isRoundSet && provider.state.activeParticipantId == 'me') {
          provider.initiateRankSelection();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dynamic Header Text
          if (isRoundSet)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFFECB3),
                    Color(0xFFB8860B),
                  ],
                ).createShader(bounds),
                child: Text(
                  "👑 ROUND: ${provider.currentRank?.name.toUpperCase()}S",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // The Pile Card
          Container(
            key: _pileKey,
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRoundSet
                    ? const Color(0xFFFFD700)
                    : const Color(0xFF3E3E3E),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isRoundSet ? const Color(0xFFFFD700) : Colors.black)
                      .withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Interior Design
                if (!isRoundSet)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.help_outline,
                          color: Color(0xFFFFD700),
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "TAP TO\nCHOOSE",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFFFD700),
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.currentRank?.name[0].toUpperCase() ?? "",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Piled: ${state.pileCount}",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankSelector(SessionProvider provider) {
    final ranks = UnitRank.values.where((r) => r != UnitRank.joker).toList();

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
        const SizedBox(height: 30),
        SizedBox(
          height: 200,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              children: ranks.map((rank) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => provider.setRoundRank(rank),
                    child: Container(
                      width: 80,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Center(
                        child: Text(
                          rank.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF121212),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => provider.submitSelectedUnits(), // Back if needed
          child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context, SessionProvider provider) {
    final hasSelection = provider.selectedUnitIds.isNotEmpty;
    final selectionCount = provider.selectedUnitIds.length;
    final isMyTurn = provider.state.activeParticipantId == 'me';
    final isRoundSet = provider.isRoundSet;

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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player Hand (Fan)
          SizedBox(
            height: 220,
            child: _buildFan(context, provider.state.myHand, provider),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              // PASS Button
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
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // PLAY Button
              Expanded(
                flex: 2,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: hasSelection
                        ? const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
                          ),
                    boxShadow: hasSelection
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton(
                    onPressed: isMyTurn && hasSelection
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
                        color: hasSelection ? Colors.black : Colors.white24,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // BLUFF Button
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isRoundSet
                        ? () => provider.raiseChallenge()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRoundSet
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF1E1E1E),
                      disabledBackgroundColor: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "BLUFF",
                      style: TextStyle(
                        color: isRoundSet ? Colors.white : Colors.white10,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
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

  Widget _buildFan(
    BuildContext context,
    List<Unit> hand,
    SessionProvider provider,
  ) {
    if (hand.isEmpty) {
      return const Center(
        child: Text("No cards", style: TextStyle(color: Colors.white24)),
      );
    }

    final int count = hand.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double centerW = width / 2;
        final double cardWidth = AppDimens.cardWidth;

        // Use staggering for many cards to keep info visible
        final bool useStagger = count > 15;
        // The total span is determined by the number of slots in the widest row
        final int horizontalSlots = useStagger ? (count / 2).ceil() : count;
        final double centerIndex = (horizontalSlots - 1) / 2.0;

        final double maxAllowedWidth = width - 30; // Spread cards more

        double radius;
        double baseBottomOffset;

        if (count <= 7) {
          radius = 500;
          baseBottomOffset = 40;
        } else if (count <= 15) {
          radius = 700;
          baseBottomOffset = 30;
        } else {
          radius = 1300; // Flatter for 2 rows
          baseBottomOffset = 10;
        }

        final double availableArcWidth = (maxAllowedWidth - cardWidth).clamp(
          100,
          2000,
        );
        final double sinHalfSpan = availableArcWidth / (2 * radius);
        final double totalSpan = 2 * math.asin(sinHalfSpan);
        final double angleStep = horizontalSlots > 1
            ? totalSpan / (horizontalSlots - 1)
            : 0;

        // Painting Order: Back Row -> Front Row -> Selected Cards
        final List<int> sortedIndices = List.generate(count, (i) => i);
        sortedIndices.sort((a, b) {
          final bool aSelected = provider.selectedUnitIds.contains(hand[a].id);
          final bool bSelected = provider.selectedUnitIds.contains(hand[b].id);

          if (aSelected != bSelected) return aSelected ? 1 : -1;

          final int aRow = useStagger
              ? (a % 2)
              : 0; // index even is back (0), odd is front (1)
          final int bRow = useStagger ? (b % 2) : 0;

          if (aRow != bRow) return aRow - bRow;
          return a - b; // Left to right
        });

        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: sortedIndices.map((index) {
            final unit = hand[index];
            final isFlying = _flyingUnits.any((u) => u.id == unit.id);
            if (isFlying) return const SizedBox.shrink();

            final isSelected = provider.selectedUnitIds.contains(unit.id);

            // Staggering: back row (higher) vs front row (lower)
            final int rowIndex = useStagger ? (index % 2) : 0;
            // Back row is 0, Front row is 1. We want back row higher.
            final double rowHeightOffset = useStagger
                ? (rowIndex == 0 ? 45.0 : 0.0)
                : 0.0;

            // horizontal position in its row (staggered horizontally too)
            final double hPos = useStagger
                ? (index / 2).floorToDouble() + (rowIndex == 1 ? 0.4 : 0.0)
                : index.toDouble();

            final double rotation = (hPos - centerIndex) * angleStep;
            final double offsetX = radius * math.sin(rotation);
            final double offsetY = radius - (radius * math.cos(rotation));

            final double left = centerW - (cardWidth / 2) + offsetX;
            final double bottom =
                baseBottomOffset -
                offsetY +
                rowHeightOffset +
                (isSelected ? 45 : 0);

            return Positioned(
              left: left,
              bottom: bottom,
              child: Transform.rotate(
                angle: rotation,
                child: UnitCard(
                  unit: unit,
                  isSelected: isSelected,
                  rotation: 0,
                  onTap: () => provider.toggleUnitSelection(unit.id),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  List<Widget> _buildFlyingUnits(BuildContext context) {
    // Basic reuse of previous logic, updated for new coordinates if needed
    // Simplified for brevity, same logic applies
    final totalCount = context.read<SessionProvider>().state.myHand.length;
    final hand = context.read<SessionProvider>().state.myHand;

    return _flyingUnits.map((unit) {
      final index = hand.indexOf(unit);
      final centerIndex = (totalCount - 1) / 2;
      final double radius = 600;
      final double angleStep = 0.08;
      final double rotation = (index - centerIndex) * angleStep;

      // Calculate start pos (rough approximation to match fan)
      // Improve by using GlobalKeys in real app
      final double startLeft =
          (Responsive.screenWidth / 2) +
          (radius * math.sin(rotation)) -
          (AppDimens.cardWidth / 2);
      final double startTop = Responsive.screenHeight - 200; // Approx fan area

      final double targetTop = _pilePosition.dy - (AppDimens.cardHeight / 2);
      final double targetLeft = _pilePosition.dx - (AppDimens.cardWidth / 2);

      return AnimatedBuilder(
        animation: _flightController,
        builder: (context, child) {
          final val = _flightController.value;
          final curveVal = Curves.easeInOut.transform(val);

          final currentLeft = lerpDouble(startLeft, targetLeft, curveVal) ?? 0;
          final currentTop = lerpDouble(startTop, targetTop, curveVal) ?? 0;
          final currentScale = lerpDouble(1.0, 0.4, curveVal) ?? 1.0;
          final currentRotation =
              lerpDouble(
                rotation,
                math.pi + (math.Random().nextDouble()),
                curveVal,
              ) ??
              0;

          return Positioned(
            left: currentLeft,
            top: currentTop,
            child: Transform.rotate(
              angle: currentRotation,
              child: Transform.scale(
                scale: currentScale,
                child: UnitCard(unit: unit, isSelected: true, onTap: () {}),
              ),
            ),
          );
        },
      );
    }).toList();
  }
}
