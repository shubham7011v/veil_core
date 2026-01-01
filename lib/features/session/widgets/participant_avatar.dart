import 'package:flutter/material.dart';
import '../models/participant.dart';

class ParticipantAvatar extends StatefulWidget {
  final Participant participant;
  final double size;
  final String? statusText; // e.g. "PLAYING", "FOLDED"

  const ParticipantAvatar({
    super.key,
    required this.participant,
    this.size = 60,
    this.statusText,
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
    final isActive = widget.participant.isActive;
    // Default size is 60, scaling slightly for active
    final double effectiveSize = isActive ? widget.size * 1.1 : widget.size;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Active Glow Ring
            if (isActive)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final double spread = 4.0 + (4.0 * _pulseAnimation.value);
                  return Container(
                    width: effectiveSize,
                    height: effectiveSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFFD700,
                          ).withValues(alpha: 0.5), // Gold glow
                          blurRadius: spread * 2,
                          spreadRadius: spread,
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Avatar Image/Placeholder
            Container(
              width: effectiveSize,
              height: effectiveSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2C2C2C),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF4A4A4A),
                  width: isActive ? 3 : 2,
                ),
                image: widget.participant.avatarUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(widget.participant.avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.participant.avatarUrl.isEmpty
                  ? Center(
                      child: Text(
                        widget.participant.name.isNotEmpty
                            ? widget.participant.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: effectiveSize * 0.4,
                        ),
                      ),
                    )
                  : null,
            ),

            // Card Count / Bet Badge
            // Placed at Bottom Right (overlapping)
            Positioned(
              right: -4,
              bottom: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF3E2723), // Dark Brown
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD7CCC8), width: 1),
                ),
                child: Center(
                  child: Text(
                    '${widget.participant.unitCount}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // Status Pill (Optional, if Active or statusText provided)
            if (isActive || widget.statusText != null)
              Positioned(
                bottom: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300), // Amber
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.statusText ?? 'PLAYING',
                    style: const TextStyle(
                      color: Colors.black, // Dark text on amber
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14), // Space for status pill
        Text(
          widget.participant.name,
          style: TextStyle(
            color: isActive ? const Color(0xFFFFD700) : Colors.white70,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
