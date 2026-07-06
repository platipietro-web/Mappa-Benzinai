import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String userId;
  final String? email;
  final String? displayName;

  const UserProfile({
    required this.userId,
    this.email,
    this.displayName,
  });

  UserProfile copyWith({
    String? email,
    String? displayName,
  }) =>
      UserProfile(
        userId: userId,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
      );

  @override
  List<Object?> get props => [userId, email, displayName];
}
