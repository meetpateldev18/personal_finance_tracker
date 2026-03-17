import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_providers.dart';
import '../models/budget_model.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.read(budgetDioProvider));
});

class BudgetRepository {
  BudgetRepository(this._dio);
  final Dio _dio;

  Future<List<BudgetModel>> getBudgets() async {
    final response = await _dio.get('/budgets');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => BudgetModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BudgetModel> createBudget({
    required String categoryId,
    required double amount,
    required String period,
    required double alertThresholdPct,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _dio.post('/budgets', data: {
      'categoryId': categoryId,
      'amount': amount,
      'period': period,
      'alertThresholdPct': alertThresholdPct,
      'startDate': startDate.toIso8601String().substring(0, 10),
      'endDate': endDate.toIso8601String().substring(0, 10),
    });
    return BudgetModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BudgetModel> updateBudget(String id, double amount) async {
    final response = await _dio.put('/budgets/$id', data: {'amount': amount});
    return BudgetModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteBudget(String id) async {
    await _dio.delete('/budgets/$id');
  }
}
