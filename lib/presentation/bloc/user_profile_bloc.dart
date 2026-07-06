import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_profile.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class UserProfileEvent extends Equatable {
  const UserProfileEvent();
  @override
  List<Object?> get props => [];
}

class LoadUserProfileEvent extends UserProfileEvent {
  final String userId;
  const LoadUserProfileEvent(this.userId);
  @override
  List<Object?> get props => [userId];
}

class ClearUserProfileEvent extends UserProfileEvent {
  const ClearUserProfileEvent();
}

// ─── State ────────────────────────────────────────────────────────────────────

class UserProfileState extends Equatable {
  final UserProfile? profile;
  final bool isLoading;

  const UserProfileState({
    this.profile,
    this.isLoading = false,
  });

  UserProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
  }) =>
      UserProfileState(
        profile: profile ?? this.profile,
        isLoading: isLoading ?? this.isLoading,
      );

  UserProfile profileOrDefault(String userId) =>
      profile ?? UserProfile(userId: userId);

  @override
  List<Object?> get props => [profile, isLoading];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final UserProfileRepository _repo;

  UserProfileBloc(this._repo) : super(const UserProfileState()) {
    on<LoadUserProfileEvent>(_onLoad);
    on<ClearUserProfileEvent>(_onClear);
  }

  Future<void> _onLoad(
    LoadUserProfileEvent event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final profile = await _repo.getUserProfile(event.userId);
    emit(state.copyWith(
      profile: profile ?? UserProfile(userId: event.userId),
      isLoading: false,
    ));
  }

  void _onClear(ClearUserProfileEvent event, Emitter<UserProfileState> emit) {
    emit(const UserProfileState());
  }
}
