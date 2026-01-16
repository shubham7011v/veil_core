import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_logger.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_state.dart';
import '../bloc/session_event.dart';
import '../../../../core/engine/engine.dart' as engine;
import '../widgets/session_view.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../../../../core/notifications/bloc/app_notification_bloc.dart';
import '../../../../core/notifications/bloc/app_notification_event.dart';
import '../../../../core/error/failure.dart';
import '../widgets/floating_emoji_layer.dart';
import '../utils/session_constants.dart';
import '../managers/card_animation_manager.dart';
import '../managers/turn_popup_manager.dart';
import '../managers/visual_sync_manager.dart';
import '../handlers/game_event_handler.dart';
import '../handlers/navigation_handler.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late CardAnimationManager _cardAnimations;
  late TurnPopupManager _turnPopups;
  late GameEventHandler _eventHandler;
  late NavigationHandler _navigation;
  late VisualSyncManager _visualSync;

  bool _showChat = false;
  bool _showEmoji = false;
  final List<FloatingEmoji> _activeEmojis = [];
  bool? _isWebSocket;

  // Track previous active player ID for turn change detection
  String? _previousActivePlayerId; // Tracks state updates for popups

  @override
  void initState() {
    super.initState();

    // Initialize managers
    _cardAnimations = CardAnimationManager(setState: setState);
    _turnPopups = TurnPopupManager(setState: setState);
    _visualSync = VisualSyncManager(setState: setState);
    _eventHandler = GameEventHandler(
      cardAnimations: _cardAnimations,
      turnPopups: _turnPopups,
      setState: setState,
      activeEmojis: _activeEmojis,
    );
    _navigation = NavigationHandler(
      context: context,
      setState: setState,
      cardAnimations: _cardAnimations,
      turnPopups: _turnPopups,
      activeEmojis: _activeEmojis,
      isWebSocket: () => _isWebSocket == true,
    );

    _entryController = AnimationController(
      vsync: this,
      duration: SessionDurations.entryAnimationDuration,
    );
    AppLogger.sessionEvent('Screen initialized');
    _entryController.forward();

    // Check for missed initial events (e.g. shuffling)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Signal server that client UI is ready for game start
      final handler = context.read<SessionBloc>().handler;
      handler.signalClientReady();

      final state = context.read<SessionBloc>().state;
      if (state.lastEvent == engine.SessionEventType.shuffling) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final eventTime = state.lastEventTimestamp;
        // If event happened within last 10 seconds, replay it
        if (now - eventTime < 10000) {
          AppLogger.sessionEvent('Replaying missed shuffling event');
          _eventHandler.handleEvent(
            context,
            engine.SessionEventType.shuffling,
            state,
          );
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isWebSocket == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      _isWebSocket = args is Map && args['useWebSocket'] == true;
    }
  }

  @override
  void dispose() {
    // Leave online room to clean up server state
    if (_isWebSocket == true) {
      try {
        AppLogger.sessionEvent('Leaving online room on dispose');
        di.sl.webSocketSessionHandler.leaveRoom('');
      } catch (e) {
        AppLogger.sessionError('Error leaving room on dispose', exception: e);
      }
    }
    _visualSync.dispose();
    _entryController.dispose();
    _turnPopups.dispose();
    _cardAnimations.dispose();
    super.dispose();
  }

  // All animation and event handling logic has been extracted to managers
  // See: CardAnimationManager, TurnPopupManager, GameEventHandler

  // Logic extracted to handlers: NavigationHandler, GameEventHandler, etc.

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionBlocState>(
      listenWhen: (prev, curr) =>
          (curr.lastEvent != engine.SessionEventType.none &&
              prev.lastEventTimestamp != curr.lastEventTimestamp) ||
          prev.engineState.activeParticipantId !=
              curr.engineState.activeParticipantId,
      listener: (context, state) {
        _cardAnimations.updateAvatarKeys(state);

        // Turn Change Feedback
        final currentActiveId = state.engineState.activeParticipantId;
        if (currentActiveId != _previousActivePlayerId &&
            currentActiveId != null &&
            currentActiveId.isNotEmpty) {
          if (currentActiveId == SessionIds.me) {
            HapticFeedback.mediumImpact();
            _turnPopups.showPopup("YOUR TURN");
          } else {
            HapticFeedback.lightImpact();
            final name = state.getPlayerName(currentActiveId);
            _turnPopups.showPopup("${name.toUpperCase()}'S TURN");
          }
          _previousActivePlayerId = currentActiveId;
        }

        // Failures
        if (state.failure != null) {
          bool handled = false;
          if (state.failure is ServerFailure) {
            final failure = state.failure as ServerFailure;
            if (failure.originalError is Map) {
              final data = failure.originalError as Map;
              if (data['code'] == 'ROOM_CLOSED') {
                handled = true;
                _navigation.leaveGame('/home');
              }
            }
          }

          if (!handled) {
            context.read<AppNotificationBloc>().add(
              ShowErrorNotification(state.failure!.message),
            );
            context.read<SessionBloc>().add(const SessionErrorCleared());
          }
        }

        if (_visualSync.shouldHandleEvent(state.lastEventTimestamp)) {
          _eventHandler.handleEvent(context, state.lastEvent, state);
        }

        _visualSync.updateVisualActivePlayer(state, mounted: mounted);
      },
      child: BlocBuilder<SessionBloc, SessionBlocState>(
        builder: (context, state) {
          _visualSync.initialize(state);
          final visualState = _visualSync.getVisualState(state);

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldLeave = await _navigation.showLeaveDialog();
              if (shouldLeave == true) {
                _navigation.leaveGame('/home');
              }
            },
            child: SessionView(
              state: state,
              visualState: visualState,
              entryController: _entryController,
              cardAnimations: _cardAnimations,
              turnPopups: _turnPopups,
              navigation: _navigation,
              activeEmojis: _activeEmojis,
              showChat: _showChat,
              showEmoji: _showEmoji,
              onToggleChat: () => setState(() {
                _showChat = !_showChat;
                if (_showChat) _showEmoji = false;
              }),
              onToggleEmoji: () => setState(() {
                _showEmoji = !_showEmoji;
                if (_showEmoji) _showChat = false;
              }),
              onSetChatVisible: (show) => setState(() => _showChat = show),
              onSetEmojiVisible: (show) => setState(() => _showEmoji = show),
            ),
          );
        },
      ),
    );
  }
}
