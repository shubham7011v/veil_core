import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<SessionProvider>();

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
                _buildTopBar(provider),

                Expanded(
                  child: Column(
                    children: [
                      _buildOpponentCarousel(context, provider),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: provider.isSelectingRank
                                ? _buildRankSelector(provider)
                                : _buildCenterPile(provider),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildBottomControls(context, provider),
              ],
            ),
          ),
        ],
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
      height: 110,
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
    final isRoundSet = provider.isRoundSet;
    final isMyTurn = provider.isMyTurn;

    return GestureDetector(
      onTap: () {
        if (!isRoundSet && isMyTurn) {
          provider.toggleRankSelectionMode();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRoundSet || provider.stagedRank != null)
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
                  (isRoundSet ? provider.currentRank! : provider.stagedRank!)
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

          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1A1A),
              border: Border.all(
                color: isRoundSet
                    ? const Color(0xFFFFD700)
                    : const Color(0xFF3E3E3E),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isRoundSet ? const Color(0xFFFFD700) : Colors.black)
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
                  Text(
                    "${provider.pileCount}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
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

          if (!isRoundSet && isMyTurn && provider.stagedRank == null)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                "TAP TO CHOOSE RANK",
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
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
          height: 160,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              children: ranks.map((rank) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => provider.stageRank(rank),
                    child: Container(
                      width: 80,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
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
          onPressed: () => provider.toggleRankSelectionMode(),
          child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 220,
            child: _buildFan(context, provider.state.myHand, provider),
          ),
          const SizedBox(height: 12),
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
                    onPressed: isRoundSet
                        ? () => provider.raiseChallenge()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRoundSet
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF1E1E1E),
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
        child: Text("EMPTY HAND", style: TextStyle(color: Colors.white24)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double cardWidth = 80;
        final int count = hand.length;
        final double centerIndex = (count - 1) / 2;

        return Stack(
          alignment: Alignment.bottomCenter,
          children: List.generate(count, (index) {
            final unit = hand[index];
            final isSelected = provider.selectedUnitIds.contains(unit.id);
            final double rotation = (index - centerIndex) * 0.15;
            final double offsetX = (index - centerIndex) * 25;

            return Positioned(
              bottom: isSelected ? 40 : 10,
              left: (width / 2) - (cardWidth / 2) + offsetX,
              child: Transform.rotate(
                angle: rotation,
                child: UnitCard(
                  unit: unit,
                  isSelected: isSelected,
                  onTap: () => provider.toggleUnitSelection(unit.id),
                ),
              ),
            );
          }),
        );
      },
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
            heading: "Objective",
            bulletPoints: ["Be the first to finish your cards."],
          ),
          DocSection(
            heading: "Rules",
            bulletPoints: [
              "Select cards from your hand.",
              "If it's the first turn, choose a Rank.",
              "Bluff if you don't have the rank cards!",
              "If caught bluffing, you pick up the pile.",
              "If you challenge someone and they were telling the truth, YOU pick up the pile.",
            ],
          ),
        ],
      ),
    );
  }
}
