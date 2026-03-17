import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost';

  static String get userServiceUrl => '$baseUrl:8081/api/v1';
  static String get transactionServiceUrl => '$baseUrl:8082/api/v1';
  static String get budgetServiceUrl => '$baseUrl:8083/api/v1';
  static String get analyticsServiceUrl => '$baseUrl:8084/api/v1';
  static String get notificationServiceUrl => '$baseUrl:8085/api/v1';
  static String get aiServiceUrl => '$baseUrl:8086/api/v1';

  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;
}
