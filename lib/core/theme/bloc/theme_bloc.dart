import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme_service.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final ThemeService _themeService;

  ThemeBloc({ThemeService? themeService})
    : _themeService = themeService ?? ThemeService(),
      super(ThemeState.initial()) {
    on<ThemeLoadRequested>(_onLoadRequested);
    on<ThemeChanged>(_onChanged);

    add(ThemeLoadRequested());
  }

  Future<void> _onLoadRequested(
    ThemeLoadRequested event,
    Emitter<ThemeState> emit,
  ) async {
    final mode = await _themeService.loadTheme();
    emit(state.copyWith(mode: mode, isLoaded: true));
  }

  Future<void> _onChanged(ThemeChanged event, Emitter<ThemeState> emit) async {
    if (state.mode == event.mode) return;
    await _themeService.saveTheme(event.mode);
    emit(state.copyWith(mode: event.mode));
  }
}
