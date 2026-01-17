import 'package:flutter/material.dart';
import '../../../../core/engine/engine.dart' as engine;
import '../../../../core/theme/colors.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../bloc/session_state.dart';
import '../utils/session_constants.dart';
import '../widgets/session_top_bar.dart';
import '../widgets/opponent_row.dart';
import '../widgets/game_table_view.dart';
import '../widgets/session_background.dart';
import '../widgets/game_win_overlay.dart';
import '../widgets/session_staging_area.dart';
import '../widgets/session_bottom_controls.dart';
import '../widgets/flying_cards_layer.dart';
import '../widgets/floating_emoji_layer.dart';
import '../../../game/presentation/widgets/chat_widget.dart';
import '../../../game/presentation/widgets/emoji_picker.dart';
import '../widgets/rank_selector_modal.dart';
import '../../../voice/presentation/widgets/voice_overlay.dart';
import '../managers/card_animation_manager.dart';
import '../managers/turn_popup_manager.dart';
import '../handlers/navigation_handler.dart';

class SessionView extends StatelessWidget {
  final SessionBlocState state;
  final SessionBlocState visualState;
  final AnimationController entryController;
  final CardAnimationManager cardAnimations;
  final TurnPopupManager turnPopups;
  final NavigationHandler navigation;
  final List<FloatingEmoji> activeEmojis;
  final bool showChat;
  final bool showEmoji;
  final VoidCallback onToggleChat;
  final VoidCallback onToggleEmoji;
  final void Function(bool show) onSetChatVisible;
  final void Function(bool show) onSetEmojiVisible;

  const SessionView({
    super.key,
    required this.state,
    required this.visualState,
    required this.entryController,
    required this.cardAnimations,
    required this.turnPopups,
    required this.navigation,
    required this.activeEmojis,
    required this.showChat,
    required this.showEmoji,
    required this.onToggleChat,
    required this.onToggleEmoji,
    required this.onSetChatVisible,
    required this.onSetEmojiVisible,
  });

  @override
  Widget build(BuildContext context) {
    final showSpectatorView = state.engineState.isSpectator;

    Widget content = Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          const SessionBackground(),
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                _buildAnimatedEntry(
                  controller: entryController,
                  interval: const Interval(
                    0.0,
                    0.4,
                    curve: Curves.easeOutCubic,
                  ),
                  slideBegin: const Offset(0, -0.5),
                  child: SessionTopBar(
                    state: visualState,
                    onChatTap: onToggleChat,
                  ),
                ),

                // Opponents
                _buildAnimatedEntry(
                  controller: entryController,
                  interval: const Interval(
                    0.1,
                    0.5,
                    curve: Curves.easeOutCubic,
                  ),
                  slideBegin: const Offset(0, -0.2),
                  child: OpponentRow(
                    state: visualState,
                    avatarKeys: cardAnimations.avatarKeys,
                  ),
                ),
                const SizedBox(height: 10),

                // Center Pile
                Expanded(
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        ScaleTransition(
                          scale: CurvedAnimation(
                            parent: entryController,
                            curve: const Interval(
                              0.2,
                              0.7,
                              curve: Curves.elasticOut,
                            ),
                          ),
                          child: GameTableView(
                            state: visualState,
                            pileKey: cardAnimations.pileKey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Feedback Popups
                turnPopups.buildPopup() ??
                    (showSpectatorView
                        ? const SizedBox.shrink()
                        : _buildAnimatedEntry(
                            controller: entryController,
                            interval: const Interval(
                              0.4,
                              0.8,
                              curve: Curves.easeOutCubic,
                            ),
                            slideBegin: const Offset(0, 0.2),
                            child: SessionStagingArea(
                              key: cardAnimations.stagingKey,
                              state: visualState,
                              myAvatarKey:
                                  cardAnimations.avatarKeys[SessionIds.me]!,
                            ),
                          )),
                const SizedBox(height: 2),

                // Bottom Controls
                if (!showSpectatorView)
                  _buildAnimatedEntry(
                    controller: entryController,
                    interval: const Interval(
                      0.5,
                      1.0,
                      curve: Curves.easeOutCubic,
                    ),
                    slideBegin: const Offset(0, 0.5),
                    child: SessionBottomControls(
                      state: visualState,
                      myAvatarKey: cardAnimations.avatarKeys[SessionIds.me]!,
                    ),
                  )
                else
                  _buildSpectatorLabel(),
              ],
            ),
          ),

          if (state.engineState.currentPhase == engine.SessionPhase.finished &&
              state.engineState.winnerId != null)
            _buildWinOverlay(),

          _buildActionLayers(),

          // Voice Overlay
          if (di.sl.voiceSessionHandler != null && FeatureFlags.enableVoiceChat)
            Positioned.fill(
              child: VoiceOverlay(sessionHandler: di.sl.voiceSessionHandler!),
            ),
        ],
      ),
    );

    return Stack(
      children: [
        content,
        if (showChat && FeatureFlags.enableGameChat) _buildChatOverlay(),
        if (showEmoji && FeatureFlags.enableGameChat)
          _buildEmojiOverlay(context),
        if (!showSpectatorView && FeatureFlags.enableGameChat)
          _buildEmojiToggle(context),

        // Rank Selection Modal
        RankSelectorModal(state: state),
      ],
    );
  }

  Widget _buildAnimatedEntry({
    required AnimationController controller,
    required Interval interval,
    required Offset slideBegin,
    required Widget child,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: slideBegin,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: controller, curve: interval)),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: controller,
          curve: Interval(interval.begin, interval.end, curve: Curves.easeOut),
        ),
        child: child,
      ),
    );
  }

  Widget _buildSpectatorLabel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.textTertiary),
        ),
        child: const Text(
          'SPECTATING',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildWinOverlay() {
    return GameWinOverlay(
      winnerId: state.engineState.winnerId!,
      winnerName: state.getPlayerName(state.engineState.winnerId!),
      coinsEarned: state.engineState.winnerId == SessionIds.me ? 400 : -100,
      gameLog: state.gameLog,
      matchStats: state.gameStartTime != null
          ? state.matchStats.copyWith(
              matchDuration: DateTime.now().difference(state.gameStartTime!),
            )
          : state.matchStats,
      onBackToHome: () => navigation.leaveGame('/home'),
      onPlayAgain: () => navigation.leaveGame('/matchmaking'),
    );
  }

  Widget _buildActionLayers() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            FlyingCardsLayer(activeAnimations: cardAnimations.flyingCards),
            if (FeatureFlags.enableGameChat)
              FloatingEmojiLayer(activeEmojis: activeEmojis),
          ],
        ),
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Positioned(
      bottom: 100,
      left: 16,
      child: ChatWidget(onClose: () => onSetChatVisible(false)),
    );
  }

  Widget _buildEmojiOverlay(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height / 2 - 140,
      right: 16,
      child: EmojiPicker(onClose: () => onSetEmojiVisible(false)),
    );
  }

  Widget _buildEmojiToggle(BuildContext context) {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height / 2 - 24,
      child: FloatingActionButton.small(
        heroTag: 'emoji_btn_fixed',
        backgroundColor: AppColors.surfaceLight,
        onPressed: onToggleEmoji,
        child: const Icon(Icons.emoji_emotions_outlined, color: Colors.white),
      ),
    );
  }
}
