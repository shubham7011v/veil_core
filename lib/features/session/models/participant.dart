import 'package:equatable/equatable.dart';

class Participant extends Equatable {
  final String id;
  final String name;
  final String avatarUrl; // For mock, we'll use asset paths or colors
  final int unitCount;
  final bool isMe;
  final bool isActive; // Is it their turn?

  const Participant({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    required this.unitCount,
    this.isMe = false,
    this.isActive = false,
  });

  @override
  List<Object?> get props => [id, name, avatarUrl, unitCount, isMe, isActive];

  Participant copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    int? unitCount,
    bool? isMe,
    bool? isActive,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      unitCount: unitCount ?? this.unitCount,
      isMe: isMe ?? this.isMe,
      isActive: isActive ?? this.isActive,
    );
  }
}
