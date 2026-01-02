import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:veil_core/core/theme/bloc/theme_bloc.dart';
import 'package:veil_core/core/theme/bloc/theme_event.dart';
import 'package:veil_core/core/theme/bloc/theme_state.dart';
import 'package:veil_core/core/theme/colors.dart';
import 'package:veil_core/core/theme/theme_service.dart';

class MockThemeService extends Mock implements ThemeService {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppThemeMode.classic);
  });

  late MockThemeService mockThemeService;

  setUp(() {
    mockThemeService = MockThemeService();
    // Default mock behavior for the constructor's initial add(ThemeLoadRequested())
    when(
      () => mockThemeService.loadTheme(),
    ).thenAnswer((_) async => AppThemeMode.classic);
  });

  group('ThemeBloc', () {
    test('initial state is correct', () {
      final themeBloc = ThemeBloc(themeService: mockThemeService);
      expect(themeBloc.state, ThemeState.initial());
      themeBloc.close();
    });

    blocTest<ThemeBloc, ThemeState>(
      'emits [isLoaded: true] when ThemeLoadRequested is successful',
      build: () {
        when(
          () => mockThemeService.loadTheme(),
        ).thenAnswer((_) async => AppThemeMode.midnight);
        return ThemeBloc(themeService: mockThemeService);
      },
      // ThemeBloc adds ThemeLoadRequested in constructor, so we skip the first state if we want to test specifically
      expect: () => [ThemeState(mode: AppThemeMode.midnight, isLoaded: true)],
      verify: (_) {
        verify(() => mockThemeService.loadTheme()).called(1);
      },
    );

    blocTest<ThemeBloc, ThemeState>(
      'emits new mode when ThemeChanged is added',
      build: () {
        when(
          () => mockThemeService.loadTheme(),
        ).thenAnswer((_) async => AppThemeMode.classic);
        when(() => mockThemeService.saveTheme(any())).thenAnswer((_) async {});
        return ThemeBloc(themeService: mockThemeService);
      },
      seed: () => ThemeState(mode: AppThemeMode.classic, isLoaded: true),
      act: (bloc) => bloc.add(ThemeChanged(AppThemeMode.midnight)),
      expect: () => [ThemeState(mode: AppThemeMode.midnight, isLoaded: true)],
      verify: (_) {
        verify(
          () => mockThemeService.saveTheme(AppThemeMode.midnight),
        ).called(1);
      },
    );

    blocTest<ThemeBloc, ThemeState>(
      'does not emit when ThemeChanged is added with same mode',
      build: () {
        when(
          () => mockThemeService.loadTheme(),
        ).thenAnswer((_) async => AppThemeMode.classic);
        return ThemeBloc(themeService: mockThemeService);
      },
      seed: () => ThemeState(mode: AppThemeMode.classic, isLoaded: true),
      act: (bloc) => bloc.add(ThemeChanged(AppThemeMode.classic)),
      expect: () => [],
    );
  });
}
