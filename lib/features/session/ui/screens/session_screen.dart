
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/dimens.dart';
import '../../../../core/constants/strings.dart';
import '../../../../core/animations/anim_utils.dart';
import '../../../../core/utils/responsive.dart'; // Import Responsive
import '../../../../shared/components/primary_button.dart';
import '../../../../shared/components/glass_container.dart';
import '../../models/session_state.dart';
import '../../models/unit.dart';
import '../../state/session_provider.dart';
import '../../widgets/unit_card.dart';
import '../../widgets/participant_avatar.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> with TickerProviderStateMixin {
  late AnimationController _entryController;
  final GlobalKey _pileKey = GlobalKey();
  
  // Flight Animation State
  List<Unit> _flyingUnits = [];
  Offset _pilePosition = Offset.zero;
  late AnimationController _flightController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: AnimUtils.visual
    )..forward();
    
    _flightController = AnimationController(
      vsync: this, duration: AnimUtils.medium,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
         final provider = context.read<SessionProvider>();
         provider.submitSelectedUnits();
         setState(() {
            _flyingUnits.clear();
         });
         _flightController.reset();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize Responsive Utils
    Responsive.init(context);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _flightController.dispose();
    super.dispose();
  }

  void _triggerSubmitAnimation(SessionProvider provider) {
     if (provider.selectedUnitIds.isEmpty) return;
     
     final RenderBox? pileBox = _pileKey.currentContext?.findRenderObject() as RenderBox?;
     if (pileBox != null) {
        final position = pileBox.localToGlobal(Offset.zero);
        _pilePosition = position + Offset(pileBox.size.width / 2, pileBox.size.height / 2);
     } else {
        _pilePosition = Offset(Responsive.screenWidth / 2, Responsive.screenHeight * 0.35); 
     }

     final flying = provider.state.myHand.where((u) => provider.selectedUnitIds.contains(u.id)).toList();
     setState(() {
        _flyingUnits = flying;
     });
     _flightController.forward();
  }

  Widget build(BuildContext context) {
    // Re-init on build to be safe with rotations/resizes
    Responsive.init(context);
    
    final provider = context.watch<SessionProvider>();
    final state = provider.state;
    
    // Scale container height based on screen
    final double bottomContainerHeight = Responsive.h(350); 
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Top Area: Room Info & Participants
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimUtils.slideUpFade(
                animation: _entryController,
                child: Padding(
                  padding: EdgeInsets.all(Responsive.w(AppDimens.paddingM)),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(8.0)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${AppStrings.roomPrefix}${state.roomId}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.textSecondary,
                                letterSpacing: 2,
                                fontSize: Responsive.sp(14),
                              ),
                            ),
                            IconButton(
                               icon: Icon(Icons.settings, color: AppColors.textSecondary, size: Responsive.w(24)),
                               onPressed: () {},
                            )
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.h(AppDimens.paddingM)),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: state.participants.map((p) {
                             if (p.isMe) return const SizedBox.shrink(); 
                             return Padding(
                               padding: EdgeInsets.symmetric(horizontal: Responsive.w(AppDimens.paddingS)),
                               child: ParticipantAvatar(
                                 participant: p,
                                 size: Responsive.w(AppDimens.avatarSize), // Scale avatar
                               ),
                             );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Center Area: The Pile
            // Dynamically position pile relative to screen height
            Positioned(
              top: Responsive.screenHeight * 0.30, 
              left: 0,
              right: 0,
              child: Center(
                child: AnimUtils.slideUpFade(
                  animation: _entryController,
                  offset: 0.1,
                  child: Column(
                    children: [
                      if (state.lastActionText != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: Responsive.h(24)),
                          child: AnimatedOpacity(
                            duration: AnimUtils.fast,
                            opacity: 1.0, 
                            child: Text(
                              state.lastActionText!,
                              style: TextStyle(
                                color: AppColors.primary, 
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                                fontSize: Responsive.sp(16),
                              ),
                            ),
                          ),
                        ),
                        
                      GlassContainer(
                        key: _pileKey, 
                        width: Responsive.w(140), // Scale pile
                        height: Responsive.h(180),
                        tint: Colors.black,
                        blur: 10,
                        child: Center(
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Icon(Icons.layers, size: Responsive.w(40), color: AppColors.primaryDim),
                               SizedBox(height: Responsive.h(16)),
                               Text(
                                 '${state.pileCount}${AppStrings.unitsSuffix}',
                                 style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                   color: AppColors.textPrimary,
                                   fontSize: Responsive.sp(24),
                                 ),
                               )
                             ],
                           ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. User Controls & Fan
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: bottomContainerHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                     // Action Buttons
                     Positioned(
                       bottom: bottomContainerHeight * 0.65, // Relative position
                       left: 0, 
                       right: 0,
                       child: AnimUtils.slideUpFade(
                         animation: _entryController,
                         offset: 0.2,
                         child: Padding(
                           padding: EdgeInsets.symmetric(horizontal: Responsive.w(AppDimens.paddingL)),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                                PrimaryButton(
                                  label: AppStrings.btnPass, 
                                  type: ButtonType.secondary,
                                  onPressed: provider.selectedUnitIds.isEmpty ? () => provider.passTurn() : null,
                                ),
                                SizedBox(width: Responsive.w(AppDimens.paddingM)),
                                if (provider.selectedUnitIds.isNotEmpty) ...[
                                  PrimaryButton(
                                    label: '${AppStrings.btnSubmit} (${provider.selectedUnitIds.length})',
                                    type: ButtonType.primary,
                                    onPressed: () => _triggerSubmitAnimation(provider),
                                  ),
                                ],
                                if (state.lastActionText != null && state.activeParticipantId == 'me') ...[
                                   SizedBox(width: Responsive.w(AppDimens.paddingM)),
                                    PrimaryButton(
                                     label: AppStrings.btnRaise,
                                     type: ButtonType.danger,
                                     onPressed: () => provider.raiseChallenge(),
                                   ),
                                ]
                             ],
                           ),
                         ),
                       ),
                     ),
                     
                     // Fan Layout
                     Positioned(
                        bottom: -Responsive.h(40), 
                        child: SizedBox(
                          width: Responsive.screenWidth,
                          height: Responsive.h(250),
                          child: _buildFan(context, state.myHand, provider),
                        ),
                     ),
                  ],
                ),
              ),
            ),
            
            // 4. Flying Units Layer
            if (_flyingUnits.isNotEmpty)
               ..._buildFlyingUnits(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFan(BuildContext context, List<Unit> hand, SessionProvider provider) {
    if (hand.isEmpty) return const SizedBox.shrink();
    
    final count = hand.length;
    final centerIndex = (count - 1) / 2;
    // Scale radius slightly for bigger screens if needed, usually fixed radius is fine for arc
    // but scaling offsetX logic is important.
    const double radius = 800; // Keep radius large for flat arc
    const double angleStep = 0.08;
    
    return Stack(
      children: List.generate(count, (index) {
         final unit = hand[index];
         final isFlying = _flyingUnits.any((u) => u.id == unit.id);
         final isSelected = provider.selectedUnitIds.contains(unit.id);
         
         final double rotation = (index - centerIndex) * angleStep;
         final double offsetX = radius * math.sin(rotation);
         final double offsetY = radius - (radius * math.cos(rotation));
         
         // Center based on screen width
         final double left = (Responsive.screenWidth / 2) - (Responsive.w(AppDimens.cardWidth) / 2) + offsetX;
         final double bottom = Responsive.h(40) - offsetY + (isSelected ? Responsive.h(40) : 0);
         
         return AnimatedPositioned(
            duration: AnimUtils.medium, 
            curve: AnimUtils.easeOutBack,
            left: left,
            bottom: bottom, 
            child: Transform.rotate(
               angle: rotation,
               child: AnimatedScale(
                 duration: AnimUtils.micro,
                 scale: isSelected ? 1.08 : 1.0,
                 child: Opacity(
                   opacity: isFlying ? 0.0 : 1.0, 
                   child: SizedBox(
                      width: Responsive.w(AppDimens.cardWidth), // Scaled Card
                      height: Responsive.h(AppDimens.cardHeight),
                      child: UnitCard(
                          unit: unit,
                          isSelected: isSelected,
                          rotation: 0, 
                          onTap: () => provider.toggleUnitSelection(unit.id),
                       ),
                   ),
                 ),
               ),
            ),
         );
      }),
    );
  }
  
  List<Widget> _buildFlyingUnits() {
      final totalCount = context.read<SessionProvider>().state.myHand.length;
      final hand = context.read<SessionProvider>().state.myHand;

      return _flyingUnits.map((unit) {
         final index = hand.indexOf(unit); 
         
         final centerIndex = (totalCount - 1) / 2;
         const double radius = 800;
         const double angleStep = 0.08;
         final double rotation = (index - centerIndex) * angleStep;
         final double offsetX = radius * math.sin(rotation);
         final double offsetY = radius - (radius * math.cos(rotation));
         
         final double startLeft = (Responsive.screenWidth / 2) - (Responsive.w(AppDimens.cardWidth) / 2) + offsetX;
         final double startBottom = Responsive.h(40) - offsetY + Responsive.h(40); 
         
         // Use visual calc top
         final double startTop = Responsive.screenHeight + Responsive.h(40) - startBottom - Responsive.h(AppDimens.cardHeight);
         
         final double targetTop = _pilePosition.dy - (Responsive.h(AppDimens.cardHeight) / 2);
         final double targetLeft = _pilePosition.dx - (Responsive.w(AppDimens.cardWidth) / 2);
         
         return AnimatedBuilder(
            animation: _flightController,
            builder: (context, child) {
               final val = _flightController.value;
               final curveVal = Curves.easeInOut.transform(val);
               
               final currentLeft = double.lerp(startLeft, targetLeft, curveVal) ?? 0;
               final currentTop = double.lerp(startTop, targetTop, curveVal) ?? 0;
               final currentScale = double.lerp(1.0, 0.4, curveVal) ?? 1.0; 
               final currentRotation = double.lerp(rotation, math.pi, curveVal) ?? 0; 
               
               return Positioned(
                  left: currentLeft,
                  top: currentTop,
                  child: Transform.rotate(
                     angle: currentRotation, 
                     child: Transform.scale(
                        scale: currentScale,
                        child: SizedBox(
                           width: Responsive.w(AppDimens.cardWidth),
                           height: Responsive.h(AppDimens.cardHeight),
                           child: UnitCard(unit: unit, isSelected: true)
                        ),
                     ),
                  ),
               );
            },
         );
      }).toList();
  }
}
