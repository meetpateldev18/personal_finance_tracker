class BudgetModel {
  const BudgetModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.spentAmount,
    required this.period,
    required this.alertThresholdPct,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  final String id;
  final String userId;
  final String categoryId;
  final String categoryName;
  final double amount;
  final double spentAmount;
  final String period; // WEEKLY | MONTHLY | YEARLY
  final double alertThresholdPct;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  double get usagePercentage =>
      amount > 0 ? (spentAmount / amount * 100).clamp(0, 100) : 0;

  double get remainingAmount => (amount - spentAmount).clamp(0, double.infinity);

  bool get isExceeded => spentAmount > amount;

  bool get isNearLimit => usagePercentage >= alertThresholdPct && !isExceeded;

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String? ?? '',
      amount: (json['amount'] as num).toDouble(),
      spentAmount: (json['spentAmount'] as num).toDouble(),
      period: json['period'] as String,
      alertThresholdPct: (json['alertThresholdPct'] as num).toDouble(),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
