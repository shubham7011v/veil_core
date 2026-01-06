import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../core/utils/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../core/di/service_locator.dart' as di;
import '../../../../core/engine/data/handlers/websocket_session_handler.dart';
import '../../../session/presentation/bloc/session_bloc.dart';
import '../../../session/presentation/bloc/session_event.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/engine/domain/models/room_event.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _nameController = TextEditingController(text: 'Royal Lounge #88');
  final _passwordController = TextEditingController();

  int _selectedPlayerCount = 5;
  bool _voiceChat = true;
  bool _spectatorMode = false;
  bool _isPrivate = true; // Default to private based on flow
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateRoom() async {
    if (!_isPrivate) {
      // Public match - redirect to matchmaking for now
      Navigator.pushNamed(context, '/matchmaking');
      return;
    }

    setState(() => _isCreating = true);

    try {
      // 1. Get Token
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null
          ? await user.getIdToken()
          : 'mock_token_${DateTime.now().millisecondsSinceEpoch}';

      // 2. Connect
      final handler =
          di.sl.createSessionHandler(online: true) as WebSocketSessionHandler;
      // TODO: Use real URL from config
      await handler.connect(
        'wss://rebelliously-unforgone-mandie.ngrok-free.dev/ws',
        token!,
      );

      // 3. Update Bloc
      if (!mounted) return;
      context.read<SessionBloc>().add(SessionHandlerSwapped(handler));

      // 4. Create Room
      await handler.createPrivateRoom(
        roomName: _nameController.text,
        password: _passwordController.text.isEmpty
            ? null
            : _passwordController.text,
        maxPlayers: _selectedPlayerCount,
        bootAmount: 0, // Boot amount removed from UI, defaulting to 0 for now
        voiceChat: _voiceChat,
        spectatorMode: _spectatorMode,
      );

      // 5. Listen for success
      // We can listen to the stream here or in the Lobby.
      // For smoother UX, let's wait for the event here before navigating.
      handler.roomEventStream.listen((event) {
        if (event is RoomCreated) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/lobby');
          }
        }
      });

      // Cleanup subscription handled by stream closing or navigation?
      // Ideally managing subscriptions is better, but for this one-shot navigation it's ok.
      // The handler persists in the Bloc.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create room: $e')));
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'CREATE ROOM',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: Responsive.sp(18),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Image Placeholder
                    Container(
                      height: Responsive.h(180),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.surfaceLight,
                            AppColors.primary.withValues(alpha: 0.1),
                            AppColors.background,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppDimens.radiusL),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            top: -20,
                            child: Icon(
                              Icons.auto_awesome,
                              size: 100,
                              color: AppColors.primary.withValues(alpha: 0.05),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Icon(
                                Icons.casino_outlined,
                                size: 64,
                                color: AppColors.primary.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              margin: EdgeInsets.all(
                                Responsive.w(AppDimens.paddingM),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CLASSIC MODE',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: Responsive.sp(10),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.h(AppDimens.paddingL)),

                    // Room Type
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPrivate = false),
                            child: _buildRoomTypeOption(
                              'Public Match',
                              !_isPrivate,
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.w(AppDimens.paddingM)),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPrivate = true),
                            child: _buildRoomTypeOption(
                              'Private Room',
                              _isPrivate,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(AppDimens.paddingL)),

                    // Room Name Input
                    Text(
                      'ROOM NAME',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: Responsive.sp(12),
                      ),
                    ),
                    SizedBox(height: Responsive.h(8)),
                    _buildTextField(
                      controller: _nameController,
                      icon: Icons.meeting_room,
                      hint: 'Room Name',
                    ),

                    SizedBox(height: Responsive.h(AppDimens.paddingL)),

                    // Password
                    Text(
                      'PASSWORD (OPTIONAL)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: Responsive.sp(12),
                      ),
                    ),
                    SizedBox(height: Responsive.h(8)),
                    _buildTextField(
                      controller: _passwordController,
                      icon: Icons.lock,
                      hint: 'Set a secure password',
                      isPassword: true,
                    ),

                    SizedBox(height: Responsive.h(AppDimens.paddingXL)),

                    SizedBox(height: Responsive.h(AppDimens.paddingXL)),

                    // Player Count
                    const Text(
                      'NUMBER OF PLAYERS',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: Responsive.h(AppDimens.paddingM)),
                    // Player Count Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_selectedPlayerCount',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: Responsive.sp(24),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.surfaceLight,
                              thumbColor: AppColors.primary,
                              overlayColor: AppColors.activeGlow,
                            ),
                            child: Slider(
                              value: _selectedPlayerCount.toDouble(),
                              min: 2,
                              max: 10,
                              divisions: 8,
                              label: '$_selectedPlayerCount Players',
                              onChanged: (val) => setState(
                                () => _selectedPlayerCount = val.toInt(),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '10',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: Responsive.sp(12),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.h(AppDimens.paddingXL)),

                    // Toggles
                    _buildToggle(
                      'Voice Chat',
                      'Allow participants to talk',
                      _voiceChat,
                      (v) => setState(() => _voiceChat = v),
                    ),
                    SizedBox(height: Responsive.h(AppDimens.paddingM)),
                    _buildToggle(
                      'Spectator Mode',
                      'Allow friends to watch',
                      _spectatorMode,
                      (v) => setState(() => _spectatorMode = v),
                    ),

                    const SizedBox(height: 100), // Bottom padding
                  ],
                ),
              ),
            ),

            // Bottom Bar
            Container(
              padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                children: [
                  // Fee display removed
                  const SizedBox.shrink(),
                  SizedBox(height: Responsive.h(AppDimens.paddingM)),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Create Room',
                      icon: Icons.arrow_forward,
                      onPressed: _isCreating ? null : _handleCreateRoom,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTypeOption(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        border: isSelected ? null : Border.all(color: AppColors.divider),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : AppColors.textSecondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusS),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textTertiary),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          suffixIcon: isPassword
              ? const Icon(Icons.visibility_off, color: AppColors.textTertiary)
              : null,
        ),
      ),
    );
  }

  Widget _buildToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              value ? Icons.mic : Icons.visibility,
              color: AppColors.primaryDim,
              size: 20,
            ),
          ),
          SizedBox(width: Responsive.w(AppDimens.paddingM)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryDim,
          ),
        ],
      ),
    );
  }
}
