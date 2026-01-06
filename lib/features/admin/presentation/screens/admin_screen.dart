import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../core/services/admin_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic>? _rooms;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await AdminService.instance.getServerStats();
      final rooms = await AdminService.instance.listRooms();
      setState(() {
        _stats = stats;
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _closeRoom(String roomId) async {
    try {
      await AdminService.instance.closeRoom(roomId);
      _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to close room: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        final palette = AppColors.getPalette(themeState.mode);

        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            title: const Text('ADMIN DASHBOARD'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshData,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(AppDimens.paddingM),
                  children: [
                    _buildStatsCard(palette),
                    const SizedBox(height: AppDimens.paddingL),
                    const Text(
                      'ACTIVE ROOMS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    if (_rooms == null || _rooms!.isEmpty)
                      const Center(child: Text('No active rooms'))
                    else
                      ..._rooms!.map((room) => _buildRoomTile(room, palette)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStatsCard(AppColorPalette palette) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.paddingL),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Rooms',
            _stats?['total_rooms']?.toString() ?? '0',
            palette,
          ),
          _buildStatItem(
            'Players',
            _stats?['total_players']?.toString() ?? '0',
            palette,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, AppColorPalette palette) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: palette.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: palette.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room, AppColorPalette palette) {
    final id = room['id'] as String;
    final playerCount = room['player_count'] as int;
    final isPrivate = room['is_private'] as bool;
    final gameStarted = room['game_started'] as bool;

    return Card(
      color: palette.surface,
      margin: const EdgeInsets.only(bottom: AppDimens.paddingM),
      child: ListTile(
        title: Text('Room ID: ${id.substring(0, 8)}...'),
        subtitle: Text(
          'Players: $playerCount | Private: $isPrivate | Active: $gameStarted',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => _confirmCloseRoom(id),
        ),
      ),
    );
  }

  void _confirmCloseRoom(String roomId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Room?'),
        content: Text(
          'This will forcefully disconnect all players in room $roomId.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _closeRoom(roomId);
            },
            child: const Text(
              'Close Room',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
