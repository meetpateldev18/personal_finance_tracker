import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

final transactionListProvider =
    AsyncNotifierProvider<TransactionListNotifier, List<TransactionModel>>(
        TransactionListNotifier.new);

class TransactionListNotifier
    extends AsyncNotifier<List<TransactionModel>> {
  @override
  Future<List<TransactionModel>> build() async {
    return ref.read(transactionRepositoryProvider).getTransactions();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(transactionRepositoryProvider).getTransactions(),
    );
  }

  Future<void> addTransaction({
    required String categoryId,
    required String type,
    required double amount,
    required String description,
    required DateTime transactionDate,
    List<String>? tags,
    String? receiptPath,
  }) async {
    final newTx = await ref
        .read(transactionRepositoryProvider)
        .createTransaction(
          categoryId: categoryId,
          type: type,
          amount: amount,
          description: description,
          transactionDate: transactionDate,
          tags: tags,
          receiptPath: receiptPath,
        );
    state = AsyncData([newTx, ...?state.valueOrNull]);
  }

  Future<void> deleteTransaction(String id) async {
    await ref.read(transactionRepositoryProvider).deleteTransaction(id);
    state = AsyncData(
      state.valueOrNull?.where((t) => t.id != id).toList() ?? [],
    );
  }
}
