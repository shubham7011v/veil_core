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
          'ROYAL PROTOCOL',
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
                      'The Objective',
                      Icons.flag,
                      'Your goal is simple yet treacherous: be the first player to discard all your cards. Place them face down into the center pile and declare their rank. But beware—honesty is merely a suggestion in the royal court.',
                      isExpanded: true,
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    _buildRuleItem(
                      'The Deal',
                      Icons.style,
                      'All cards are distributed evenly among participants. Ace is highest rank. A standard 52-card deck is used.',
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    _buildRuleItem(
                      'Card Rankings',
                      Icons.military_tech,
                      'A > K > Q > J > 10... > 2. Aces are traditionally high.',
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    _buildRuleItem(
                      'How to Bluff',
                      Icons.visibility_off,
                      'You may declare any rank, regardless of the actual cards you play. However, you must play as many cards as you declared.',
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    _buildRuleItem(
                      'Calling a Bluff',
                      Icons.gavel,
                      'If you suspect deception, you may "Challenge" the previous play when it becomes your turn. Only the immediate next player in rotation has the right to challenge. If they lied, they pick up the pile. If they told the truth, you pick up the pile.',
                    ),
                    const SizedBox(height: AppDimens.paddingM),
                    _buildRuleItem(
                      'Victory',
                      Icons.emoji_events,
                      'The first to have 0 cards wins. Points are awarded based on finishing order.',
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
            Text(
              content,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
