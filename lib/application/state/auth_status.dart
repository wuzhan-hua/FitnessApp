enum AuthStatus { signedOut, guest, authenticated }

extension AuthStatusX on AuthStatus {
  bool get isSignedIn => this != AuthStatus.signedOut;
  bool get isGuest => this == AuthStatus.guest;
}

class AuthSessionSnapshot {
  const AuthSessionSnapshot({required this.status, required this.userId});

  final AuthStatus status;
  final String? userId;
}
