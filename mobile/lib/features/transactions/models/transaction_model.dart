class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    required this.type,
    required this.amount,
    required this.description,
    required this.transactionDate,
    this.receiptUrl,
    this.isFlagged = false,
    this.tags = const [],
  });

  final String id;
  final String userId;
  final String categoryId;
  final String categoryName;
  final String type; // INCOME | EXPENSE | TRANSFER
  final double amount;
  final String description;
  final DateTime transactionDate;
  final String? receiptUrl;
  final bool isFlagged;
  final List<String> tags;

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String? ?? '',
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      receiptUrl: json['receiptUrl'] as String?,
      isFlagged: json['isFlagged'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  bool get isExpense => type == 'EXPENSE';
  bool get isIncome => type == 'INCOME';
}
