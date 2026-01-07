import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../bloc/voice_bloc.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/notifications/bloc/app_notification_bloc.dart';
import '../../../../core/notifications/bloc/app_notification_event.dart';

class VoiceOverlay extends StatelessWidget {
  final VoiceSessionHandler sessionHandler;

  const VoiceOverlay({super.key, required this.sessionHandler});

  @override
  Widget build(BuildContext context) {
    return BlocListener<VoiceBloc, VoiceState>(
      listener: (context, state) {
        if (state.failure != null) {
          context.read<AppNotificationBloc>().add(
            ShowErrorNotification(state.failure!.message),
          );
          // In a real app we might want a VoiceErrorCleared event,
          // but for now, the Bloc handles it via state.copyWith(failure: null)
          // if we add such an event.
        }
      },
      child: BlocBuilder<VoiceBloc, VoiceState>(
        builder: (context, state) {
          return Stack(
            children: [
              // 1. Queue List (Top Right or custom position)
              if (state.queue.isNotEmpty)
                Positioned(
                  top: 80,
                  right: 16,
                  child: _buildQueueIndicator(state),
                ),

              // 2. Active Speaker Ring / Announcement
              if (state.currentSpeakerId != null)
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildSpeakerBanner(state)),
                ),

              // 3. Action Button (Bottom Right FAB style)
              Positioned(
                bottom: 100,
                right: 20,
                child: _buildActionButton(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQueueIndicator(VoiceState state) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'In Queue: ${state.queue.length}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          if (state.myQueuePosition != -1)
            Text(
              'Position: #${state.myQueuePosition + 1}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeakerBanner(VoiceState state) {
    // If it's me speaking
    if (state.isMyTurn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primary),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'SPEAKING (${state.timeRemainingS}s)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Someone else speaking
    // We assume the ID is displayed elsewhere in avatar, but this is a global banner
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'User ${state.currentSpeakerId} Speaking... (${state.timeRemainingS}s)',
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, VoiceState state) {
    // 1. My Turn -> Show nothing (Mic is open) or visualizer
    // Actually, user wants a button? "Walkie Talkie Flow: User taps Raise Hand... Mic opens automatically"
    // So the button is for raising/lowering hand.

    // If I'm speaking, the button could be "Done" (Release Mic early)
    if (state.isMyTurn) {
      return FloatingActionButton.extended(
        backgroundColor: Colors.red,
        onPressed: () {
          sessionHandler.raiseHand(); // Toggle off
        },
        label: const Text('DONE'),
        icon: const Icon(Icons.mic_off),
      );
    }

    // If I'm queued
    if (state.myQueuePosition != -1) {
      return FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        onPressed: () {
          sessionHandler.raiseHand(); // Toggle off (Cancel)
        },
        label: Text('WAITING #${state.myQueuePosition + 1}'),
        icon: const Icon(Icons.hourglass_empty),
      );
    }

    // Default: Raise Hand
    return FloatingActionButton.extended(
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.primary,
      onPressed: () {
        sessionHandler.raiseHand();
      },
      label: const Text('SPEAK'),
      icon: const Icon(Icons.back_hand),
    );
  }
}
