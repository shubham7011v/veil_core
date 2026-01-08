import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_notification_event.dart';
import 'app_notification_state.dart';

class AppNotificationBloc
    extends Bloc<AppNotificationEvent, AppNotificationState> {
  AppNotificationBloc() : super(const NotificationIdle()) {
    on<ShowNotification>(_onShowNotification);
    on<DismissNotification>(_onDismissNotification);
  }

  void _onShowNotification(
    ShowNotification event,
    Emitter<AppNotificationState> emit,
  ) {
    emit(
      NotificationShowing(
        message: event.message,
        severity: event.severity,
        duration: event.duration ?? const Duration(seconds: 4),
        actionLabel: event.actionLabel,
        onAction: event.onAction,
      ),
    );
  }

  void _onDismissNotification(
    DismissNotification event,
    Emitter<AppNotificationState> emit,
  ) {
    emit(const NotificationIdle());
  }
}
