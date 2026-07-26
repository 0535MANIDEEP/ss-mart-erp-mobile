import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/challans_bloc.dart';
import '../../domain/entities/delivery_challan.dart';
import '../../../../injection/injection_container.dart';
import 'challan_form_page.dart';
import 'challan_detail_page.dart';
import '../../../../shared/widgets/search_bar_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';

/// List page displaying all delivery challans with status filter tabs.
///
/// Provides a tabbed view (All | Pending | Dispatched | Delivered) with
/// search functionality and a FAB for creating new challans. Tapping a
/// challan navigates to the detail view; long-pressing reveals quick actions.
///
/// Dispatches [LoadChallans] on init and on pull-to-refresh. Status filter
/// tabs dispatch a new [LoadChallans] with the selected status parameter.
class ChallansPage extends StatelessWidget {
  const ChallansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChallansBloc>()..add(const LoadChallans()),
      child: const _ChallansView(),
    );
  }
}

class _ChallansView extends StatefulWidget {
  const _ChallansView();

  @override
  State<_ChallansView> createState() => _ChallansViewState();
}

class _ChallansViewState extends State<_ChallansView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _tabs = [
    Tab(text: 'All'),
    Tab(text: 'Pending'),
    Tab(text: 'Dispatched'),
    Tab(text: 'Delivered'),
  ];

  static const _tabStatuses = [null, 'pending', 'dispatched', 'delivered'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final status = _tabStatuses[_tabController.index];
      context.read<ChallansBloc>().add(LoadChallans(status: status));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Challans'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
        ),
      ),
      body: Column(
        children: [
          SearchBarWidget(
            hintText: 'Search challans...',
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          Expanded(
            child: BlocConsumer<ChallansBloc, ChallansState>(
              listener: (context, state) {
                if (state is ChallanDeleted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Challan deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  context.read<ChallansBloc>().add(const LoadChallans());
                }
              },
              builder: (context, state) {
                if (state is ChallansLoading) {
                  return const LoadingWidget(message: 'Loading challans...');
                }
                if (state is ChallansError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${state.message}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            final status = _tabStatuses[_tabController.index];
                            context
                                .read<ChallansBloc>()
                                .add(LoadChallans(status: status));
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (state is ChallansLoaded) {
                  final filtered = _filterChallans(state.challans);
                  if (filtered.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.local_shipping_outlined,
                      title: 'No challans found',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'Try a different search term'
                          : 'Tap + to create your first delivery challan',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      final status = _tabStatuses[_tabController.index];
                      context
                          .read<ChallansBloc>()
                          .add(LoadChallans(status: status));
                    },
                    child: _buildChallansList(filtered),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => const ChallanFormPage(),
            ),
          );
          if (result == true && mounted) {
            final status = _tabStatuses[_tabController.index];
            context.read<ChallansBloc>().add(LoadChallans(status: status));
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  List<DeliveryChallan> _filterChallans(List<DeliveryChallan> challans) {
    if (_searchQuery.isEmpty) return challans;
    final query = _searchQuery.toLowerCase();
    return challans.where((c) {
      return c.challanNumber.toLowerCase().contains(query) ||
          c.customerName.toLowerCase().contains(query) ||
          c.vehicleNumber.toLowerCase().contains(query) ||
          c.driverName.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildChallansList(List<DeliveryChallan> challans) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: challans.length,
      itemBuilder: (context, index) {
        final challan = challans[index];
        return _ChallanCard(
          challan: challan,
          onTap: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => ChallanDetailPage(challan: challan),
              ),
            );
            if (result == true && mounted) {
              final status = _tabStatuses[_tabController.index];
              context
                  .read<ChallansBloc>()
                  .add(LoadChallans(status: status));
            }
          },
          onDelete: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete Challan'),
                content: Text(
                  'Are you sure you want to delete challan ${challan.challanNumber}?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              context.read<ChallansBloc>().add(
                    DeleteChallan(challanId: challan.id),
                  );
            }
          },
        );
      },
    );
  }
}

/// Card widget for a single challan in the list view.
class _ChallanCard extends StatelessWidget {
  final DeliveryChallan challan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChallanCard({
    required this.challan,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor,
          child: Icon(_statusIcon, color: Colors.white),
        ),
        title: Text('Challan #${challan.challanNumber}'),
        subtitle: Text(
          'Customer: ${challan.customerName}\n'
          '${challan.items.length} items · ${challan.vehicleNumber}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color get _statusColor {
    switch (challan.status) {
      case 'dispatched':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData get _statusIcon {
    switch (challan.status) {
      case 'dispatched':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }
}
