import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/engine/engine.dart';

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
