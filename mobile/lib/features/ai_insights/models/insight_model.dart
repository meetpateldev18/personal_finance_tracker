class InsightModel {
  const InsightModel({
    required this.type,
    required this.content,
    required this.generatedAt,
  });

  final String type;
  final String content;
  final DateTime generatedAt;

  factory InsightModel.fromJson(Map<String, dynamic> json) {
    return InsightModel(
      type: json['type'] as String,
      content: json['content'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netBalance,
    required this.transactionCount,
  });

  final double totalIncome;
  final double totalExpenses;
  final double netBalance;
  final int transactionCount;

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalIncome: (json['totalIncome'] as num).toDouble(),
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      netBalance: (json['netBalance'] as num).toDouble(),
      transactionCount: json['transactionCount'] as int,
    );
  }
}

class CategoryBreakdown {
  const CategoryBreakdown({
    required this.categoryName,
    required this.totalAmount,
    required this.percentage,
    required this.transactionCount,
  });

  final String categoryName;
  final double totalAmount;
  final double percentage;
  final int transactionCount;

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      categoryName: json['categoryName'] as String,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
      transactionCount: json['transactionCount'] as int,
    );
  }
}

class MonthlyTrend {
  const MonthlyTrend({
    required this.month,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netBalance,
  });

  final String month;
  final double totalIncome;
  final double totalExpenses;
  final double netBalance;

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) {
    return MonthlyTrend(
      month: json['month'] as String,
      totalIncome: (json['totalIncome'] as num).toDouble(),
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      netBalance: (json['netBalance'] as num).toDouble(),
    );
  }
}
