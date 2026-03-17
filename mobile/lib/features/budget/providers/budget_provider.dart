import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget_model.dart';
import '../repositories/budget_repository.dart';

final budgetListProvider =
    AsyncNotifierProvider<BudgetListNotifier, List<BudgetModel>>(
        BudgetListNotifier.new);

class BudgetListNotifier extends AsyncNotifier<List<BudgetModel>> {
  @override
  Future<List<BudgetModel>> build() async {
    return ref.read(budgetRepositoryProvider).getBudgets();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(budgetRepositoryProvider).getBudgets(),
    );
  }

  Future<void> createBudget({
    required String categoryId,
    required double amount,
    required String period,
    required double alertThresholdPct,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final budget = await ref.read(budgetRepositoryProvider).createBudget(
          categoryId: categoryId,
          amount: amount,
          period: period,
          alertThresholdPct: alertThresholdPct,
          startDate: startDate,
          endDate: endDate,
        );
    state = AsyncData([...?state.valueOrNull, budget]);
  }

  Future<void> deleteBudget(String id) async {
    await ref.read(budgetRepositoryProvider).deleteBudget(id);
    state = AsyncData(
      state.valueOrNull?.where((b) => b.id != id).toList() ?? [],
    );
  }
}
