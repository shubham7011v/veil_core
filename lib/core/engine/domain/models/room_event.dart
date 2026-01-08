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

  const RoomCreated({
    required this.roomCode,
    required this.roomId,
    required this.roomName,
    required this.hostId,
  });

  factory RoomCreated.fromJson(Map<String, dynamic> json) {
    return RoomCreated(
      roomCode: json['roomCode'] as String,
      roomId: json['roomId'] as String,
      roomName: json['roomName'] as String,
      hostId: json['hostId'] as String,
    );
  }

  @override
  List<Object?> get props => [roomCode, roomId, roomName, hostId];
}

class RoomJoined extends RoomEvent {
  final String roomCode;
  final String roomName;
  final String hostId;

  const RoomJoined({
    required this.roomCode,
    required this.roomName,
    required this.hostId,
  });

  factory RoomJoined.fromJson(Map<String, dynamic> json) {
    return RoomJoined(
      roomCode: json['roomCode'] as String,
      roomName: json['roomName'] as String,
      hostId: json['hostId'] as String,
    );
  }

  @override
  List<Object?> get props => [roomCode, roomName, hostId];
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

  const RoomUpdated({
    required this.roomCode,
    this.roomName,
    required this.hostId,
    required this.participants,
    required this.playerCount,
    required this.maxPlayers,
    required this.bootAmount,
    required this.isGameStarted,
  });

  factory RoomUpdated.fromJson(Map<String, dynamic> json) {
    final participantsList = json['participants'] as List<dynamic>? ?? [];
    final participants = participantsList.map((p) {
      final pMap = p as Map<String, dynamic>;
      return Participant(
        id: pMap['id'] as String,
        name: pMap['name'] as String,
        unitCount: pMap['cardCount'] as int? ?? 0,
        // TODO: Dynamically determine isMe by comparing with current user ID from AuthBloc
        isMe: false,
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
