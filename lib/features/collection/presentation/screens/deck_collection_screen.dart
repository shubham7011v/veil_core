import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/theme/bloc/theme_state.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../shared/components/primary_button.dart';

class DeckCollectionScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const DeckCollectionScreen({super.key, this.onBack});

  @override
  State<DeckCollectionScreen> createState() => _DeckCollectionScreenState();
}

class _DeckCollectionScreenState extends State<DeckCollectionScreen> {
  int _selectedTabIndex = 0; // 0: Face Cards, 1: Number, 2: Backs

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        final palette = AppColors.getPalette(themeState.mode);

        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            title: Text(
              'Royal Deck Collection',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: palette.textPrimary,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: palette.textSecondary),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.help_outline, color: palette.textSecondary),
                onPressed: () {},
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Header / Reward Info
                Padding(
                  padding: const EdgeInsets.all(AppDimens.paddingM),
                  child: Column(
                    children: [
                      Text(
                        'SEASON 4 REWARDS',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unified Bluff Series',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Semi-realistic Indian royalty theme with premium finishes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppDimens.paddingM,
                  ),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppDimens.radiusM),
                    border: Border.all(color: palette.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildTab('Face Cards', 0, palette)),
                      Expanded(child: _buildTab('Number', 1, palette)),
                      Expanded(child: _buildTab('Backs', 2, palette)),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimens.paddingL),

                // Grid
                Expanded(
                  child: _selectedTabIndex == 2
                      ? _buildBacksGrid(palette)
                      : _buildFacesGrid(palette),
                ),

                const SizedBox(height: AppDimens.paddingM),

                // Bottom Action
                Padding(
                  padding: const EdgeInsets.all(AppDimens.paddingM),
                  child: SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Equip This Deck',
                      icon: Icons.style,
                      type: ButtonType.danger, // Using red button as per mock
                      onPressed: () {
                        // Equip logic
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab(String label, int index, AppColorPalette palette) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.danger
              : Colors.transparent, // Red for active tab
          borderRadius: BorderRadius.circular(AppDimens.radiusS),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : palette.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFacesGrid(AppColorPalette palette) {
    // Mock 4 card showcase
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingM),
      mainAxisSpacing: AppDimens.paddingM,
      crossAxisSpacing: AppDimens.paddingM,
      childAspectRatio: 0.7,
      children: [
        _buildCardPreview('K', 'hearts', true, palette), // King of Hearts
        _buildCardPreview('A', 'spades', false, palette), // Ace of Spades
        _buildCardPreview('Q', 'diamonds', true, palette), // Queen of Diamonds
        _buildCardPreview('10', 'clubs', false, palette), // 10 of Clubs
      ],
    );
  }

  Widget _buildBacksGrid(AppColorPalette palette) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingM),
      children: [
        Center(
          child: Text(
            'AVAILABLE BACKS',
            style: TextStyle(
              color: palette.primary,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: _buildBackCard(
                  'Royal Mandala',
                  'Standard',
                  false,
                  palette,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBackCard(
                  'Midnight Velvet',
                  'Premium',
                  true,
                  palette,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardPreview(
    String rank,
    String suit,
    bool isRed,
    AppColorPalette palette,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6CC), // Vintage paper color - Keep constant
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 8,
            child: Text(
              rank,
              style: TextStyle(
                color: isRed ? palette.danger : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          Positioned(
            top: 36,
            left: 8,
            child: Icon(
              // Icons are placeholders for suits
              isRed ? Icons.favorite : Icons.eco,
              color: isRed ? palette.danger : Colors.black,
              size: 16,
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Transform.rotate(
              angle: 3.14,
              child: Text(
                rank,
                style: TextStyle(
                  color: isRed ? palette.danger : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              rank == 'K'
                  ? Icons.workspace_premium
                  : rank == 'Q'
                  ? Icons.auto_awesome
                  : rank == 'A'
                  ? Icons.star
                  : Icons.style,
              size: 48,
              color: (isRed ? palette.danger : Colors.black).withValues(
                alpha: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(
    String name,
    String tier,
    bool isEquipped,
    AppColorPalette palette,
  ) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isEquipped
                  ? palette.surfaceLight
                  : palette.cardBack, // Use palette
              borderRadius: BorderRadius.circular(AppDimens.radiusM),
              border: isEquipped
                  ? Border.all(color: palette.primary, width: 2)
                  : null,
            ),
            child: isEquipped
                ? Stack(
                    children: [
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.danger,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'EQUIPPED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      Icons.local_fire_department,
                      color: palette.primaryDim,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          tier,
          style: TextStyle(color: palette.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}
