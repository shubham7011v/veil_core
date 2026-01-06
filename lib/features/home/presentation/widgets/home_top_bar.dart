import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/data/models/user_model.dart';
import '../../../auth/auth.dart';

class HomeTopBar extends StatefulWidget {
  final UserModel? user;
  final UserStats? stats;
  final AppColorPalette palette;

  const HomeTopBar({
    super.key,
    required this.user,
    required this.stats,
    required this.palette,
  });

  @override
  State<HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends State<HomeTopBar> {
  bool _showNickName = false;

  @override
  void initState() {
    super.initState();
    _loadNamePreference();
  }

  Future<void> _loadNamePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showNickName = prefs.getBool('show_nickname') ?? false;
      });
    }
  }

  Future<void> _toggleNameDisplay() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !_showNickName;
    await prefs.setBool('show_nickname', newValue);
    if (mounted) {
      setState(() {
        _showNickName = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String greeting = sl.greetingService.getTimeBasedGreeting();

    // Logic for toggle:
    // If _showNickName is true, try to show the Go stats name (Nick Name).
    // If false, show the Firebase user name (FirstName).
    // Fallback if either is missing.
    String displayName;

    if (_showNickName) {
      // Go Nickname
      displayName =
          widget.stats?.name ?? widget.user?.firstName ?? 'Mysterious Player';
      // If stats name is empty or default 'Unknown', maybe fallback?
      // UserStats defaults name to 'Unknown' if missing.
      if (displayName == 'Unknown') {
        displayName = widget.user?.firstName ?? 'Mysterious Player';
      }
    } else {
      // Firebase User Name
      displayName =
          widget.user?.firstName ?? widget.stats?.name ?? 'Mysterious Player';
    }

    final String photoUrl = widget.user?.photoUrl ?? '';
    final String rank = widget.stats?.rank ?? widget.user?.rank ?? 'Novice';
    final int coins = widget.stats?.coins ?? widget.user?.coins ?? 1000;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: widget.palette.textTertiary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleNameDisplay,
                      onLongPress: () {
                        if (_showNickName) {
                          _showEditNicknameDialog(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Switch to Nickname (tap) to edit it.',
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cinzel(
                          color: widget.palette.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 30,
                backgroundColor: widget.palette.primary.withValues(alpha: 0.1),
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Icon(
                        Icons.person,
                        size: 20,
                        color: widget.palette.primary,
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip(
                'Rank',
                rank,
                widget.palette.primary,
                widget.palette,
              ),
              _buildInfoChip(
                'Coins',
                coins.toString(),
                widget.palette.primary,
                widget.palette,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    String label,
    String value,
    Color color,
    AppColorPalette palette,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: palette.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: GoogleFonts.cinzel(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (label == 'Coins' &&
                int.tryParse(value) != null &&
                int.parse(value) < 100)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: GestureDetector(
                  onTap: () {
                    sl.webSocketSessionHandler.refillCoins();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Refilling coins...')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.primaryDim,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'REFILL',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showEditNicknameDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController.fromValue(
      TextEditingValue(
        text: widget.stats?.name ?? '',
        selection: TextSelection.collapsed(
          offset: widget.stats?.name.length ?? 0,
        ),
      ),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: widget.palette.surface,
          title: Text(
            'Edit Nickname',
            style: GoogleFonts.cinzel(color: widget.palette.primary),
          ),
          content: TextField(
            controller: controller,
            style: GoogleFonts.inter(color: widget.palette.textPrimary),
            decoration: InputDecoration(
              labelText: 'New Nickname',
              labelStyle: TextStyle(color: widget.palette.textSecondary),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: widget.palette.primary),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: widget.palette.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: widget.palette.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  sl.webSocketSessionHandler.updateNickname(newName);
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Save',
                style: TextStyle(color: widget.palette.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}
