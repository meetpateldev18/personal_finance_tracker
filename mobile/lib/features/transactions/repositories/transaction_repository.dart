import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_providers.dart';
import '../models/transaction_model.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.read(transactionDioProvider));
});

class TransactionRepository {
  TransactionRepository(this._dio);
  final Dio _dio;

  Future<List<TransactionModel>> getTransactions({
    int page = 0,
    int size = 20,
    String? type,
    String? categoryId,
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (type != null) 'type': type,
      if (categoryId != null) 'categoryId': categoryId,
      if (from != null) 'from': from.toIso8601String().substring(0, 10),
      if (to != null) 'to': to.toIso8601String().substring(0, 10),
    };
    final response = await _dio.get('/transactions', queryParameters: params);
    final content = response.data['content'] as List<dynamic>;
    return content
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionModel> createTransaction({
    required String categoryId,
    required String type,
    required double amount,
    required String description,
    required DateTime transactionDate,
    List<String>? tags,
    String? receiptPath,
  }) async {
    FormData formData;

    final fields = {
      'categoryId': categoryId,
      'type': type,
      'amount': amount.toString(),
      'description': description,
      'transactionDate': transactionDate.toIso8601String().substring(0, 10),
      if (tags != null) 'tags': tags.join(','),
    };

    if (receiptPath != null) {
      formData = FormData.fromMap({
        ...fields,
        'receipt': await MultipartFile.fromFile(receiptPath),
      });
    } else {
      formData = FormData.fromMap(fields);
    }

    final response = await _dio.post(
      '/transactions',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return TransactionModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteTransaction(String id) async {
    await _dio.delete('/transactions/$id');
  }
}
