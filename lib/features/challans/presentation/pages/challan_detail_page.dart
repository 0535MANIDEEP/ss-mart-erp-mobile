import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/challans_bloc.dart';
import '../../domain/entities/delivery_challan.dart';
import '../../domain/entities/delivery_challan_item.dart';
import '../../../../injection/injection_container.dart';

/// Detail page displaying all information for a delivery challan.
///
/// Shows the challan header (customer, vehicle, driver, status) and a list
/// of all line items with delivery progress. Status action buttons are
/// displayed based on the current status:
/// - **pending**: "Mark as Dispatched" button
/// - **dispatched**: "Mark as Delivered" button
///
/// The page also supports printing/sharing the challan via the app bar menu.
class ChallanDetailPage extends StatelessWidget {
  final DeliveryChallan challan;

  const ChallanDetailPage({super.key, required this.challan});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChallansBloc>(),
      child: _ChallanDetailView(challan: challan),
    );
  }
}

class _ChallanDetailView extends StatelessWidget {
  final DeliveryChallan challan;

  const _ChallanDetailView({required this.challan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Challan #${challan.challanNumber}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'share') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Share functionality coming soon'),
                  ),
                );
              } else if (value == 'print') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Print functionality coming soon'),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'share', child: Text('Share Challan')),
              const PopupMenuItem(value: 'print', child: Text('Print Challan')),
            ],
          ),
        ],
      ),
      body: BlocConsumer<ChallansBloc, ChallansState>(
        listener: (context, state) {
          if (state is ChallanStatusUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Challan status updated to ${state.challan.status.toUpperCase()}',
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          } else if (state is ChallansError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBadge(),
                const SizedBox(height: 16),
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildVehicleCard(),
                const SizedBox(height: 16),
                _buildItemsSection(),
                const SizedBox(height: 16),
                _buildDeliveryProgressCard(),
                const SizedBox(height: 24),
                _buildActionButtons(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    IconData icon;
    switch (challan.status) {
      case 'dispatched':
        color = Colors.blue;
        icon = Icons.local_shipping;
        break;
      case 'delivered':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            challan.status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Challan Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _infoRow(Icons.person, 'Customer', challan.customerName),
            const SizedBox(height: 8),
            _infoRow(Icons.calendar_today, 'Date',
                challan.challanDate.toString().substring(0, 10)),
            const SizedBox(height: 8),
            _infoRow(Icons.tag, 'Challan Number', challan.challanNumber),
            if (challan.salesOrderId != null) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.receipt_long, 'Sales Order', challan.salesOrderId!),
            ],
            const SizedBox(height: 8),
            _infoRow(Icons.inventory_2, 'Items',
                '${challan.items.length} items'),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vehicle & Driver',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _infoRow(Icons.local_shipping, 'Vehicle', challan.vehicleNumber),
            const SizedBox(height: 8),
            _infoRow(Icons.person_outline, 'Driver', challan.driverName),
            const SizedBox(height: 8),
            _infoRow(Icons.phone, 'Phone', challan.driverPhone),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Line Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (challan.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No items in this challan',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...challan.items.map((item) => _itemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(DeliveryChallanItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              _DeliveryStatusChip(item: item),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ordered: ${item.quantity.toInt()} ${item.unit} '
            '· Delivered: ${item.deliveredQuantity.toInt()} ${item.unit}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildDeliveryProgressCard() {
    final total = challan.totalQuantity;
    final delivered = challan.totalDeliveredQuantity;
    final progress = total > 0 ? delivered / total : 0.0;

    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${delivered.toInt()} of ${total.toInt()} items delivered '
              '(${(progress * 100).toInt()}%)',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ChallansState state) {
    if (challan.isPending) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: state is ChallansLoading
              ? null
              : () {
                  context.read<ChallansBloc>().add(
                        UpdateChallanStatus(
                          challanId: challan.id,
                          newStatus: 'dispatched',
                        ),
                      );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: state is ChallansLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.local_shipping),
          label: const Text(
            'Mark as Dispatched',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    if (challan.isDispatched) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: state is ChallansLoading
              ? null
              : () {
                  context.read<ChallansBloc>().add(
                        UpdateChallanStatus(
                          challanId: challan.id,
                          newStatus: 'delivered',
                        ),
                      );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: state is ChallansLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle),
          label: const Text(
            'Mark as Delivered',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chip widget showing delivery status for a single item.
class _DeliveryStatusChip extends StatelessWidget {
  final DeliveryChallanItem item;

  const _DeliveryStatusChip({required this.item});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    if (item.isFullyDelivered) {
      color = Colors.green;
      label = 'Delivered';
    } else if (item.isPartialDelivery) {
      color = Colors.orange;
      label = 'Partial';
    } else {
      color = Colors.grey;
      label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
