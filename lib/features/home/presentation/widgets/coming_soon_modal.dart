import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/colors.dart';

class ComingSoonModal extends StatefulWidget {
  final String featureName;
  final String description;
  final IconData icon;
  final AppColorPalette palette;
  final List<Map<String, dynamic>>? featureHighlights;

  const ComingSoonModal({
    super.key,
    required this.featureName,
    required this.description,
    required this.icon,
    required this.palette,
    this.featureHighlights,
  });

  @override
  State<ComingSoonModal> createState() => _ComingSoonModalState();
}

class _ComingSoonModalState extends State<ComingSoonModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: widget.palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.palette.primary.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.palette.primary.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.palette.primary.withValues(alpha: 0.15),
                        widget.palette.primaryDim.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Animated Icon
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, value, child) {
                          return Transform.rotate(
                            angle: value * 0.1,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    widget.palette.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    widget.palette.primaryDim.withValues(
                                      alpha: 0.1,
                                    ),
                                  ],
                                ),
                                border: Border.all(
                                  color: widget.palette.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                widget.icon,
                                size: 56,
                                color: widget.palette.primary,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // "Coming Soon" Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.palette.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.palette.primary.withValues(
                              alpha: 0.3,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: widget.palette.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'COMING SOON',
                              style: GoogleFonts.inter(
                                color: widget.palette.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Section
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Feature Name
                      Text(
                        widget.featureName,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          color: widget.palette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        widget.description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: widget.palette.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Feature Highlights
                      // Feature Highlights
                      if (widget.featureHighlights != null)
                        ...widget.featureHighlights!.map(
                          (highlight) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildFeatureHighlight(
                              highlight['icon'] as IconData,
                              highlight['text'] as String,
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Close Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.palette.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'GOT IT',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureHighlight(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.palette.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: widget.palette.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: widget.palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}
