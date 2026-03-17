import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/budget_provider.dart';
import '../../repositories/budget_repository.dart';
import '../../../../core/theme/app_theme.dart';

final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateBudgetSheet(context, ref),
          ),
        ],
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 72),
                  const SizedBox(height: 12),
                  const Text('No budgets yet'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create Budget'),
                    onPressed: () => _showCreateBudgetSheet(context, ref),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.read(budgetListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: budgets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  _BudgetCard(budget: budgets[i], ref: ref),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showCreateBudgetSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateBudgetSheet(widgetRef: ref),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.ref});
  final dynamic budget;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final pct = budget.usagePercentage;
    final barColor = budget.isExceeded
        ? colors.expense
        : budget.isNearLimit
            ? colors.warning
            : colors.income;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.categoryName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      budget.period,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (budget.isExceeded)
                      const Chip(
                        label: Text('Exceeded', style: TextStyle(fontSize: 10)),
                        backgroundColor: Color(0xFFFFEBEE),
                        labelStyle: TextStyle(color: Colors.red),
                        padding: EdgeInsets.zero,
                      )
                    else if (budget.isNearLimit)
                      const Chip(
                        label: Text('Near Limit', style: TextStyle(fontSize: 10)),
                        backgroundColor: Color(0xFFFFF8E1),
                        labelStyle: TextStyle(color: Colors.orange),
                        padding: EdgeInsets.zero,
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.red,
                      onPressed: () => ref
                          .read(budgetListProvider.notifier)
                          .deleteBudget(budget.id),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spent: ${_currencyFmt.format(budget.spentAmount)}',
                  style: TextStyle(color: barColor, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Total: ${_currencyFmt.format(budget.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: barColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(barColor),
              borderRadius: BorderRadius.circular(4),
              minHeight: 10,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${pct.toStringAsFixed(0)}% used',
                    style: const TextStyle(fontSize: 11)),
                Text(
                  'Remaining: ${_currencyFmt.format(budget.remainingAmount)}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateBudgetSheet extends ConsumerStatefulWidget {
  const _CreateBudgetSheet({required this.widgetRef});
  final WidgetRef widgetRef;

  @override
  ConsumerState<_CreateBudgetSheet> createState() =>
      _CreateBudgetSheetState();
}

class _CreateBudgetSheetState extends ConsumerState<_CreateBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  String? _categoryId;
  String _period = 'MONTHLY';
  double _threshold = 80;
  bool _isLoading = false;

  static const _categories = [
    {'id': '00000000-0000-0000-0000-000000000001', 'name': 'Food & Dining'},
    {'id': '00000000-0000-0000-0000-000000000002', 'name': 'Transportation'},
    {'id': '00000000-0000-0000-0000-000000000003', 'name': 'Shopping'},
    {'id': '00000000-0000-0000-0000-000000000004', 'name': 'Entertainment'},
    {'id': '00000000-0000-0000-0000-000000000005', 'name': 'Healthcare'},
    {'id': '00000000-0000-0000-0000-000000000006', 'name': 'Utilities'},
    {'id': '00000000-0000-0000-0000-000000000007', 'name': 'Housing'},
    {'id': '00000000-0000-0000-0000-000000000008', 'name': 'Education'},
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);

    try {
      await ref.read(budgetListProvider.notifier).createBudget(
            categoryId: _categoryId!,
            amount: double.parse(_amountCtrl.text),
            period: _period,
            alertThresholdPct: _threshold,
            startDate: start,
            endDate: end,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Budget',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c['id'],
                        child: Text(c['name']!),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Select a category' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Budget Amount',
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null || double.parse(v) <= 0) {
                  return 'Enter valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _period,
              decoration: const InputDecoration(labelText: 'Period'),
              items: const [
                DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
              ],
              onChanged: (v) => setState(() => _period = v!),
            ),
            const SizedBox(height: 12),
            Text('Alert at ${_threshold.toInt()}% usage'),
            Slider(
              value: _threshold,
              min: 50,
              max: 100,
              divisions: 10,
              label: '${_threshold.toInt()}%',
              onChanged: (v) => setState(() => _threshold = v),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Budget'),
            ),
          ],
        ),
      ),
    );
  }
}
