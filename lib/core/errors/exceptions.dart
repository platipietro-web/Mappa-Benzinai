class AppException implements Exception {
  final String message;
  final String? code;

  AppException({required this.message, this.code});

  @override
  String toString() => message;
}

class LocationException extends AppException {
  LocationException({required String message})
      : super(message: message, code: 'LOCATION_ERROR');
}

class NetworkException extends AppException {
  NetworkException({required String message})
      : super(message: message, code: 'NETWORK_ERROR');
}

class DatabaseException extends AppException {
  DatabaseException({required String message})
      : super(message: message, code: 'DATABASE_ERROR');
}

class AuthException extends AppException {
  AuthException({required String message})
      : super(message: message, code: 'AUTH_ERROR');
}

class CacheException extends AppException {
  CacheException({required String message})
      : super(message: message, code: 'CACHE_ERROR');
}

class ApiException extends AppException {
  final int? statusCode;

  ApiException({
    required String message,
    this.statusCode,
  }) : super(message: message, code: 'API_ERROR');
}
