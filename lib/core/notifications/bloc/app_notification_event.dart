import 'package:equatable/equatable.dart';

enum NotificationSeverity { info, success, warning, error, critical }

abstract class AppNotificationEvent extends Equatable {
  const AppNotificationEvent();

  @override
  List<Object?> get props => [];
}

class ShowNotification extends AppNotificationEvent {
  final String message;
  final NotificationSeverity severity;
  final Duration? duration;
  final String? actionLabel;
  final void Function()? onAction;

  const ShowNotification({
    required this.message,
    this.severity = NotificationSeverity.info,
    this.duration,
    this.actionLabel,
    this.onAction,
  });

  @override
  List<Object?> get props => [message, severity, duration, actionLabel];
}

class ShowErrorNotification extends ShowNotification {
  const ShowErrorNotification(
    String message, {
    super.duration,
    super.actionLabel,
    super.onAction,
  }) : super(message: message, severity: NotificationSeverity.error);
}

class ShowSuccessNotification extends ShowNotification {
  const ShowSuccessNotification(String message, {super.duration})
    : super(message: message, severity: NotificationSeverity.success);
}

class ShowInfoNotification extends ShowNotification {
  const ShowInfoNotification(String message, {super.duration})
    : super(message: message, severity: NotificationSeverity.info);
}

class ShowWarningNotification extends ShowNotification {
  const ShowWarningNotification(String message, {super.duration})
    : super(message: message, severity: NotificationSeverity.warning);
}

class DismissNotification extends AppNotificationEvent {
  const DismissNotification();
}
