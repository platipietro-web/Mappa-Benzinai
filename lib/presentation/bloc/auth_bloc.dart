import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class SignUpEvent extends AuthEvent {
  final String email;
  final String password;
  final String? displayName;

  const SignUpEvent({required this.email, required this.password, this.displayName});

  @override
  List<Object?> get props => [email, password, displayName];
}

class SignInEvent extends AuthEvent {
  final String email;
  final String password;

  const SignInEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignInAnonymouslyEvent extends AuthEvent {
  const SignInAnonymouslyEvent();
}

class SignOutEvent extends AuthEvent {
  final bool signUpMode;
  const SignOutEvent({this.signUpMode = false});

  @override
  List<Object?> get props => [signUpMode];
}

class AuthStatusChangedEvent extends AuthEvent {
  final String? userId;

  const AuthStatusChangedEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ResetPasswordEvent extends AuthEvent {
  final String email;

  const ResetPasswordEvent(this.email);

  @override
  List<Object?> get props => [email];
}

// States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final String userId;
  final bool isAnonymous;

  const Authenticated({required this.userId, this.isAnonymous = false});

  @override
  List<Object?> get props => [userId, isAnonymous];
}

class Unauthenticated extends AuthState {
  final bool signUpMode;
  const Unauthenticated({this.signUpMode = false});

  @override
  List<Object?> get props => [signUpMode];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(const AuthInitial()) {
    on<SignUpEvent>(_onSignUp);
    on<SignInEvent>(_onSignIn);
    on<SignInAnonymouslyEvent>(_onSignInAnonymously);
    on<SignOutEvent>(_onSignOut);
    on<AuthStatusChangedEvent>(_onAuthStatusChanged);
    on<ResetPasswordEvent>(_onResetPassword);

    // Listen to auth state changes
    _authRepository.authStateChanges().listen((userId) {
      add(AuthStatusChangedEvent(userId));
    });
  }

  Future<void> _onSignUp(
    SignUpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signUpWithEmail(
        event.email,
        event.password,
        displayName: event.displayName,
      );
      final userId = _authRepository.getCurrentUserId();
      if (userId != null) {
        emit(Authenticated(userId: userId));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignIn(
    SignInEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signInWithEmail(event.email, event.password);
      final userId = _authRepository.getCurrentUserId();
      if (userId != null) {
        emit(Authenticated(userId: userId));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInAnonymously(
    SignInAnonymouslyEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signInAnonymously();
      final userId = _authRepository.getCurrentUserId();
      if (userId != null) {
        emit(Authenticated(userId: userId, isAnonymous: true));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signOut();
      emit(Unauthenticated(signUpMode: event.signUpMode));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  void _onAuthStatusChanged(
    AuthStatusChangedEvent event,
    Emitter<AuthState> emit,
  ) {
    if (event.userId != null) {
      emit(Authenticated(
        userId: event.userId!,
        isAnonymous: _authRepository.isCurrentUserAnonymous(),
      ));
    } else {
      emit(const Unauthenticated());
    }
  }

  Future<void> _onResetPassword(
    ResetPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.resetPassword(event.email);
      emit(const AuthInitial());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
