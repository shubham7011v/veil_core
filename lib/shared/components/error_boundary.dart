import 'package:flutter/material.dart';
import 'package:veil_core/shared/components/app_error_widget.dart';

/// A widget that catches Flutter errors in its child sub-tree
/// and displays a fallback error UI instead of crashing the whole app.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final VoidCallback? onRetry;

  const ErrorBoundary({super.key, required this.child, this.onRetry});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return Scaffold(
        body: AppErrorWidget(
          message:
              'A UI error occurred in this section: ${_errorDetails!.exception}',
          onRetry: () {
            setState(() {
              _errorDetails = null;
            });
            widget.onRetry?.call();
          },
        ),
      );
    }

    return ErrorWidget.builder == _errorBuilder
        ? widget.child
        : ErrorBuilder(builder: _errorBuilder, child: widget.child);
  }

  Widget _errorBuilder(FlutterErrorDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _errorDetails = details;
        });
      }
    });
    return const SizedBox.shrink();
  }
}

/// Helper widget to override ErrorWidget.builder locally
class ErrorBuilder extends StatefulWidget {
  final ErrorWidgetBuilder builder;
  final Widget child;

  const ErrorBuilder({super.key, required this.builder, required this.child});

  @override
  State<ErrorBuilder> createState() => _ErrorBuilderState();
}

class _ErrorBuilderState extends State<ErrorBuilder> {
  late ErrorWidgetBuilder _oldBuilder;

  @override
  void initState() {
    super.initState();
    _oldBuilder = ErrorWidget.builder;
    ErrorWidget.builder = widget.builder;
  }

  @override
  void dispose() {
    ErrorWidget.builder = _oldBuilder;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
