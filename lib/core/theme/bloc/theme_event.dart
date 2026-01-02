import 'package:equatable/equatable.dart';
import '../colors.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

class ThemeLoadRequested extends ThemeEvent {}

class ThemeChanged extends ThemeEvent {
  final AppThemeMode mode;

  const ThemeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}
