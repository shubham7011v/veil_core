import 'package:equatable/equatable.dart';
import 'app_notification_event.dart';

abstract class AppNotificationState extends Equatable {
  const AppNotificationState();

  @override
  List<Object?> get props => [];
}

class NotificationIdle extends AppNotificationState {
  const NotificationIdle();
}

class NotificationShowing extends AppNotificationState {
  final String message;
  final NotificationSeverity severity;
  final Duration duration;
  final String? actionLabel;
  final void Function()? onAction;

  const NotificationShowing({
    required this.message,
    required this.severity,
    this.duration = const Duration(seconds: 4),
    this.actionLabel,
    this.onAction,
  });

  @override
  List<Object?> get props => [message, severity, duration, actionLabel];
}
