import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/components/glass_container.dart';
import '../../state/session_provider.dart';

class BotSettingsScreen extends StatefulWidget {
  const BotSettingsScreen({super.key});

  @override
  State<BotSettingsScreen> createState() => _BotSettingsScreenState();
}

class _BotSettingsScreenState extends State<BotSettingsScreen> {
  double _playerCount = 5;
  double _botThinkingTime = 10;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BOT MATCH SETTINGS'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Game Configuration'),
              SizedBox(height: Responsive.h(20)),
              GlassContainer(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    _buildSettingsSlider(
                      label: 'PLAYERS',
                      value: _playerCount,
                      min: 2,
                      max: 10,
                      divisions: 8,
                      onChanged: (val) => setState(() => _playerCount = val),
                    ),
                    const Divider(color: AppColors.divider, height: 32),
                    _buildSettingsSlider(
                      label: 'BOT THINKING TIME',
                      value: _botThinkingTime,
                      suffix: 's',
                      min: 1,
                      max: 30,
                      divisions: 29,
                      onChanged: (val) =>
                          setState(() => _botThinkingTime = val),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Responsive.h(24)),
              _buildSectionHeader('Personalities in this Match'),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    _buildPersonalityItem(
                      'Conservative',
                      'Rahul',
                      'Rarely bluffs. Only plays 1 card at a time. Very cautious.',
                      Icons.shield_outlined,
                      Colors.blue,
                    ),
                    _buildPersonalityItem(
                      'Aggressive',
                      'Priya',
                      'Bluffs often. Plays 3-4 cards frequently. Highly risky.',
                      Icons.local_fire_department_outlined,
                      Colors.red,
                    ),
                    _buildPersonalityItem(
                      'The Ghost',
                      'Soniya',
                      'Loves to pass. Forces pile discards. Strategic and patient.',
                      Icons.visibility_off_outlined,
                      Colors.purple,
                    ),
                    _buildPersonalityItem(
                      'Balanced',
                      'Amit',
                      'Standard play style. Challenges when suspicious.',
                      Icons.balance_outlined,
                      Colors.green,
                    ),
                  ],
                ),
              ),
              SizedBox(height: Responsive.h(20)),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'START BATTLE',
                  icon: Icons.play_arrow,
                  onPressed: () {
                    context.read<SessionProvider>().startSession(
                      playerCount: _playerCount.toInt(),
                      thinkingTimeS: _botThinkingTime.toInt(),
                    );
                    Navigator.pushReplacementNamed(context, '/session');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Widget _buildSettingsSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String suffix = '',
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: AppColors.textSecondary)),
            Text(
              '${value.toInt()}$suffix',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPersonalityItem(
    String type,
    String name,
    String desc,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name ($type)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
