import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_providers.dart';

final _slackConnectedProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  try {
    final dio = ref.read(notificationDioProvider);
    await dio.get('/slack/status');
    return true;
  } catch (_) {
    return false;
  }
});

class SlackSettingsScreen extends ConsumerStatefulWidget {
  const SlackSettingsScreen({super.key});

  @override
  ConsumerState<SlackSettingsScreen> createState() =>
      _SlackSettingsScreenState();
}

class _SlackSettingsScreenState extends ConsumerState<SlackSettingsScreen> {
  final _slackUserIdCtrl = TextEditingController();
  final _workspaceCtrl = TextEditingController();
  bool _isConnecting = false;

  @override
  void dispose() {
    _slackUserIdCtrl.dispose();
    _workspaceCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_slackUserIdCtrl.text.trim().isEmpty) return;
    setState(() => _isConnecting = true);
    try {
      final dio = ref.read(notificationDioProvider);
      await dio.post('/slack/connect', data: {
        'slackUserId': _slackUserIdCtrl.text.trim(),
        'workspaceName': _workspaceCtrl.text.trim(),
      });
      ref.invalidate(_slackConnectedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Slack connected successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    try {
      final dio = ref.read(notificationDioProvider);
      await dio.delete('/slack/disconnect');
      ref.invalidate(_slackConnectedProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedAsync = ref.watch(_slackConnectedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Slack Integration')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Slack logo + description
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A154B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text('Slack Notifications',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Receive budget alerts, spending summaries and large transaction alerts directly in Slack.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Connection status
          connectedAsync.when(
            data: (connected) => connected
                ? _ConnectedCard(onDisconnect: _disconnect)
                : _ConnectForm(
                    slackUserIdCtrl: _slackUserIdCtrl,
                    workspaceCtrl: _workspaceCtrl,
                    isLoading: _isConnecting,
                    onConnect: _connect,
                  ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ConnectForm(
              slackUserIdCtrl: _slackUserIdCtrl,
              workspaceCtrl: _workspaceCtrl,
              isLoading: _isConnecting,
              onConnect: _connect,
            ),
          ),
          const SizedBox(height: 24),

          // Available commands card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Slash Commands',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  _CommandTile(
                      command: '/balance',
                      description: 'View your current balance'),
                  _CommandTile(
                      command: '/budget',
                      description: 'Check budget usage'),
                  _CommandTile(
                      command: '/spending',
                      description: 'Monthly spending breakdown'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({required this.onDisconnect});
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFE8F5E9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Connected to Slack',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onDisconnect,
              child: const Text('Disconnect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectForm extends StatelessWidget {
  const _ConnectForm({
    required this.slackUserIdCtrl,
    required this.workspaceCtrl,
    required this.isLoading,
    required this.onConnect,
  });

  final TextEditingController slackUserIdCtrl;
  final TextEditingController workspaceCtrl;
  final bool isLoading;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Connect Your Account',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            TextField(
              controller: slackUserIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Slack User ID (e.g. U012AB3CD)',
                prefixIcon: Icon(Icons.person_outlined),
                helperText: 'Find in Slack: Profile → More → Copy member ID',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: workspaceCtrl,
              decoration: const InputDecoration(
                labelText: 'Workspace Name (optional)',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : onConnect,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect to Slack'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({required this.command, required this.description});
  final String command;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(command,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(description, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
