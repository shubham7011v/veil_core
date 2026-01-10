import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/config/app_config.dart';
import '../bloc/admin_bloc.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AdminBloc(sl.adminRepository), // sl() must resolve AdminRepository
      child: const _AdminView(),
    );
  }
}

class _AdminView extends StatefulWidget {
  const _AdminView();

  @override
  State<_AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<_AdminView> {
  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  void _checkAuthorization() {
    final user = FirebaseAuth.instance.currentUser;
    final config = AppConfig.instance;

    if (user != null && config.adminUids.contains(user.uid)) {
      // Automatically attempt login with the secret key from GitHub Secrets/Dart Defines
      context.read<AdminBloc>().add(AdminLogin());
    } else {
      // Not an admin in the injected list
      context.read<AdminBloc>().add(AdminLogout()); // Ensure reset
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Matrix style
      appBar: AppBar(
        title: const Text('SERVER ADMIN'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.greenAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign, color: Colors.orangeAccent),
            tooltip: 'Broadcast Message',
            onPressed: () => _showBroadcastDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AdminBloc>().add(LoadAdminData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AdminBloc>().add(AdminLogout());
            },
          ),
        ],
      ),
      body: BlocBuilder<AdminBloc, AdminState>(
        builder: (context, state) {
          if (state is AdminInitial || state is AdminError) {
            if (state is AdminError) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.message)));
              });
            }
            return _buildLogin(context);
          }

          if (state is AdminLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            );
          }

          if (state is AdminAuthenticated) {
            return _buildDashboard(context, state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 64, color: Colors.redAccent),
            const SizedBox(height: 32),
            const Text(
              'UNAUTHORIZED ACCESS',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'User UID: ${FirebaseAuth.instance.currentUser?.uid ?? "Unknown"}',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
            const SizedBox(height: 32),
            Text(
              'This terminal is restricted to ${AppConfig.instance.isProduction ? "production" : "development"} administrators. Your UID must be registered in the mainframe via GitHub Secrets.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 48),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'RETREAT',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'BROADCAST ALERT',
          style: TextStyle(color: Colors.orangeAccent),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter message to all users...',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.greenAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<AdminBloc>().add(
                  BroadcastMessageEvent(controller.text),
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Broadcasting signal...')),
                );
              }
            },
            child: const Text('TRANSMIT'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, AdminAuthenticated state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats
        _buildStatCard("UPTIME", "${state.stats['uptime_sec']}s"),
        _buildStatCard("GOROUTINES", "${state.stats['goroutines']}"),

        const Divider(color: Colors.greenAccent, height: 40),

        const Text(
          "ACTIVE ROOMS",
          style: TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        if (state.rooms.isEmpty)
          const Text("No active rooms", style: TextStyle(color: Colors.grey)),

        ...state.rooms.map(
          (room) => Card(
            color: Colors.grey[900],
            child: ExpansionTile(
              iconColor: Colors.greenAccent,
              collapsedIconColor: Colors.grey,
              title: Text(
                "Room: ${room['id']}",
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                "Players: ${room['playerCount']} | Phase: ${room['phase']}",
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Close Room',
                onPressed: () {
                  context.read<AdminBloc>().add(CloseRoomEvent(room['id']));
                },
              ),
              children: [
                if (room['playerIds'] != null)
                  ...(room['playerIds'] as List).map(
                    (pid) => ListTile(
                      dense: true,
                      title: Text(
                        pid.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          context.read<AdminBloc>().add(
                            BanUserEvent(pid.toString()),
                          );
                        },
                        child: const Text(
                          'BAN',
                          style: TextStyle(color: Colors.red, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.greenAccent)),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
