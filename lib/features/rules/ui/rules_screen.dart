import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../shared/components/primary_button.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'BLUFF (Indian Style) v1',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingM,
                vertical: 8,
              ),
              child: Text(
                'Master the art of deception to claim your throne.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimens.paddingM),
                child: Column(
                  children: [
                    _buildRuleItem(
                      'Game Setup',
                      Icons.settings_suggest,
                      '• Players: 2 to 10\n• Deck: Standard 52 cards\n• Suits: ❌ Ignored (Only Rank matters)\n• Distributed: Equally\n• Winner: First to reach 0 cards',
                      isExpanded: true,
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    _buildRuleItem(
                      'Game Start',
                      Icons.play_circle_outline,
                      '• First player: Winner of previous game.\n• At start: ❌ No rank selected.\n• First player plays 1–4 cards and declares a rank.',
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    _buildRuleItem(
                      'Turn Rules',
                      Icons.swap_horiz,
                      'On your turn, you can:\n• Play 1–4 cards face-down and declare a rank.\n• Pass (keeps bluff opportunity alive for others).',
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    _buildRuleItem(
                      'Pass-Cycle End (Key Rule)',
                      Icons.loop,
                      'If ALL players pass and the turn returns to the one who last played:\n• 🗑️ Entire pile is DISCARDED.\n• 🔄 Round ends.\n• 🎴 Same player starts next round with a new rank.',
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    _buildRuleItem(
                      'Bluff Rules',
                      Icons.gavel,
                      '• Only the next player in order can call Bluff.\n• Applies only to the LAST played cards.\n• Correct Bluff (Lie): Liar picks up pile.\n• Wrong Bluff (Truth): Caller picks up pile.',
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    _buildRuleItem(
                      'After Bluff Resolution',
                      Icons.restart_alt,
                      '• 🔄 Rank resets.\n• 🆕 New round starts.\n• ▶️ Turn goes to the WINNER of the challenge.',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.paddingM),
              child: SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'RETURN TO TABLE',
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(
    String title,
    IconData icon,
    String content, {
    bool isExpanded = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Theme(
        data: ThemeData.dark().copyWith(
          dividerColor: Colors.transparent,
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          leading: Icon(icon, color: AppColors.primary, size: 20),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusM),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppDimens.paddingM,
            0,
            AppDimens.paddingM,
            AppDimens.paddingM,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                content,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
