import 'package:equatable/equatable.dart';
import 'participant.dart';

abstract class RoomEvent extends Equatable {
  const RoomEvent();

  @override
  List<Object?> get props => [];
}

class RoomCreated extends RoomEvent {
  final String roomCode;
  final String roomId;
  final String roomName;
  final String hostId;
  final int? createdAt;

  const RoomCreated({
    required this.roomCode,
    required this.roomId,
    required this.roomName,
    required this.hostId,
    this.createdAt,
  });

  factory RoomCreated.fromJson(Map<String, dynamic> json) {
    return RoomCreated(
      roomCode: json['roomCode'] as String,
      roomId: json['roomId'] as String,
      roomName: json['roomName'] as String,
      hostId: json['hostId'] as String,
      createdAt: json['createdAt'] as int?,
    );
  }

  @override
  List<Object?> get props => [roomCode, roomId, roomName, hostId, createdAt];
}

class RoomJoined extends RoomEvent {
  final String roomCode;
  final String roomName;
  final String hostId;
  final int? createdAt;

  const RoomJoined({
    required this.roomCode,
    required this.roomName,
    required this.hostId,
    this.createdAt,
  });

  factory RoomJoined.fromJson(Map<String, dynamic> json) {
    return RoomJoined(
      roomCode: json['roomCode'] as String,
      roomName: json['roomName'] as String,
      hostId: json['hostId'] as String,
      createdAt: json['createdAt'] as int?,
    );
  }

  @override
  List<Object?> get props => [roomCode, roomName, hostId, createdAt];
}

class RoomUpdated extends RoomEvent {
  final String roomCode;
  final String? roomName;
  final String hostId;
  final List<Participant> participants;
  final int playerCount;
  final int maxPlayers;
  final double bootAmount;
  final bool isGameStarted;
  final int? createdAt;

  const RoomUpdated({
    required this.roomCode,
    this.roomName,
    required this.hostId,
    required this.participants,
    required this.playerCount,
    required this.maxPlayers,
    required this.bootAmount,
    required this.isGameStarted,
    this.createdAt,
  });

  factory RoomUpdated.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final participantsList = json['participants'] as List<dynamic>? ?? [];
    final participants = participantsList.map((p) {
      final pMap = p as Map<String, dynamic>;
      final pId = pMap['id'] as String;
      final isMe = currentUserId != null && pId == currentUserId;
      return Participant(
        id: isMe ? 'me' : pId,
        name: pMap['name'] as String,
        avatarUrl: pMap['avatarUrl'] as String?,
        unitCount: pMap['cardCount'] as int? ?? 0,
        isMe: isMe,
        isActive: pMap['isActive'] as bool? ?? false,
      );
    }).toList();

    return RoomUpdated(
      roomCode: json['roomCode'] as String,
      roomName: json['roomName'] as String?,
      hostId: json['hostId'] as String,
      participants: participants,
      playerCount: json['playerCount'] as int,
      maxPlayers: json['maxPlayers'] as int,
      bootAmount: (json['bootAmount'] as num).toDouble(),
      isGameStarted: json['isGameStarted'] as bool? ?? false,
      createdAt: json['createdAt'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    roomCode,
    roomName,
    hostId,
    participants,
    playerCount,
    maxPlayers,
    bootAmount,
    isGameStarted,
  ];
}

class RoomError extends RoomEvent {
  final String code;
  final String message;

  const RoomError({required this.code, required this.message});

  @override
  List<Object?> get props => [code, message];
}
