import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/admin_repository.dart';

// --- Events ---
abstract class AdminEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AdminLogin extends AdminEvent {
  final String key;
  AdminLogin(this.key);
}

class LoadAdminData extends AdminEvent {}

class CloseRoomEvent extends AdminEvent {
  final String roomId;
  CloseRoomEvent(this.roomId);
}

class AdminLogout extends AdminEvent {}

// --- States ---
abstract class AdminState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {}

class AdminLoading extends AdminState {}

class AdminAuthenticated extends AdminState {
  final Map<String, dynamic> stats;
  final List<dynamic> rooms;

  AdminAuthenticated({required this.stats, required this.rooms});

  @override
  List<Object?> get props => [stats, rooms];
}

class AdminError extends AdminState {
  final String message;
  AdminError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- Bloc ---
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final AdminRepository repository;

  AdminBloc(this.repository) : super(AdminInitial()) {
    on<AdminLogin>(_onLogin);
    on<LoadAdminData>(_onLoadData);
    on<CloseRoomEvent>(_onCloseRoom);
    on<AdminLogout>((_, emit) {
      repository.setKey(''); // Clear key
      emit(AdminInitial());
    });
  }

  Future<void> _onLogin(AdminLogin event, Emitter<AdminState> emit) async {
    emit(AdminLoading());
    repository.setKey(event.key);
    try {
      // Test the key by fetching stats
      final stats = await repository.getStats();
      final rooms = await repository.getRooms();
      emit(AdminAuthenticated(stats: stats, rooms: rooms));
    } catch (e) {
      emit(AdminError("Invalid Key or Server Error: $e"));
      repository.setKey(''); // Reset invalid key
    }
  }

  Future<void> _onLoadData(
    LoadAdminData event,
    Emitter<AdminState> emit,
  ) async {
    if (state is! AdminAuthenticated) return;
    try {
      final stats = await repository.getStats();
      final rooms = await repository.getRooms();
      emit(AdminAuthenticated(stats: stats, rooms: rooms));
    } catch (e) {
      emit(AdminError("Failed to refresh data: $e"));
    }
  }

  Future<void> _onCloseRoom(
    CloseRoomEvent event,
    Emitter<AdminState> emit,
  ) async {
    try {
      await repository.closeRoom(event.roomId);
      add(LoadAdminData()); // Refresh list
    } catch (e) {
      // Ideally show a snackbar via listener, but for now we just error state
      emit(AdminError("Failed to close room: $e"));
    }
  }
}
