import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/animations/anim_utils.dart';
// import '../../../../core/constants/dimens.dart';
import '../models/participant.dart';

class ParticipantAvatar extends StatefulWidget {
  final Participant participant;
  final double size;

  const ParticipantAvatar({
    super.key,
    required this.participant,
    this.size = 64,
  });

  @override
  State<ParticipantAvatar> createState() => _ParticipantAvatarState();
}

class _ParticipantAvatarState extends State<ParticipantAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // scale up if active
    final double effectiveSize = widget.participant.isActive
        ? widget.size * 1.1
        : widget.size;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: effectiveSize + 24, // Extra space for glow
          height: effectiveSize + 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Active Glow Ring
              if (widget.participant.isActive)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final double spread =
                        4.0 + (6.0 * _pulseAnimation.value); // 4 to 10
                    final double opacity =
                        0.4 + (0.4 * _pulseAnimation.value); // 0.4 to 0.8
                    return Container(
                      width: effectiveSize,
                      height: effectiveSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: opacity),
                            blurRadius: spread * 1.5,
                            spreadRadius: spread,
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Avatar Circle
              AnimatedContainer(
                duration: AnimUtils.fast,
                width: effectiveSize,
                height: effectiveSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceLight,
                  border: Border.all(
                    color: widget.participant.isActive
                        ? AppColors.primary
                        : AppColors.divider,
                    width: widget.participant.isActive ? 2 : 1,
                  ),
                  image: widget.participant.avatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(widget.participant.avatarUrl),
                        )
                      : null,
                ),
                child: widget.participant.avatarUrl.isEmpty
                    ? Center(
                        child: Text(
                          widget.participant.name[0].toUpperCase(),
                          style: TextStyle(
                            color: widget.participant.isActive
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: effectiveSize * 0.4,
                          ),
                        ),
                      )
                    : null,
              ),

              // Unit Count Badge
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.style,
                        size: 10,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.participant.unitCount}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: AnimUtils.fast,
          style: TextStyle(
            color: widget.participant.isActive
                ? AppColors.primary
                : AppColors.textSecondary,
            fontWeight: widget.participant.isActive
                ? FontWeight.bold
                : FontWeight.normal,
            fontSize: 12,
            shadows: widget.participant.isActive
                ? [
                    Shadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Text(widget.participant.name),
        ),
      ],
    );
  }
}
