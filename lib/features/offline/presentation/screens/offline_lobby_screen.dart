import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../offline.dart';

enum _LobbyPhase { modeSelection, hosting, joining }

class OfflineLobbyScreen extends StatefulWidget {
  const OfflineLobbyScreen({super.key});

  @override
  State<OfflineLobbyScreen> createState() => _OfflineLobbyScreenState();
}

class _OfflineLobbyScreenState extends State<OfflineLobbyScreen> {
  _LobbyPhase _phase = _LobbyPhase.modeSelection;
  StreamSubscription? _gameStateSub;
  String? _statusMessage;

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  void _cleanup() {
    sl.discoveryService.stop();
    sl.localServerService.stop();
    _gameStateSub?.cancel();
  }

  Future<void> _startHosting() async {
    setState(() {
      _phase = _LobbyPhase.hosting;
      _statusMessage = 'Initializing local station...';
    });

    try {
      final user = (context.read<AuthBloc>().state as Authenticated).user;

      // 1. Start Server
      await sl.localServerService.start();

      // 2. Start Discovery
      await sl.discoveryService.startBroadcasting(user.displayName ?? 'Host');

      // 3. Connect as Host Client
      await sl.webSocketSessionHandler.connect(
        'ws://127.0.0.1:8080',
        user.uid,
        displayName: user.displayName,
      );

      // 4. Listen for game start to navigate
      _gameStateSub = sl.localGameEngine.stateStream.listen((state) {
        if (!mounted) return;
        if (state.phase == OfflinePhase.thinking) {
          Navigator.pushReplacementNamed(
            context,
            AppRouter.session,
            arguments: {'useWebSocket': true},
          );
        }
      });

      setState(() => _statusMessage = 'Station active. Waiting for crew...');
    } catch (e) {
      setState(
        () => _statusMessage = 'Hull breach! Failed to start server: $e',
      );
    }
  }

  void _startJoining() {
    setState(() {
      _phase = _LobbyPhase.joining;
      _statusMessage = 'Scanning local frequencies...';
    });
    sl.discoveryService.startListening();
  }

  Future<void> _connectToHost(String name, String ip, int port) async {
    setState(() => _statusMessage = 'Approaching station $name...');
    try {
      final user = (context.read<AuthBloc>().state as Authenticated).user;

      await sl.webSocketSessionHandler.connect(
        'ws://$ip:$port',
        user.uid,
        displayName: user.displayName,
      );

      // Listen for game start
      // Note: In Join mode, the state comes from the Host server via WebSocket handler
      // The session screen will handle actual game navigation once connected
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRouter.session,
        arguments: {'useWebSocket': true},
      );
    } catch (e) {
      setState(() => _statusMessage = 'Connection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.background,
                  AppColors.primaryDim.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(child: _buildMainContent()),
                if (_statusMessage != null) _buildStatusBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Text(
            'OFFLINE MATCH',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          Text(
            'HOSPORT / LAN MODE',
            style: GoogleFonts.outfit(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_phase) {
      case _LobbyPhase.modeSelection:
        return _buildModeSelection();
      case _LobbyPhase.hosting:
        return _buildHostingLobby();
      case _LobbyPhase.joining:
        return _buildJoiningList();
    }
  }

  Widget _buildModeSelection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSelectionCard(
              title: 'HOST STATION',
              desc: 'Start a local match and let others join your hotspot.',
              icon: Icons.wifi_tethering,
              color: AppColors.primary,
              onTap: _startHosting,
            ),
            const SizedBox(height: 24),
            _buildSelectionCard(
              title: 'JOIN MISSION',
              desc: 'Scan for active hosts in your local network.',
              icon: Icons.radar,
              color: AppColors.primaryDim,
              onTap: _startJoining,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHostingLobby() {
    return StreamBuilder<OfflineGameState>(
      stream: sl.localGameEngine.stateStream,
      builder: (context, snapshot) {
        final players = snapshot.data?.participants ?? [];
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final p = players[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          child: Text(
                            p.name[0],
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          p.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (index == 0)
                          const Text(
                            'HOST',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: ElevatedButton(
                onPressed: players.length >= 2
                    ? () => sl.localGameEngine.start()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'LAUNCH MISSION',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildJoiningList() {
    return StreamBuilder<Set<String>>(
      stream: sl.discoveryService.discoveredHosts,
      builder: (context, snapshot) {
        final hosts = snapshot.data?.toList() ?? [];
        if (hosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Scanning local space...',
                  style: TextStyle(color: Colors.white60),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: hosts.length,
          itemBuilder: (context, index) {
            final parts = hosts[index].split('|');
            final name = parts[0];
            final ip = parts[1];
            final port = int.parse(parts[2]);

            return _buildSelectionCard(
              title: name,
              desc: 'IP: $ip',
              icon: Icons.person,
              color: AppColors.primaryDim,
              onTap: () => _connectToHost(name, ip, port),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Text(
        _statusMessage!,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
