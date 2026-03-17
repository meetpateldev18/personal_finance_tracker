import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/transaction_provider.dart';
import '../../../../core/theme/app_theme.dart';

final _currencyFmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState
    extends ConsumerState<TransactionListScreen> {
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          PopupMenuButton<String?>(
            initialValue: _selectedType,
            icon: Icon(
              _selectedType != null
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            onSelected: (v) {
              setState(() => _selectedType = v);
              ref.invalidate(transactionListProvider);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('All')),
              PopupMenuItem(value: 'INCOME', child: Text('Income')),
              PopupMenuItem(value: 'EXPENSE', child: Text('Expense')),
              PopupMenuItem(value: 'TRANSFER', child: Text('Transfer')),
            ],
          ),
        ],
      ),
      body: txAsync.when(
        data: (txs) {
          final filtered = _selectedType == null
              ? txs
              : txs.where((t) => t.type == _selectedType).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 64),
                  const SizedBox(height: 8),
                  const Text('No transactions found'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Transaction'),
                    onPressed: () => context.go('/transactions/add'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.read(transactionListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _TransactionCard(tx: filtered[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({required this.tx});
  final dynamic tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isExpense = tx.type == 'EXPENSE';
    final color = isExpense ? colors.expense : colors.income;
    final sign = isExpense ? '-' : '+';

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: colors.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outlined, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: const Text('Are you sure you want to delete this transaction?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete')),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref
            .read(transactionListProvider.notifier)
            .deleteTransaction(tx.id);
      },
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(
              isExpense ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
              size: 18,
            ),
          ),
          title: Text(
            tx.description.isEmpty ? tx.categoryName : tx.description,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx.categoryName,
                  style: const TextStyle(fontSize: 12)),
              Text(
                DateFormat('MMM d, yyyy').format(tx.transactionDate),
                style: const TextStyle(fontSize: 11),
              ),
              if (tx.isFlagged)
                const Text('⚠️ Flagged',
                    style: TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
          trailing: Text(
            '$sign${_currencyFmt.format(tx.amount)}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
