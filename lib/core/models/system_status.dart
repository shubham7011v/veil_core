import 'package:flutter/material.dart';

enum SystemStatusType {
  healthy,
  noInternet,
  serverDown,
  authIssue,
  syncing,
  failed,
}

class SystemStatus {
  final SystemStatusType type;
  final String label;
  final String description;
  final String actionLabel;
  final IconData icon;
  final Color statusColor;

  const SystemStatus({
    required this.type,
    required this.label,
    required this.description,
    required this.actionLabel,
    required this.icon,
    required this.statusColor,
  });

  factory SystemStatus.healthy() => const SystemStatus(
    type: SystemStatusType.healthy,
    label: 'System Healthy',
    description: 'Multiplayer engine and cloud services are active.',
    actionLabel: 'REFRESH ALL',
    icon: Icons.check_circle_rounded,
    statusColor: Color(0xFF4CAF50),
  );

  factory SystemStatus.noInternet() => const SystemStatus(
    type: SystemStatusType.noInternet,
    label: 'No Internet',
    description: 'Your device is not connected to the internet.',
    actionLabel: 'CHECK CONNECTION',
    icon: Icons.wifi_off_rounded,
    statusColor: Color(0xFFF43F5E),
  );

  factory SystemStatus.serverDown() => const SystemStatus(
    type: SystemStatusType.serverDown,
    label: 'Server Offline',
    description: 'The game server is currently unreachable.',
    actionLabel: 'RETRY CONNECTION',
    icon: Icons.dns_rounded,
    statusColor: Color(0xFFF43F5E),
  );

  factory SystemStatus.authIssue() => const SystemStatus(
    type: SystemStatusType.authIssue,
    label: 'Auth Required',
    description: 'Unable to verify your session identity.',
    actionLabel: 'RE-AUTHENTICATE',
    icon: Icons.lock_person_rounded,
    statusColor: Color(0xFFFF9800),
  );

  factory SystemStatus.syncing() => const SystemStatus(
    type: SystemStatusType.syncing,
    label: 'Syncing...',
    description: 'Linking with global services...',
    actionLabel: 'PLEASE WAIT',
    icon: Icons.sync_rounded,
    statusColor: Colors.blueAccent,
  );

  factory SystemStatus.failed() => const SystemStatus(
    type: SystemStatusType.failed,
    label: 'System Error',
    description: 'An unexpected connection failure occurred.',
    actionLabel: 'RETRY ALL',
    icon: Icons.error_rounded,
    statusColor: Color(0xFFF43F5E),
  );
}
