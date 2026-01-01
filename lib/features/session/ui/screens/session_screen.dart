import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChrome
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../core/constants/strings.dart';
import '../../../../core/animations/anim_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/components/glass_container.dart';
import '../../models/unit.dart';
import '../../state/session_provider.dart';
import '../../widgets/unit_card.dart';
import '../../widgets/participant_avatar.dart';

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
  List<Unit> _flyingUnits = [];
  Offset _pilePosition = Offset.zero;
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

  void _triggerSubmitAnimation(SessionProvider provider) {
    if (provider.selectedUnitIds.isEmpty) return;

    final RenderBox? pileBox =
        _pileKey.currentContext?.findRenderObject() as RenderBox?;
    if (pileBox != null) {
      final position = pileBox.localToGlobal(Offset.zero);
      _pilePosition =
          position + Offset(pileBox.size.width / 2, pileBox.size.height / 2);
    } else {
      _pilePosition = Offset(
        Responsive.screenWidth / 2,
        Responsive.screenHeight * 0.35,
      );
    }

    final flying = provider.state.myHand
        .where((u) => provider.selectedUnitIds.contains(u.id))
        .toList();
    setState(() {
      _flyingUnits = flying;
    });
    _flightController.forward();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<SessionProvider>();
    final state = provider.state;

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

                      // Center Pile & Info
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (state.lastActionText != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Text(
                                  state.lastActionText!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFE0E0E0),
                                    fontSize: 18,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'Serif', // Placeholder
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            // Pile Visual
                            _buildPile(state.pileCount),
                          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu Button
          _buildCircleButton(Icons.menu, () {}),

          // Current Bet / Info Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF3E3E3E)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.emoji_events,
                  color: Color(0xFFFFD700),
                  size: 18,
                ), // Crown/Trophy
                SizedBox(width: 8),
                Text(
                  "Kings", // Placeholder for Current Bet
                  style: TextStyle(
                    color: Color(0xFFF0F0F0),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Serif',
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 18),
              ],
            ),
          ),

          // Chat Button
          _buildCircleButton(Icons.chat_bubble_outline, () {}),
        ],
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

  Widget _buildPile(int count) {
    return Container(
      key: _pileKey,
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF2C221C), // Card Back Dark
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4E342E), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.layers, color: Color(0xFF8D6E63), size: 32),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: const TextStyle(
                color: Color(0xFFD7CCC8),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, SessionProvider provider) {
    final hasSelection = provider.selectedUnitIds.isNotEmpty;
    final selectionCount = provider.selectedUnitIds.length;

    final allUnits = provider.state.myHand;
    final selectedUnits = allUnits
        .where((u) => provider.selectedUnitIds.contains(u.id))
        .toList();
    final unselectedUnits = allUnits
        .where((u) => !provider.selectedUnitIds.contains(u.id))
        .toList();

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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), // Reduced padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Staging Area (Selected Cards)
          if (hasSelection)
            Container(
              height: 90,
              margin: const EdgeInsets.only(bottom: 4),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: List.generate(selectedUnits.length, (index) {
                  final unit = selectedUnits[index];
                  // Overlap them slightly
                  final double offset =
                      (index - (selectedUnits.length - 1) / 2) * 30.0;

                  return Positioned(
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(offset, 0),
                        child: Transform.rotate(
                          angle: (index - (selectedUnits.length - 1) / 2) * 0.1,
                          child: UnitCard(
                            unit: unit,
                            onTap: () => provider.toggleUnitSelection(unit.id),
                            isSelected: true,
                            width: 50,
                            height: 75,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

          // The Hand Fan (Unselected Cards)
          SizedBox(
            height: 165,
            child: _buildFan(context, unselectedUnits, provider),
          ),

          const SizedBox(height: 8), // Reduced gap
          // Action Buttons: Pass | Play | Bluff
          Row(
            children: [
              // PASS Button
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 46, // Increased slightly
                  child: OutlinedButton(
                    onPressed: provider.selectedUnitIds.isEmpty
                        ? () => provider.passTurn()
                        : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4A4A4A)),
                      padding: EdgeInsets.zero, // Prevent clipping
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: const Color(0xFF1E1E1E),
                    ),
                    child: const Text(
                      "Pass",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // PLAY Button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46, // Increased slightly
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: hasSelection
                          ? const LinearGradient(
                              colors: [Color(0xFFD4AF37), Color(0xFFA67C00)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF333333), Color(0xFF222222)],
                            ),
                      boxShadow: hasSelection
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD700,
                                ).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: ElevatedButton(
                      onPressed: hasSelection
                          ? () => _triggerSubmitAnimation(provider)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero, // Prevent clipping
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        hasSelection ? "Play $selectionCount" : "Play",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: hasSelection
                              ? const Color(0xFF1E1200)
                              : Colors.white24,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // CALL BLUFF Button
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 46, // Increased slightly
                  child: ElevatedButton(
                    onPressed: () => provider.raiseChallenge(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D0C0C),
                      foregroundColor: const Color(0xFFEF5350),
                      padding: EdgeInsets.zero, // Prevent clipping
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: const Text(
                      "Bluff",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
