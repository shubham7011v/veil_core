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
    final double effectiveSize = isActive ? widget.size * 1.15 : widget.size;

    return Opacity(
      opacity: isActive ? 1.0 : 0.7, // Dim inactive players
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Premium Active Glow Ring
              if (isActive)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final double spread = 6.0 + (6.0 * _pulseAnimation.value);
                    return Container(
                      width: effectiveSize,
                      height: effectiveSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFFD700,
                            ).withValues(alpha: 0.6),
                            blurRadius: spread * 2,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Avatar Image / Border
              Container(
                width: effectiveSize,
                height: effectiveSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E1E1E),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF3E3E3E),
                    width: isActive ? 2.5 : 1.5,
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

              // Unit Count Badge (Circular & Premium)
              Positioned(
                right: -4,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4E342E),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${widget.participant.unitCount}',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),

              // Status Pill (Premium Amber)
              if (isActive || widget.statusText != null)
                Positioned(
                  bottom: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.statusText ?? (isActive ? 'PLAYING' : 'WAITING'),
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.participant.name,
            style: TextStyle(
              fontFamily: 'Inter',
              color: isActive
                  ? const Color(0xFFFFD700)
                  : Colors.white.withValues(alpha: 0.702),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              height: 1.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
