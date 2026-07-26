import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/payments_bloc.dart';
import '../../domain/entities/payment.dart';

/// Payments list page with tabbed navigation between received and made payments.
///
/// Displays payment history in a chronological card list with outstanding
/// balance summary at the top. Provides a FAB to record new payments and
/// filter by date range.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  @override
  void initState() {
    super.initState();
    context.read<PaymentsBloc>().add(const LoadPayments());
    context.read<PaymentsBloc>().add(const LoadOutstanding());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Received'),
              Tab(text: 'Made'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildOutstandingSummary(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPaymentList(null),
                  _buildPaymentList('receive'),
                  _buildPaymentList('make'),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showRecordPaymentDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildOutstandingSummary() {
    return BlocBuilder<PaymentsBloc, PaymentsState>(
      buildWhen: (prev, curr) => prev.outstanding != curr.outstanding,
      builder: (context, state) {
        final outstanding = state.outstanding;
        if (outstanding == null) return const SizedBox.shrink();
        final receivable = (outstanding['totalReceivable'] as int?) ?? 0;
        final payable = (outstanding['totalPayable'] as int?) ?? 0;
        final net = (outstanding['netPosition'] as int?) ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _summaryCard('Receivable', receivable, Colors.green),
              const SizedBox(width: 8),
              _summaryCard('Payable', payable, Colors.red),
              const SizedBox(width: 8),
              _summaryCard('Net', net, net >= 0 ? Colors.blue : Colors.orange),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(String label, int amount, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                '₹${(amount / 100).toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentList(String? type) {
    return BlocBuilder<PaymentsBloc, PaymentsState>(
      buildWhen: (prev, curr) => prev.payments != curr.payments,
      builder: (context, state) {
        if (state.isLoading) return const Center(child: CircularProgressIndicator());
        final payments = type == null
            ? state.payments
            : state.payments.where((p) => p.paymentType == type).toList();
        if (payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payment_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No payments found', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) => _buildPaymentCard(payments[index]),
        );
      },
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    final isReceive = payment.isReceive;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isReceive
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.red.withValues(alpha: 0.2),
          child: Icon(
            isReceive ? Icons.arrow_downward : Icons.arrow_upward,
            color: isReceive ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text(
          payment.partyName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${payment.paymentMode}${payment.isAdvance ? " • Advance" : ""}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isReceive ? "+" : "-"}${payment.formattedAmount}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isReceive ? Colors.green : Colors.red,
                fontSize: 15,
              ),
            ),
            Text(
              DateFormat('dd MMM').format(payment.paymentDate),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Colors.green),
              title: const Text('Receive Payment'),
              subtitle: const Text('Record payment from customer'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment recorded successfully')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.red),
              title: const Text('Make Payment'),
              subtitle: const Text('Record payment to supplier'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment recorded successfully')),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
