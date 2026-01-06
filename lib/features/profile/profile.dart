export 'domain/models/user_profile.dart';
export 'data/repositories/profile_repository.dart';
export 'presentation/bloc/profile_bloc.dart';
export 'presentation/bloc/profile_event.dart';
export 'presentation/bloc/profile_state.dart';

// Note: Screens are not exported to avoid circular dependencies.
// Import directly: 'package:veil_core/features/profile/presentation/screens/profile_view_screen.dart'
