import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
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
  final _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
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
            const Icon(Icons.security, size: 64, color: Colors.greenAccent),
            const SizedBox(height: 32),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'MASTER KEY',
                labelStyle: TextStyle(color: Colors.greenAccent),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.greenAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                context.read<AdminBloc>().add(AdminLogin(_keyController.text));
              },
              child: const Text('ACCESS MAINFRAME'),
            ),
          ],
        ),
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
            child: ListTile(
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
                onPressed: () {
                  context.read<AdminBloc>().add(CloseRoomEvent(room['id']));
                },
              ),
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
