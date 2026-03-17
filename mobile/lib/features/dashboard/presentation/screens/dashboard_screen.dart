import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../budget/providers/budget_provider.dart';
import '../../../transactions/providers/transaction_provider.dart';
import '../../../ai_insights/repositories/analytics_repository.dart';
import '../../../../core/theme/app_theme.dart';

final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

final _dashboardSummaryProvider = FutureProvider<_DashboardSummary>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final repo = ref.read(analyticsRepositoryProvider);
  final summary = await repo.getSummary(from: from, to: now);
  final trends = await repo.getMonthlyTrend(months: 6);
  return _DashboardSummary(summary: summary, trends: trends);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final summaryAsync = ref.watch(_dashboardSummaryProvider);
    final budgetsAsync = ref.watch(budgetListProvider);
    final transactionsAsync = ref.watch(transactionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Hello, ${user?.fullName.split(' ').first ?? 'there'} 👋',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('MMMM yyyy').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI Insights',
            onPressed: () => context.go('/insights'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_dashboardSummaryProvider);
          ref.invalidate(budgetListProvider);
          ref.invalidate(transactionListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Monthly summary cards
            summaryAsync.when(
              data: (data) => _SummaryCards(summary: data),
              loading: () => const _LoadingCard(height: 120),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
            const SizedBox(height: 20),

            // Spending trend chart
            summaryAsync.when(
              data: (data) => _SpendingChart(trends: data.trends),
              loading: () => const _LoadingCard(height: 200),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Budget overview
            _SectionHeader(
              title: 'Budget Overview',
              onSeeAll: () => context.go('/budgets'),
            ),
            budgetsAsync.when(
              data: (budgets) => budgets.isEmpty
                  ? _EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'No budgets yet',
                      actionLabel: 'Create Budget',
                      onAction: () => context.go('/budgets'),
                    )
                  : Column(
                      children: budgets.take(3).map(_BudgetTile.new).toList(),
                    ),
              loading: () => const _LoadingCard(height: 80),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
            const SizedBox(height: 20),

            // Recent transactions
            _SectionHeader(
              title: 'Recent Transactions',
              onSeeAll: () => context.go('/transactions'),
            ),
            transactionsAsync.when(
              data: (txs) => txs.isEmpty
                  ? _EmptyState(
                      icon: Icons.receipt_long_outlined,
                      label: 'No transactions yet',
                      actionLabel: 'Add Transaction',
                      onAction: () => context.go('/transactions/add'),
                    )
                  : Column(
                      children: txs.take(5).map(_TransactionTile.new).toList(),
                    ),
              loading: () => const _LoadingCard(height: 80),
              error: (e, _) => _ErrorCard(message: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Private widgets
// ──────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});
  final _DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final data = summary.summary;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Income',
            amount: data.totalIncome,
            color: colors.income,
            icon: Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Expenses',
            amount: data.totalExpenses,
            color: colors.expense,
            icon: Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Balance',
            amount: data.netBalance,
            color: data.netBalance >= 0 ? colors.income : colors.expense,
            icon: Icons.account_balance,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                _currencyFmt.format(amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingChart extends StatelessWidget {
  const _SpendingChart({required this.trends});
  final List<dynamic> trends;

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).extension<AppColors>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('6-Month Trend',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  barGroups: List.generate(trends.length, (i) {
                    final t = trends[i];
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                          toY: t.totalIncome, color: colors.income, width: 8),
                      BarChartRodData(
                          toY: t.totalExpenses, color: colors.expense, width: 8),
                    ]);
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= trends.length) {
                            return const SizedBox.shrink();
                          }
                          final label = (trends[idx].month as String)
                              .substring(5); // MM
                          return Text(label,
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: colors.income, label: 'Income'),
                const SizedBox(width: 16),
                _LegendDot(color: colors.expense, label: 'Expenses'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile(this.budget);
  final dynamic budget;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final pct = budget.usagePercentage / 100;
    final barColor = budget.isExceeded
        ? colors.expense
        : budget.isNearLimit
            ? colors.warning
            : colors.income;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(budget.categoryName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_currencyFmt.format(budget.spentAmount)} / ${_currencyFmt.format(budget.amount)}',
                  style: TextStyle(fontSize: 12, color: barColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: barColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(barColor),
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.tx);
  final dynamic tx;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isExpense = tx.type == 'EXPENSE';
    final color = isExpense ? colors.expense : colors.income;
    final sign = isExpense ? '-' : '+';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
            size: 18,
          ),
        ),
        title: Text(tx.description.isEmpty ? tx.categoryName : tx.description),
        subtitle: Text(
          DateFormat('MMM d, yyyy').format(tx.transactionDate),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '$sign${_currencyFmt.format(tx.amount)}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});
  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          TextButton(onPressed: onSeeAll, child: const Text('See All')),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Data class used internally by the FutureProvider
// ──────────────────────────────────────────
class _DashboardSummary {
  const _DashboardSummary({required this.summary, required this.trends});
  final dynamic summary;
  final List<dynamic> trends;
}
