import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import 'home_match_card.dart';

class HomePrivateRoomSection extends StatelessWidget {
  final AppColorPalette palette;

  const HomePrivateRoomSection({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: HomeMatchCard(
                title: 'CREATE\nROOM',
                icon: Icons.add_circle_outline,
                onTap: () =>
                    context.read<HomeBloc>().add(HomeCreateRoomClicked()),
                palette: palette,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HomeMatchCard(
                title: 'JOIN\nROOM',
                icon: Icons.login,
                onTap: () =>
                    context.read<HomeBloc>().add(HomeJoinRoomClicked()),
                palette: palette,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HomeMatchCard(
                title: 'CREATE\nHOTSPOT',
                icon: Icons.wifi_tethering,
                onTap: () =>
                    context.read<HomeBloc>().add(HomeCreateHotspotClicked()),
                palette: palette,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HomeMatchCard(
                title: 'JOIN\nHOTSPOT',
                icon: Icons.wifi_find_outlined,
                onTap: () =>
                    context.read<HomeBloc>().add(HomeJoinHotspotClicked()),
                palette: palette,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
