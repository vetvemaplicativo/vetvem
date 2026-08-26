class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

class AuthExceptions {
  static const invalidCredentials = AuthException('E-mail ou senha incorretos.');
  static const emailAlreadyInUse = AuthException('Este e-mail já está cadastrado.');
  static const networkError = AuthException('Sem conexão. Verifique sua internet.');
  static const googleCancelled = AuthException('Login com Google cancelado.');
  static const appleCancelled = AuthException('Login com Apple cancelado.');
}
