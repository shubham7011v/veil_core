import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/app_notification_bloc.dart';
import '../bloc/app_notification_event.dart';
import '../bloc/app_notification_state.dart';

class AppNotificationListener extends StatelessWidget {
  final Widget child;

  const AppNotificationListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppNotificationBloc, AppNotificationState>(
      listener: (context, state) {
        if (state is NotificationShowing) {
          final snackBar = SnackBar(
            content: Text(state.message),
            duration: state.duration,
            backgroundColor: _getBackgroundColor(state.severity),
            behavior: SnackBarBehavior.floating,
            action: state.actionLabel != null
                ? SnackBarAction(
                    label: state.actionLabel!,
                    textColor: Colors.white,
                    onPressed: () {
                      state.onAction?.call();
                    },
                  )
                : null,
          );

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(snackBar);

          // Auto-dismiss notification state after duration
          Future.delayed(state.duration, () {
            if (context.mounted) {
              context.read<AppNotificationBloc>().add(
                const DismissNotification(),
              );
            }
          });
        }
      },
      child: child,
    );
  }

  Color _getBackgroundColor(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.success:
        return const Color(0xFF4CAF50);
      case NotificationSeverity.error:
      case NotificationSeverity.critical:
        return const Color(0xFFE53935);
      case NotificationSeverity.warning:
        return const Color(0xFFFFA726);
      case NotificationSeverity.info:
        return const Color(0xFF29B6F6);
    }
  }
}
