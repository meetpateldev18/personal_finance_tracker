import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_providers.dart';
import '../models/user_model.dart';

const _accessTokenKey = 'access_token';
const _refreshTokenKey = 'refresh_token';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.read(userServiceDioProvider),
    storage: ref.read(secureStorageProvider),
  );
});

class AuthRepository {
  AuthRepository({required Dio dio, required FlutterSecureStorage storage})
      : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<AuthTokens> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
    await _persistTokens(tokens);
    return tokens;
  }

  Future<AuthTokens> register({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'username': username,
      'fullName': fullName,
    });
    final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
    await _persistTokens(tokens);
    return tokens;
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } finally {
      await _storage.deleteAll();
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) return null;
    try {
      final response = await _dio.get('/users/me');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistTokens(AuthTokens tokens) async {
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
  }
}
