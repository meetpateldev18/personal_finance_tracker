import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_providers.dart';
import '../models/insight_model.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(
    analyticsDio: ref.read(analyticsDioProvider),
    aiDio: ref.read(aiDioProvider),
  );
});

class AnalyticsRepository {
  AnalyticsRepository({required Dio analyticsDio, required Dio aiDio})
      : _analyticsDio = analyticsDio,
        _aiDio = aiDio;

  final Dio _analyticsDio;
  final Dio _aiDio;

  Future<AnalyticsSummary> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _analyticsDio.get('/analytics/summary', queryParameters: {
      'from': from.toIso8601String().substring(0, 10),
      'to': to.toIso8601String().substring(0, 10),
    });
    return AnalyticsSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CategoryBreakdown>> getCategoryBreakdown({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _analyticsDio.get('/analytics/category-breakdown', queryParameters: {
      'from': from.toIso8601String().substring(0, 10),
      'to': to.toIso8601String().substring(0, 10),
    });
    final data = response.data as List<dynamic>;
    return data
        .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MonthlyTrend>> getMonthlyTrend({int months = 6}) async {
    final response = await _analyticsDio.get('/analytics/monthly-trend',
        queryParameters: {'months': months});
    final data = response.data as List<dynamic>;
    return data
        .map((e) => MonthlyTrend.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InsightModel> analyzeSpending() async {
    final response = await _aiDio.post('/ai/spending-analysis');
    return InsightModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<InsightModel> getBudgetRecommendations() async {
    final response = await _aiDio.post('/ai/budget-recommendations');
    return InsightModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<InsightModel> getHealthScore() async {
    final response = await _aiDio.post('/ai/health-score');
    return InsightModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<InsightModel> askQuestion(String question) async {
    final response = await _aiDio.post('/ai/ask', data: {'question': question});
    return InsightModel.fromJson(response.data as Map<String, dynamic>);
  }
}
