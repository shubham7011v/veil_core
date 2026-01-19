import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../session/session.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/game_constants.dart';
import '../bloc/matchmaking_bloc.dart';
import '../bloc/matchmaking_event.dart';
import '../bloc/matchmaking_state.dart';
import '../widgets/matchmaking_connection_banner.dart';

import '../widgets/matchmaking_orbit.dart';
import '../widgets/matchmaking_header.dart';
import '../widgets/matchmaking_status_view.dart';
import '../widgets/matchmaking_participants_grid.dart';

class MatchmakingScreen extends StatelessWidget {
  const MatchmakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MatchmakingBloc(
        handler: sl.webSocketSessionHandler,
        authRepository: sl.authRepository,
      )..add(StartMatchmaking()),
      child: const _MatchmakingView(),
    );
  }
}

class _MatchmakingView extends StatefulWidget {
  const _MatchmakingView();

  @override
  State<_MatchmakingView> createState() => _MatchmakingViewState();
}

class _MatchmakingViewState extends State<_MatchmakingView>
    with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      duration: GameConstants.matchmakingOrbitDuration,
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: GameConstants.pulseAnimationDuration,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onHomeSideEffect(
    BuildContext context,
    MatchmakingSideEffect effect,
    AppColorPalette palette,
  ) {
    if (effect is MatchmakingNavigateToSession) {
      if (_hasNavigated) return;
      _hasNavigated = true;

      AppLogger.info('🎉 [MatchmakingScreen] Match found! Navigating...');

      Future.delayed(
        Duration(seconds: AppConfig.instance.matchmakingDelaySeconds),
        () {
          if (context.mounted) {
            final isOnline = effect.isOnline;
            Navigator.pushReplacementNamed(
              context,
              '/session',
              arguments: {'useWebSocket': isOnline},
            );
          }
        },
      );
    } else if (effect is MatchmakingTriggerHaptic) {
      HapticFeedback.selectionClick();
    } else if (effect is MatchmakingShowSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(effect.message),
          backgroundColor: effect.isError ? palette.danger : palette.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (effect is MatchmakingPop) {
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        final palette = AppColors.getPalette(themeState.mode);

        return BlocListener<MatchmakingBloc, MatchmakingState>(
          listenWhen: (previous, current) =>
              current.effect != null ||
              (current.connectionStatus == ConnectionStatus.connected &&
                  !current.isConnecting &&
                  previous.connectionStatus != current.connectionStatus),
          listener: (context, state) {
            // Handler Swap Logic
            if (state.connectionStatus == ConnectionStatus.connected &&
                !state.isConnecting) {
              AppLogger.info(
                '🔄 [MatchmakingScreen] Swapping handler with SessionBloc',
              );
              context.read<SessionBloc>().add(
                SessionHandlerSwapped(context.read<MatchmakingBloc>().handler),
              );
            }

            if (state.effect != null) {
              _onHomeSideEffect(context, state.effect!, palette);
            }
          },
          child: BlocBuilder<MatchmakingBloc, MatchmakingState>(
            builder: (context, state) {
              return Scaffold(
                backgroundColor: palette.background,
                body: Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [palette.background, palette.surface],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          MatchmakingHeader(
                            secondsRemaining: state.secondsRemaining,
                            onClose: () {
                              context.read<MatchmakingBloc>().add(
                                CancelMatchmaking(),
                              );
                              Navigator.pop(context);
                            },
                            palette: palette,
                            pulseAnimation: _pulseController,
                          ),
                          MatchmakingConnectionBanner(
                            status: state.connectionStatus,
                            pulseController: _pulseController,
                          ),
                          const SizedBox(height: 24),
                          MatchmakingStatusView(
                            isMatchFound: state.isMatchFound,
                            participantCount: state.participants.length,
                            palette: palette,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 140,
                            child: MatchmakingOrbit(
                              controller: _orbitController,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Expanded(
                            child: MatchmakingParticipantsGrid(
                              participants: state.participants,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
