import 'package:equatable/equatable.dart';
import '../colors.dart';

class ThemeState extends Equatable {
  final AppThemeMode mode;
  final bool isLoaded;

  const ThemeState({required this.mode, required this.isLoaded});

  factory ThemeState.initial() =>
      const ThemeState(mode: AppThemeMode.classic, isLoaded: false);

  ThemeState copyWith({AppThemeMode? mode, bool? isLoaded}) {
    return ThemeState(
      mode: mode ?? this.mode,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  List<Object?> get props => [mode, isLoaded];
}
