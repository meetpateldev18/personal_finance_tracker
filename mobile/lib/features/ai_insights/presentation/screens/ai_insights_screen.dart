import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../repositories/analytics_repository.dart';
import '../../models/insight_model.dart';
import '../../../../core/theme/app_theme.dart';

final _spendingAnalysisProvider =
    FutureProvider.autoDispose<InsightModel>((ref) async {
  return ref.read(analyticsRepositoryProvider).analyzeSpending();
});

final _healthScoreProvider =
    FutureProvider.autoDispose<InsightModel>((ref) async {
  return ref.read(analyticsRepositoryProvider).getHealthScore();
});

final _categoryBreakdownProvider =
    FutureProvider.autoDispose<List<CategoryBreakdown>>((ref) async {
  final now = DateTime.now();
  return ref.read(analyticsRepositoryProvider).getCategoryBreakdown(
        from: DateTime(now.year, now.month, 1),
        to: now,
      );
});

class AiInsightsScreen extends ConsumerStatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  ConsumerState<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends ConsumerState<AiInsightsScreen> {
  final _questionCtrl = TextEditingController();
  InsightModel? _answer;
  bool _asking = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _askQuestion() async {
    final q = _questionCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _asking = true);
    try {
      final answer =
          await ref.read(analyticsRepositoryProvider).askQuestion(q);
      setState(() => _answer = answer);
      _questionCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_spendingAnalysisProvider);
              ref.invalidate(_healthScoreProvider);
              ref.invalidate(_categoryBreakdownProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Health Score
          _SectionTitle(title: '🏥 Financial Health Score'),
          ref.watch(_healthScoreProvider).when(
                data: (insight) => _InsightCard(insight: insight),
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: e.toString()),
              ),
          const SizedBox(height: 20),

          // Spending patterns
          _SectionTitle(title: '🔍 Spending Analysis'),
          ref.watch(_spendingAnalysisProvider).when(
                data: (insight) => _InsightCard(insight: insight),
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: e.toString()),
              ),
          const SizedBox(height: 20),

          // Category pie chart
          _SectionTitle(title: '📊 This Month by Category'),
          ref.watch(_categoryBreakdownProvider).when(
                data: (breakdown) => breakdown.isEmpty
                    ? const _EmptyCard()
                    : _CategoryPieChart(breakdown: breakdown),
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: e.toString()),
              ),
          const SizedBox(height: 20),

          // Ask AI
          _SectionTitle(title: '🤖 Ask Your Finance Advisor'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _questionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'Ask anything — "How can I save more?" or "Should I invest?"',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Ask'),
                    onPressed: _asking ? null : _askQuestion,
                  ),
                  if (_answer != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    Text(
                      _answer!.content,
                      style: const TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMd()
                          .add_jm()
                          .format(_answer!.generatedAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final InsightModel insight;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(insight.content, style: const TextStyle(height: 1.6)),
            const SizedBox(height: 8),
            Text(
              'Generated ${DateFormat.yMMMd().add_jm().format(insight.generatedAt)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart({required this.breakdown});
  final List<CategoryBreakdown> breakdown;

  static const _colors = [
    Color(0xFF6C63FF), Color(0xFF03DAC6), Color(0xFFFFC107),
    Color(0xFFE91E63), Color(0xFF4CAF50), Color(0xFF2196F3),
    Color(0xFFFF5722), Color(0xFF9C27B0),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: List.generate(
                    breakdown.length.clamp(0, _colors.length),
                    (i) => PieChartSectionData(
                      value: breakdown[i].totalAmount,
                      color: _colors[i % _colors.length],
                      title: '${breakdown[i].percentage.toStringAsFixed(0)}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(
                breakdown.length.clamp(0, _colors.length),
                (i) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      color: _colors[i % _colors.length],
                    ),
                    const SizedBox(width: 4),
                    Text(breakdown[i].categoryName,
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
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
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child:
                Text(message, style: const TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No data for this period')),
      ),
    );
  }
}
