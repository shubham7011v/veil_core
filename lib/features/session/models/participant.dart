
class Participant {
  final String id;
  final String name;
  final String avatarUrl; // For mock, we'll use asset paths or colors
  final int unitCount;
  final bool isMe;
  final bool isActive; // Is it their turn?
  
  Participant({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    required this.unitCount,
    this.isMe = false,
    this.isActive = false,
  });

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
