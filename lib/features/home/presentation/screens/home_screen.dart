import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../core/notifications/widgets/app_notification_listener.dart';
import '../../../../core/di/service_locator.dart';
import '../../../social/social.dart';
import '../../../collection/collection.dart';
import '../../../settings/settings.dart';
import '../widgets/coming_soon_modal.dart';
import '../widgets/rejoin_game_dialog.dart';
import '../widgets/insufficient_coins_dialog.dart';
import '../widgets/home_dashboard.dart';
import '../widgets/home_bottom_nav_bar.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _onHomeSideEffect(
    BuildContext context,
    HomeSideEffect effect,
    AppColorPalette palette,
  ) {
    if (effect is HomeNavigateTo) {
      Navigator.pushNamed(context, effect.route);
    } else if (effect is HomeShowRejoinDialog) {
      RejoinGameDialog.show(
        context: context,
        palette: palette,
        onResume: () => context.read<HomeBloc>().add(HomeRejoinGameConfirmed()),
        onNewGame: () => context.read<HomeBloc>().add(HomeNewGameConfirmed()),
      );
    } else if (effect is HomeShowInsufficientCoinsDialog) {
      InsufficientCoinsDialog.show(context: context, palette: palette);
    } else if (effect is HomeShowComingSoonDialog) {
      showDialog(
        context: context,
        builder: (context) => ComingSoonModal(
          featureName: effect.featureName,
          description: effect.description,
          icon: effect.icon,
          palette: palette,
        ),
      );
    } else if (effect is HomeShowSnackBar) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(effect.message)));
    }
  }

  void _goHome(BuildContext context) {
    context.read<HomeBloc>().add(const HomeBottomNavTapped(0));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc(
        sessionHandler: sl.webSocketSessionHandler,
        systemStatusService: sl.systemStatusService,
        audioService: sl.audioService,
        greetingService: sl.greetingService,
      )..add(HomeStarted()),
      child: AppNotificationListener(
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            final palette = AppColors.getPalette(themeState.mode);

            return BlocListener<HomeBloc, HomeState>(
              listenWhen: (previous, current) => current.effect != null,
              listener: (context, state) {
                if (state.effect != null) {
                  _onHomeSideEffect(context, state.effect!, palette);
                }
              },
              child: BlocBuilder<HomeBloc, HomeState>(
                buildWhen: (previous, current) =>
                    previous.tabIndex != current.tabIndex ||
                    previous.systemStatus != current.systemStatus,
                builder: (context, homeState) {
                  final selectedIndex = homeState.tabIndex;

                  return PopScope(
                    canPop: selectedIndex == 0,
                    onPopInvokedWithResult: (didPop, result) {
                      if (didPop) return;
                      _goHome(context);
                    },
                    child: Scaffold(
                      backgroundColor: palette.background,
                      body: SafeArea(
                        child: IndexedStack(
                          index: selectedIndex,
                          children: [
                            HomeDashboard(
                              palette: palette,
                              homeState: homeState,
                            ),
                            FriendsScreen(onBack: () => _goHome(context)),
                            LeaderboardScreen(onBack: () => _goHome(context)),
                            DeckCollectionScreen(
                              onBack: () => _goHome(context),
                            ),
                            SettingsScreen(onBack: () => _goHome(context)),
                          ],
                        ),
                      ),
                      bottomNavigationBar: HomeBottomNavBar(
                        selectedIndex: selectedIndex,
                        palette: palette,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
