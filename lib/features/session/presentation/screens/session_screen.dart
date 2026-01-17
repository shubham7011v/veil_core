import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_logger.dart';
import '../bloc/session_bloc.dart';
import '../bloc/session_state.dart';

import '../../../../core/engine/engine.dart' as engine;
import '../widgets/session_view.dart';
import '../../../../core/notifications/bloc/app_notification_bloc.dart';
import '../../../../core/notifications/bloc/app_notification_event.dart';
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
    // Note: Leave logic is now handled largely by Bloc/Handler, but clean exit is good.
    // However, Bloc should manage session lifecycle via events if needed.
    // For now, Managers need disposal.
    _visualSync.dispose();
    _entryController.dispose();
    _turnPopups.dispose();
    _cardAnimations.dispose();
    super.dispose();
  }

  void _handleSideEffect(BuildContext context, SessionSideEffect effect) {
    if (effect is SessionNavigateToHome) {
      _navigation.leaveGame('/home');
    } else if (effect is SessionShowTurnPopup) {
      _turnPopups.showPopup(effect.message);
    } else if (effect is SessionTriggerHaptic) {
      if (effect.isLight) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } else if (effect is SessionShowSnackBar) {
      context.read<AppNotificationBloc>().add(
        effect.isError
            ? ShowErrorNotification(effect.message)
            : ShowSuccessNotification(effect.message),
      );
    } else if (effect is SessionShowErrorNotification) {
      context.read<AppNotificationBloc>().add(
        ShowErrorNotification(effect.message),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionBlocState>(
      listenWhen: (prev, curr) =>
          curr.effect != null ||
          (curr.lastEvent != engine.SessionEventType.none &&
              prev.lastEventTimestamp != curr.lastEventTimestamp),
      listener: (context, state) {
        // Handle Side Effects
        if (state.effect != null) {
          _handleSideEffect(context, state.effect!);
        }

        // Handle Visual Sync & Events
        _cardAnimations.updateAvatarKeys(state);

        // Turn feedback is now handled via Side Effects or explicit state checks if needed,
        // but let's keep event handler for strictly visual game events.
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
                // Trigger event instead of direct nav?
                // For now, keep navigation handler logic consistently
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
