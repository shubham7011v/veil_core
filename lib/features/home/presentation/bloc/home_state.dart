import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/models/system_status.dart';

class HomeState extends Equatable {
  final int tabIndex;
  final SystemStatus systemStatus;
  final bool hasActiveSession;
  final String greeting;
  final HomeSideEffect? effect;

  const HomeState({
    this.tabIndex = 0,
    required this.systemStatus,
    this.hasActiveSession = false,
    this.greeting = '',
    this.effect,
  });

  HomeState copyWith({
    int? tabIndex,
    SystemStatus? systemStatus,
    bool? hasActiveSession,
    String? greeting,
    HomeSideEffect? effect,
  }) {
    return HomeState(
      tabIndex: tabIndex ?? this.tabIndex,
      systemStatus: systemStatus ?? this.systemStatus,
      hasActiveSession: hasActiveSession ?? this.hasActiveSession,
      greeting: greeting ?? this.greeting,
      effect: effect,
    );
  }

  @override
  List<Object?> get props => [
    tabIndex,
    systemStatus,
    hasActiveSession,
    greeting,
    effect,
  ];
}

// Side Effects
abstract class HomeSideEffect extends Equatable {
  @override
  List<Object?> get props => [];
}

class HomeNavigateTo extends HomeSideEffect {
  final String route;
  HomeNavigateTo(this.route);
  @override
  List<Object?> get props => [route];
}

class HomeShowRejoinDialog extends HomeSideEffect {}

class HomeShowInsufficientCoinsDialog extends HomeSideEffect {}

class HomeShowSnackBar extends HomeSideEffect {
  final String message;
  HomeShowSnackBar(this.message);
  @override
  List<Object?> get props => [message];
}

class HomeShowComingSoonDialog extends HomeSideEffect {
  final String featureName;
  final String description;
  final IconData icon;

  HomeShowComingSoonDialog({
    required this.featureName,
    required this.description,
    required this.icon,
  });

  @override
  List<Object?> get props => [featureName, description, icon];
}
