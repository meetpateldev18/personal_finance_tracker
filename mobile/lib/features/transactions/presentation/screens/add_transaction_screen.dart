import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../providers/transaction_provider.dart';

// Hardcoded category list matching DB seed data; in production fetch from /categories.
const _categories = [
  {'id': '00000000-0000-0000-0000-000000000001', 'name': 'Food & Dining'},
  {'id': '00000000-0000-0000-0000-000000000002', 'name': 'Transportation'},
  {'id': '00000000-0000-0000-0000-000000000003', 'name': 'Shopping'},
  {'id': '00000000-0000-0000-0000-000000000004', 'name': 'Entertainment'},
  {'id': '00000000-0000-0000-0000-000000000005', 'name': 'Healthcare'},
  {'id': '00000000-0000-0000-0000-000000000006', 'name': 'Utilities'},
  {'id': '00000000-0000-0000-0000-000000000007', 'name': 'Housing'},
  {'id': '00000000-0000-0000-0000-000000000008', 'name': 'Education'},
  {'id': '00000000-0000-0000-0000-000000000009', 'name': 'Salary'},
  {'id': '00000000-0000-0000-0000-000000000010', 'name': 'Investment'},
  {'id': '00000000-0000-0000-0000-000000000011', 'name': 'Other'},
];

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState
    extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'EXPENSE';
  String? _categoryId;
  DateTime _date = DateTime.now();
  String? _receiptPath;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _receiptPath = file.path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(transactionListProvider.notifier).addTransaction(
            categoryId: _categoryId!,
            type: _type,
            amount: double.parse(_amountCtrl.text),
            description: _descCtrl.text.trim(),
            transactionDate: _date,
            receiptPath: _receiptPath,
          );
      if (mounted) context.go('/transactions');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Transaction type selector
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'EXPENSE',
                        label: Text('Expense'),
                        icon: Icon(Icons.arrow_upward)),
                    ButtonSegment(
                        value: 'INCOME',
                        label: Text('Income'),
                        icon: Icon(Icons.arrow_downward)),
                    ButtonSegment(
                        value: 'TRANSFER',
                        label: Text('Transfer'),
                        icon: Icon(Icons.swap_horiz)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) =>
                      setState(() => _type = s.first),
                ),
                const SizedBox(height: 24),

                // Amount
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Amount is required';
                    final parsed = double.tryParse(v);
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c['id'],
                            child: Text(c['name']!),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) => v == null ? 'Select a category' : null,
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Date picker
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(DateFormat('MMMM d, yyyy').format(_date)),
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt upload
                OutlinedButton.icon(
                  icon: Icon(_receiptPath != null
                      ? Icons.check_circle_outlined
                      : Icons.upload_file_outlined),
                  label: Text(_receiptPath != null
                      ? 'Receipt attached'
                      : 'Attach Receipt (optional)'),
                  onPressed: _pickReceipt,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Transaction'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
