import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/components/glass_container.dart';
import '../../../../core/engine/engine.dart';
import '../bloc/session_bloc.dart'; // Correct relative path

import '../bloc/session_state.dart'; // Ensure SessionBlocState is available
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../bloc/session_event.dart';
import '../../../../core/notifications/bloc/app_notification_bloc.dart';
import '../../../../core/notifications/bloc/app_notification_event.dart';
import '../widgets/participant_avatar.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return BlocConsumer<SessionBloc, SessionBlocState>(
      listener: (context, state) {
        // Handle Failures
        if (state.failure != null) {
          context.read<AppNotificationBloc>().add(
            ShowErrorNotification(state.failure!.message),
          );
          // Auto-clear error after showing notification
          context.read<SessionBloc>().add(const SessionErrorCleared());
        }

        // If game starts, navigate to session
        if (state.engineState.currentPhase != SessionPhase.lobby) {
          final useWebSocket =
              context.read<SessionBloc>().handler is WebSocketSessionHandler;
          Navigator.pushReplacementNamed(
            context,
            '/session',
            arguments: {'useWebSocket': useWebSocket},
          );
        }
      },
      builder: (context, state) {
        final participants = state.engineState.participants;
        final roomId = state.engineState.roomId;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                // Leave room if connected via WebSocket
                final bloc = context.read<SessionBloc>();
                if (bloc.handler is WebSocketSessionHandler) {
                  (bloc.handler as WebSocketSessionHandler).leaveRoom(roomId);
                }
                Navigator.pop(context);
              },
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(Responsive.w(AppDimens.paddingL)),
              child: Column(
                children: [
                  // Header
                  GlassContainer(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.h(AppDimens.paddingM),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ROOM CODE',
                          style: TextStyle(
                            color: AppColors.primaryDim,
                            letterSpacing: 2,
                            fontSize: Responsive.sp(12),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: Responsive.h(8)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              roomId,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: Responsive.sp(36),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(
                                Icons.copy,
                                color: AppColors.primaryDim,
                              ),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: roomId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Room code copied!'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: Responsive.h(AppDimens.paddingXL)),

                  Text(
                    'PARTICIPANTS (${participants.length}/10)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                      fontSize: Responsive.sp(12),
                    ),
                  ),

                  SizedBox(height: Responsive.h(AppDimens.paddingM)),

                  // List
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: Responsive.w(AppDimens.paddingM),
                        mainAxisSpacing: Responsive.h(AppDimens.paddingM),
                        childAspectRatio: 0.8,
                      ),
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        final p = participants[index];
                        return GlassContainer(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ParticipantAvatar(
                                participant: p,
                                size: Responsive.w(60),
                              ),
                              SizedBox(height: Responsive.h(12)),
                              Text(
                                p.name,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: Responsive.sp(14),
                                ),
                              ),
                              SizedBox(height: Responsive.h(4)),
                              Text(
                                p.isMe ? '(You)' : 'Ready',
                                style: TextStyle(
                                  color: p.isMe
                                      ? AppColors.primary
                                      : AppColors.success,
                                  fontSize: Responsive.sp(12),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: Responsive.h(AppDimens.paddingM)),

                  // Action
                  if (participants.length >= 2)
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: 'START SESSION',
                        onPressed: () {
                          final bloc = context.read<SessionBloc>();
                          if (bloc.handler is WebSocketSessionHandler) {
                            (bloc.handler as WebSocketSessionHandler)
                                .startPrivateGame(roomId);
                          }
                        },
                      ),
                    )
                  else
                    Text(
                      'Waiting for players...',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
