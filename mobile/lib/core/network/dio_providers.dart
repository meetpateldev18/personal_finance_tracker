import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

const _accessTokenKey = 'access_token';
const _refreshTokenKey = 'refresh_token';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

Dio _buildDio(String baseUrl) {
  return Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(milliseconds: AppConfig.connectTimeoutMs),
    receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeoutMs),
    headers: {'Content-Type': 'application/json'},
  ));
}

/// Creates a Dio instance with automatic JWT injection and transparent token refresh.
Dio buildAuthenticatedDio({
  required String baseUrl,
  required FlutterSecureStorage storage,
  required Dio authDio,
}) {
  final dio = _buildDio(baseUrl);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: _accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode != 401) {
          return handler.next(error);
        }

        // Attempt silent token refresh
        final refreshToken = await storage.read(key: _refreshTokenKey);
        if (refreshToken == null) return handler.next(error);

        try {
          final response = await authDio.post(
            '${AppConfig.userServiceUrl}/auth/refresh',
            data: {'refreshToken': refreshToken},
          );
          final newAccess = response.data['accessToken'] as String;
          final newRefresh = response.data['refreshToken'] as String;

          await storage.write(key: _accessTokenKey, value: newAccess);
          await storage.write(key: _refreshTokenKey, value: newRefresh);

          // Retry original request
          final opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccess';
          final retried = await dio.fetch(opts);
          return handler.resolve(retried);
        } catch (_) {
          await storage.deleteAll();
          return handler.next(error);
        }
      },
    ),
  );

  return dio;
}

final _unauthDioProvider = Provider<Dio>(
  (_) => _buildDio(AppConfig.userServiceUrl),
);

final userServiceDioProvider = Provider<Dio>((ref) {
  return buildAuthenticatedDio(
    baseUrl: AppConfig.userServiceUrl,
    storage: ref.read(secureStorageProvider),
    authDio: ref.read(_unauthDioProvider),
  );
});

final transactionDioProvider = Provider<Dio>((ref) {
  return buildAuthenticatedDio(
    baseUrl: AppConfig.transactionServiceUrl,
    storage: ref.read(secureStorageProvider),
    authDio: ref.read(_unauthDioProvider),
  );
});

final budgetDioProvider = Provider<Dio>((ref) {
  return buildAuthenticatedDio(
    baseUrl: AppConfig.budgetServiceUrl,
    storage: ref.read(secureStorageProvider),
    authDio: ref.read(_unauthDioProvider),
  );
});

final analyticsDioProvider = Provider<Dio>((ref) {
  return buildAuthenticatedDio(
    baseUrl: AppConfig.analyticsServiceUrl,
    storage: ref.read(secureStorageProvider),
    authDio: ref.read(_unauthDioProvider),
  );
});

final aiDioProvider = Provider<Dio>((ref) {
  return buildAuthenticatedDio(
    baseUrl: AppConfig.aiServiceUrl,
    storage: ref.read(secureStorageProvider),
    authDio: ref.read(_unauthDioProvider),
  );
});

final notificationDioProvider = Provider<Dio>((ref) {
  return buildAuthenticatedDio(
    baseUrl: AppConfig.notificationServiceUrl,
    storage: ref.read(secureStorageProvider),
    authDio: ref.read(_unauthDioProvider),
  );
});
