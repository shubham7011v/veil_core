import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../shared/components/primary_button.dart';
// import '../../../../shared/components/glass_container.dart';

class DeckCollectionScreen extends StatefulWidget {
  const DeckCollectionScreen({super.key});

  @override
  State<DeckCollectionScreen> createState() => _DeckCollectionScreenState();
}

class _DeckCollectionScreenState extends State<DeckCollectionScreen> {
  int _selectedTabIndex = 0; // 0: Face Cards, 1: Number, 2: Backs
  // final String _equippedDeckId = 'deck_02'; // Default equipped

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Royal Deck Collection',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
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
                  const Text(
                    'SEASON 4 REWARDS',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Unified Bluff Series',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Semi-realistic Indian royalty theme with premium finishes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusM),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTab('Face Cards', 0)),
                  Expanded(child: _buildTab('Number', 1)),
                  Expanded(child: _buildTab('Backs', 2)),
                ],
              ),
            ),

            const SizedBox(height: AppDimens.paddingL),

            // Grid
            Expanded(
              child: _selectedTabIndex == 2
                  ? _buildBacksGrid()
                  : _buildFacesGrid(),
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
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.danger
              : Colors.transparent, // Red for active tab
          borderRadius: BorderRadius.circular(AppDimens.radiusS),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFacesGrid() {
    // Mock 4 card showcase
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingM),
      mainAxisSpacing: AppDimens.paddingM,
      crossAxisSpacing: AppDimens.paddingM,
      childAspectRatio: 0.7,
      children: [
        _buildCardPreview(
          'K',
          'hearts',
          'assets/king.png',
          true,
        ), // King of Hearts
        _buildCardPreview(
          'A',
          'spades',
          'assets/ace.png',
          false,
        ), // Ace of Spades
        _buildCardPreview(
          'Q',
          'diamonds',
          'assets/queen.png',
          true,
        ), // Queen of Diamonds
        _buildCardPreview(
          '10',
          'clubs',
          'assets/ten.png',
          false,
        ), // 10 of Clubs
      ],
    );
  }

  Widget _buildBacksGrid() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingM),
      // childAspectRatio: 1.5, // Not used in ListView unless grid, but ok
      children: [
        const Center(
          child: Text(
            'AVAILABLE BACKS',
            style: TextStyle(
              color: AppColors.primary,
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
                child: _buildBackCard('Royal Mandala', 'Standard', false),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBackCard('Midnight Velvet', 'Premium', true),
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
    String assetPath,
    bool isRed,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6CC), // Vintage paper color
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
                color: isRed ? AppColors.danger : Colors.black,
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
              color: isRed ? AppColors.danger : Colors.black,
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
                  color: isRed ? AppColors.danger : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.style,
              size: 48,
              color: Colors.black.withValues(alpha: 0.1),
            ), // Placeholder for art
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(String name, String tier, bool isEquipped) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isEquipped
                  ? const Color(0xFF1E2A38)
                  : const Color(0xFF3E1E1E), // Blue/Red abstract
              borderRadius: BorderRadius.circular(AppDimens.radiusM),
              border: isEquipped
                  ? Border.all(color: AppColors.primary, width: 2)
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
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.only(
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
                : const Center(
                    child: Icon(
                      Icons.local_fire_department,
                      color: AppColors.primaryDim,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          tier,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}
