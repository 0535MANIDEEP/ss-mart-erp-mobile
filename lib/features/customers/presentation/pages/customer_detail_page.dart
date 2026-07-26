import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/customer_entity.dart';
import '../bloc/customer_bloc.dart';
import 'customer_form_page.dart';
import '../../../../injection/injection_container.dart';

/// Read-only detail view for a [Customer].
///
/// Displays all customer fields including loyalty points and credit info,
/// with edit and delete actions via the AppBar and body.
class CustomerDetailPage extends StatefulWidget {
  final String customerId;

  const CustomerDetailPage({super.key, required this.customerId});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  @override
  void initState() {
    super.initState();
    context
        .read<CustomerBloc>()
        .add(LoadCustomerById(customerId: widget.customerId));
  }

  void _confirmDelete(BuildContext context, Customer customer) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete "${customer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<CustomerBloc>().add(
                    DeleteCustomer(customerId: customer.id),
                  );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerBloc>(),
      child: BlocConsumer<CustomerBloc, CustomerState>(
        listener: (context, state) {
          if (state is CustomerOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          } else if (state is CustomerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CustomerLoading) {
            return Scaffold(
              appBar: AppBar(title: const Text('Customer Detail')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (state is CustomerDetailLoaded) {
            final customer = state.customer;
            return _buildDetail(context, customer);
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Customer Detail')),
            body: const Center(child: Text('Customer not found')),
          );
        },
      ),
    );
  }

  Widget _buildDetail(BuildContext context, Customer customer) {
    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute<dynamic>(
                  builder: (_) => CustomerFormPage(customer: customer),
                ),
              );
              if (result == true && mounted) {
                context.read<CustomerBloc>().add(
                      LoadCustomerById(customerId: customer.id),
                    );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, customer),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor:
                    customer.isB2B ? Colors.blue : Colors.green,
                child: Text(
                  customer.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                customer.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: customer.isB2B ? Colors.blue[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: customer.isB2B ? Colors.blue : Colors.green,
                  ),
                ),
                child: Text(
                  customer.type,
                  style: TextStyle(
                    color: customer.isB2B ? Colors.blue : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            _buildInfoTile(Icons.phone, 'Phone', customer.phone ?? 'N/A'),
            _buildInfoTile(Icons.email, 'Email', customer.email ?? 'N/A'),
            _buildInfoTile(
              Icons.home,
              'Address',
              _buildFullAddress(customer),
            ),
            _buildInfoTile(Icons.location_city, 'City', customer.city ?? 'N/A'),
            _buildInfoTile(Icons.map, 'State', customer.state ?? 'N/A'),
            _buildInfoTile(Icons.pin_drop, 'Pincode', customer.pincode ?? 'N/A'),
            _buildInfoTile(
              Icons.receipt_long,
              'GSTIN',
              customer.gstin ?? 'N/A',
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Credit Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ),
            _buildInfoTile(
              Icons.credit_card,
              'Credit Limit',
              '₹${(customer.creditLimit / 100).toStringAsFixed(2)}',
            ),
            _buildInfoTile(
              Icons.account_balance_wallet,
              'Current Balance',
              '₹${(customer.currentBalance / 100).toStringAsFixed(2)}',
            ),
            _buildInfoTile(
              Icons.trending_up,
              'Credit Utilization',
              '${customer.creditUtilization.toStringAsFixed(1)}%',
            ),
            if (customer.hasOutstanding)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Outstanding balance due',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Loyalty',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ),
            _buildInfoTile(
              Icons.stars,
              'Loyalty Points',
              customer.loyaltyPoints.toString(),
            ),
            _buildInfoTile(
              Icons.card_membership,
              'Loyalty Card',
              customer.loyaltyCardNumber ?? 'N/A',
            ),
          ],
        ),
      ),
    );
  }

  String _buildFullAddress(Customer customer) {
    final parts = [
      customer.address,
      customer.city,
      customer.state,
      customer.pincode,
    ].where((p) => p != null && p.isNotEmpty).toList();
    return parts.isEmpty ? 'N/A' : parts.join(', ');
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
