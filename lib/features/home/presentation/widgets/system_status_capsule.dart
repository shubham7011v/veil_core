import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/models/system_status.dart';
import 'system_status_diagnostics_modal.dart';

class SystemStatusCapsule extends StatelessWidget {
  final SystemStatus systemStatus;
  final AppColorPalette palette;

  const SystemStatusCapsule({
    super.key,
    required this.systemStatus,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDiagnosticsModal(context, systemStatus),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: systemStatus.statusColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: systemStatus.statusColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: systemStatus.statusColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              systemStatus.label.toUpperCase(),
              style: GoogleFonts.inter(
                color: palette.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 12),
            Container(height: 10, width: 1, color: palette.divider),
            const SizedBox(width: 8),
            Icon(systemStatus.icon, size: 12, color: systemStatus.statusColor),
          ],
        ),
      ),
    );
  }

  void _showDiagnosticsModal(BuildContext context, SystemStatus status) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          SystemStatusDiagnosticsModal(status: status, palette: palette),
    );
  }
}
