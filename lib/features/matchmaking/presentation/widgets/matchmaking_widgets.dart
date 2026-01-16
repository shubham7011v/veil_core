import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/engine/engine.dart';

class MatchmakingConnectionBanner extends StatelessWidget {
  final ConnectionStatus status;
  final AnimationController pulseController;

  const MatchmakingConnectionBanner({
    super.key,
    required this.status,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionStatus.connected) return const SizedBox.shrink();

    final isReconnecting =
        status == ConnectionStatus.reconnecting ||
        status == ConnectionStatus.connecting;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
      ),
      child: Container(
        width: double.infinity,
        color: isReconnecting ? Colors.orangeAccent : Colors.redAccent,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReconnecting ? Icons.sync : Icons.error_outline,
              color: Colors.black,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              isReconnecting ? 'Reconnecting to server...' : 'Connection Lost',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParticipantCard extends StatelessWidget {
  final Participant participant;

  const ParticipantCard({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(width: 120, height: 160),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: participant.isMe ? const Color(0xFFE5A043) : Colors.white10,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2C2C2C),
              image:
                  (participant.avatarUrl != null &&
                      participant.avatarUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(participant.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              border: Border.all(
                color: participant.isMe
                    ? const Color(0xFFE5A043)
                    : const Color(0xFF4CAF50),
                width: 2,
              ),
            ),
            child:
                (participant.avatarUrl == null ||
                    participant.avatarUrl!.isEmpty)
                ? Center(
                    child: Text(
                      participant.name.isNotEmpty
                          ? participant.name[0].toUpperCase()
                          : 'P',
                      style: GoogleFonts.cinzel(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              participant.isMe ? 'Me' : participant.name,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          if (participant.rank != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                participant.rank!.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xFFE5A043),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class EmptySlot extends StatelessWidget {
  const EmptySlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(width: 120, height: 160),

      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10, width: 2),
            ),
            child: Icon(
              Icons.person_outline,
              color: Colors.white.withValues(alpha: 0.2),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting...',
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class MatchmakingOrbit extends StatelessWidget {
  final AnimationController controller;

  const MatchmakingOrbit({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(4, (index) {
            final double offset = (index * 2 * math.pi / 4);
            final double angle = controller.value * 2 * math.pi + offset;
            final double radius = 60.0;

            return Transform.translate(
              offset: Offset(
                math.cos(angle) * radius,
                math.sin(angle) * radius * 0.3,
              ),
              child: Transform.rotate(
                angle: angle + math.pi / 2,
                child: _buildFacingDownCard(),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildFacingDownCard() {
    return Container(
      width: 60,
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE5A043).withValues(alpha: 0.3),
          width: 1,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      child: Center(
        child: Container(
          width: 40,
          height: 70,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFE5A043).withValues(alpha: 0.1),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.style,
            color: const Color(0xFFE5A043).withValues(alpha: 0.1),
            size: 24,
          ),
        ),
      ),
    );
  }
}
