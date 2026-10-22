import 'package:flutter/foundation.dart';

enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
  guest,
}

enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  offline,
}

enum BackendProviderType {
  firebase,
  localDev,
}

@immutable
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isAnonymous;
  final DateTime? createdAt;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isAnonymous = false,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'isAnonymous': isAnonymous,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        uid: json['uid'] as String,
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
        photoUrl: json['photoUrl'] as String?,
        isAnonymous: json['isAnonymous'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isAnonymous,
    DateTime? createdAt,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AuthException implements Exception {
  final String message;
  final String code;
  final dynamic originalError;

  const AuthException({
    required this.message,
    this.code = 'unknown',
    this.originalError,
  });

  @override
  String toString() => message;
}
