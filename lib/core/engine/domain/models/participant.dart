import 'package:equatable/equatable.dart';

class Participant extends Equatable {
  final String id;
  final String? sessionId;
  final String name;
  final String? avatarUrl;
  final String? rank;
  final int unitCount;
  final bool isMe;
  final bool isActive; // Is it their turn?
  final bool isDisconnected;

  const Participant({
    required this.id,
    this.sessionId,
    required this.name,
    this.avatarUrl,
    this.rank,
    required this.unitCount,
    this.isMe = false,
    this.isActive = false,
    this.isDisconnected = false,
  });

  @override
  List<Object?> get props => [
    id,
    sessionId,
    name,
    avatarUrl,
    rank,
    unitCount,
    isMe,
    isActive,
    isDisconnected,
  ];

  Participant copyWith({
    String? id,
    String? sessionId,
    String? name,
    String? avatarUrl,
    String? rank,
    int? unitCount,
    bool? isMe,
    bool? isActive,
    bool? isDisconnected,
  }) {
    return Participant(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rank: rank ?? this.rank,
      unitCount: unitCount ?? this.unitCount,
      isMe: isMe ?? this.isMe,
      isActive: isActive ?? this.isActive,
      isDisconnected: isDisconnected ?? this.isDisconnected,
    );
  }
}
