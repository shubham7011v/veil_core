import 'package:flutter/material.dart';
import '../engine/domain/models/session_enums.dart';

class ConnectionStatusIndicator extends StatelessWidget {
  final Stream<ConnectionStatus> statusStream;

  const ConnectionStatusIndicator({super.key, required this.statusStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionStatus>(
      stream: statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectionStatus.disconnected;

        if (status == ConnectionStatus.connected) {
          return const SizedBox.shrink(); // Hide when connected
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _getStatusColor(status),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == ConnectionStatus.reconnecting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                _getStatusMessage(status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connecting:
        return Colors.blue;
      case ConnectionStatus.reconnecting:
        return Colors.orange;
      case ConnectionStatus.failed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusMessage(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting...';
      case ConnectionStatus.failed:
        return 'Connection failed';
      default:
        return 'Disconnected';
    }
  }
}
