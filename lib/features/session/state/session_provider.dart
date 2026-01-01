import 'package:flutter/material.dart';
import 'dart:math';
import '../models/participant.dart';
import '../models/session_state.dart';
import '../models/unit.dart';

class SessionProvider extends ChangeNotifier {
  SessionState _state = SessionState.initial();
  SessionState get state => _state;

  // For selecting units in UI before submitting
  final List<String> _selectedUnitIds = [];
  List<String> get selectedUnitIds => List.unmodifiable(_selectedUnitIds);

  SessionProvider() {
    _initializeMockSession();
  }

  void _initializeMockSession() {
    // 1. Create mock participants
    final participants = [
      Participant(id: 'p1', name: 'Rahul', unitCount: 5, isActive: false),
      Participant(id: 'p2', name: 'Priya', unitCount: 8, isActive: false),
      Participant(
        id: 'me',
        name: 'You',
        unitCount: 10,
        isMe: true,
        isActive: true,
      ), // Starts with user
      Participant(id: 'p3', name: 'Amit', unitCount: 3, isActive: false),
    ];

    // 2. Deal mock hand to 'me'
    final myHand = List.generate(25, (index) {
      // Random suits and ranks for demo
      final type = UnitType.values[Random().nextInt(UnitType.values.length)];
      final rank = UnitRank.values[Random().nextInt(UnitRank.values.length)];
      return Unit(id: 'u_$index', type: type, rank: rank);
    });

    _state = _state.copyWith(
      roomId: '402',
      participants: participants,
      myHand: myHand,
      currentPhase: SessionPhase.thinking,
      activeParticipantId: 'me',
      lastActionText: 'Session Started',
    );
    notifyListeners();
  }

  void toggleUnitSelection(String unitId) {
    if (_selectedUnitIds.contains(unitId)) {
      _selectedUnitIds.remove(unitId);
    } else {
      if (_selectedUnitIds.length >= 4) {
        // Limit reached, could show a snackbar or just ignore
        return;
      }
      _selectedUnitIds.add(unitId);
    }

    // Update isSelected flag in models for UI helpers if needed,
    // though purely using ID list is cleaner for state.
    // Let's update the model to trigger rebuilds if needed deep down
    final updatedHand = _state.myHand.map((u) {
      if (u.id == unitId) {
        u.isSelected = _selectedUnitIds.contains(unitId);
      }
      return u;
    }).toList();

    _state = _state.copyWith(myHand: updatedHand);
    notifyListeners();
  }

  void submitSelectedUnits() async {
    if (_selectedUnitIds.isEmpty) return;

    // 1. Remove from hand
    final remainingHand = _state.myHand
        .where((u) => !_selectedUnitIds.contains(u.id))
        .toList();

    // 2. Update self unit count
    final updatedParticipants = _state.participants.map((p) {
      if (p.isMe) {
        return p.copyWith(unitCount: remainingHand.length, isActive: false);
      }
      // Pass turn to next (simple logic: me -> p3 -> p1 -> p2)
      if (p.id == 'p3') return p.copyWith(isActive: true);
      return p;
    }).toList();

    // 3. Update pile
    final newPileCount = _state.pileCount + _selectedUnitIds.length;

    _state = _state.copyWith(
      myHand: remainingHand,
      participants: updatedParticipants,
      pileCount: newPileCount,
      activeParticipantId: 'p3', // Hardcoded next player for demo
      lastActionText: 'You declared ${_selectedUnitIds.length} cards',
    );

    _selectedUnitIds.clear();
    notifyListeners();

    // Simulate bot thinking
    _simulateBotTurn();
  }

  void _simulateBotTurn() async {
    await Future.delayed(const Duration(seconds: 2));

    // Bot 'p3' plays
    final updatedParticipants = _state.participants.map((p) {
      if (p.id == 'p3')
        return p.copyWith(isActive: false, unitCount: p.unitCount - 1);
      if (p.id == 'p1') return p.copyWith(isActive: true);
      return p;
    }).toList();

    _state = _state.copyWith(
      participants: updatedParticipants,
      pileCount: _state.pileCount + 1,
      activeParticipantId: 'p1',
      lastActionText: 'Amit declared 1 card',
    );
    notifyListeners();
  }

  void passTurn() {
    // Logic for passing (if allowed in rules, usually you can't pass if you have to play, but this is a mock)
    notifyListeners();
  }

  void raiseChallenge() {
    _state = _state.copyWith(
      lastActionText: 'You challenged the last move!',
      // In real app, reveal cards logic here
    );
    notifyListeners();
  }

  void startSession() {
    _state = _state.copyWith(
      currentPhase: SessionPhase.thinking,
      lastActionText: 'Session Started',
    );
    notifyListeners();
  }
}
