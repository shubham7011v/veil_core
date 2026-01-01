
import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../core/constants/strings.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/components/glass_container.dart';
import '../../models/participant.dart';
import '../../widgets/participant_avatar.dart';

class LobbyScreen extends StatelessWidget {
  final String roomId;
  final List<Participant> participants;
  final VoidCallback onStart;

  const LobbyScreen({
    super.key,
    required this.roomId,
    required this.participants,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    // Filter out 'me' from list to show others distinctively or just show all
    // Usually lobby shows everyone.
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Responsive.w(AppDimens.paddingL)),
          child: Column(
            children: [
              // Header
              GlassContainer(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: Responsive.h(AppDimens.paddingM)),
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
                    Text(
                      roomId,
                      style: TextStyle(
                         color: AppColors.primary,
                         fontSize: Responsive.sp(36),
                         fontWeight: FontWeight.bold,
                         letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: Responsive.h(AppDimens.paddingXL)),
              
              Text(
                 'PARTICIPANTS (${participants.length}/5)',
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
                              ParticipantAvatar(participant: p, size: Responsive.w(60)),
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
                                  color: p.isMe ? AppColors.primary : AppColors.success,
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
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                   label: 'START SESSION',
                   onPressed: onStart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
