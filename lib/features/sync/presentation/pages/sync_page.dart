import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/sync_bloc.dart';
import '../../../../injection/injection_container.dart';

/// Page displaying sync engine status, pending items, and manual sync trigger.
class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SyncBloc>()..add(const CheckSyncStatus()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sync Status'),
          centerTitle: true,
        ),
        body: BlocBuilder<SyncBloc, SyncState>(
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<SyncBloc>().add(const CheckSyncStatus());
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSyncStatusCard(context, state),
                  const SizedBox(height: 16),
                  _buildSyncStats(context, state),
                  const SizedBox(height: 16),
                  _buildSyncActions(context, state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context, SyncState state) {
    final isSyncing = state is SyncInProgress;
    final isSynced = state is SyncCompleted;
    final lastSync = state is SyncStatus ? state.lastSyncTime : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isSyncing
                  ? Icons.sync
                  : isSynced
                      ? Icons.cloud_done
                      : Icons.cloud_queue,
              size: 48,
              color: isSyncing
                  ? Colors.orange
                  : isSynced
                      ? Colors.green
                      : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              isSyncing
                  ? 'Syncing...'
                  : isSynced
                      ? 'Sync Complete'
                      : 'Ready to Sync',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (lastSync != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last sync: ${DateFormat('dd/MM/yyyy HH:mm').format(lastSync)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStats(BuildContext context, SyncState state) {
    final pendingCount = state is SyncStatus ? state.pendingItems : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync Statistics', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            _buildStatRow('Pending Items', '$pendingCount', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSyncActions(BuildContext context, SyncState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync Now'),
              subtitle: const Text('Manually trigger sync with server'),
              trailing: const Icon(Icons.chevron_right),
              onTap: state is SyncInProgress ? null : () {
                context.read<SyncBloc>().add(const StartSync());
              },
            ),
          ],
        ),
      ),
    );
  }
}
