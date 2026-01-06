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
import '../../../../core/config/app_config.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isJoining = false;
  bool _isSpectator = false;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleJoinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isJoining = true);

    try {
      // 1. Get Token
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null
          ? await user.getIdToken()
          : 'mock_token_${DateTime.now().millisecondsSinceEpoch}';

      // 2. Connect
      final handler =
          di.sl.createSessionHandler(online: true) as WebSocketSessionHandler;
      await handler.connect(AppConfig.instance.serverUrl, token!);
      // 3. Update Bloc
      if (!mounted) return;
      context.read<SessionBloc>().add(SessionHandlerSwapped(handler));

      // 4. Join Room
      await handler.joinPrivateRoom(
        code,
        password: _passwordController.text.isEmpty
            ? null
            : _passwordController.text,
        isSpectator: _isSpectator,
      );

      // 5. Listen for success
      handler.roomEventStream.listen((event) {
        if (event is RoomJoined) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/lobby');
          }
        } else if (event is RoomError) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: ${event.message}')));
            setState(() => _isJoining = false);
          }
        }
      });
      // Note: handler persists in Bloc, subscription can be managed if needed.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to join room: $e')));
        setState(() => _isJoining = false);
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
          'JOIN ROOM',
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
        child: Padding(
          padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ENTER ROOM CODE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: Responsive.sp(12),
                ),
              ),
              SizedBox(height: Responsive.h(8)),
              _buildTextField(
                controller: _codeController,
                icon: Icons.vpn_key,
                hint: 'e.g. ABC123',
                isUppercase: true,
              ),

              SizedBox(height: Responsive.h(AppDimens.paddingL)),

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
                hint: 'Room password',
                isPassword: true,
              ),

              SizedBox(height: Responsive.h(AppDimens.paddingM)),

              // Spectator Toggle
              Row(
                children: [
                  Checkbox(
                    value: _isSpectator,
                    activeColor: AppColors.primary,
                    checkColor: Colors.black,
                    side: BorderSide(color: AppColors.textTertiary),
                    onChanged: (val) =>
                        setState(() => _isSpectator = val ?? false),
                  ),
                  Text(
                    'Join as Spectator',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: Responsive.sp(14),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: _isJoining ? 'Joining...' : 'Join Room',
                  icon: Icons.login,
                  onPressed: _isJoining ? null : _handleJoinRoom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool isUppercase = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusS),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        textCapitalization: isUppercase
            ? TextCapitalization.characters
            : TextCapitalization.none,
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
}
