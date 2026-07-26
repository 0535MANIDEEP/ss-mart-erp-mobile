import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../bloc/loyalty_bloc.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../../injection/injection_container.dart';

/// Page for manual loyalty points adjustment by administrators.
///
/// Allows searching for a customer, entering a points adjustment (positive
/// to add, negative to deduct), and providing a mandatory reason. Includes
/// a confirmation dialog before processing the adjustment.
///
/// ## Points Adjustment Rules
/// - Positive values add points (earn).
/// - Negative values deduct points (redeem).
/// - Points cannot be deducted below zero.
/// - Reason is required for audit trail purposes.
///
/// ## Validation
/// - Customer must be selected.
/// - Points value must be non-zero.
/// - Reason must not be empty.
///
/// ## Usage
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const LoyaltyAdjustmentPage(),
/// ));
/// ```
class LoyaltyAdjustmentPage extends StatefulWidget {
  const LoyaltyAdjustmentPage({super.key});

  @override
  State<LoyaltyAdjustmentPage> createState() => _LoyaltyAdjustmentPageState();
}

class _LoyaltyAdjustmentPageState extends State<LoyaltyAdjustmentPage> {
  final _pointsController = TextEditingController();
  final _reasonController = TextEditingController();
  final _searchController = TextEditingController();

  Customer? _selectedCustomer;
  bool _isSearching = false;
  List<Customer> _searchResults = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _pointsController.dispose();
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchCustomers(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final customerRepo = GetIt.instance<CustomerRepository>();
      final result = await customerRepo.getCustomers(
        search: query.trim(),
        perPage: 20,
      );

      result.fold(
        (failure) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
            _hasSearched = true;
          });
        },
        (customers) {
          setState(() {
            _searchResults = customers.where((c) => c.isActive).toList();
            _isSearching = false;
            _hasSearched = true;
          });
        },
      );
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasSearched = true;
      });
    }
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _searchResults = [];
      _hasSearched = false;
      _searchController.clear();
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
    });
  }

  bool _validateInputs() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    final points = int.tryParse(_pointsController.text);
    if (points == null || points == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid points value (non-zero)'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    if (points < 0 && _selectedCustomer!.loyaltyPoints + points < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient points. Current balance: ${_selectedCustomer!.loyaltyPoints}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for this adjustment'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  void _showConfirmationDialog() {
    if (!_validateInputs()) return;

    final points = int.parse(_pointsController.text);
    final isAdd = points > 0;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isAdd ? 'Add Points' : 'Deduct Points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_selectedCustomer!.name}'),
            const SizedBox(height: 8),
            Text(
              'Current Balance: ${_selectedCustomer!.loyaltyPoints} points',
            ),
            const SizedBox(height: 8),
            Text(
              'Adjustment: ${isAdd ? '+' : ''}$points points',
              style: TextStyle(
                color: isAdd ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New Balance: ${_selectedCustomer!.loyaltyPoints + points} points',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${_reasonController.text.trim()}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _processAdjustment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: points > 0 ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(points > 0 ? 'Add Points' : 'Deduct Points'),
          ),
        ],
      ),
    );
  }

  void _processAdjustment() {
    final points = int.parse(_pointsController.text);
    final isAdd = points > 0;

    final loyaltyBloc = context.read<LoyaltyBloc>();

    if (isAdd) {
      loyaltyBloc.add(EarnPointsRequested(
        customerId: _selectedCustomer!.id,
        points: points,
        referenceType: 'manual_adjustment',
      ));
    } else {
      loyaltyBloc.add(RedeemPointsRequested(
        customerId: _selectedCustomer!.id,
        points: points.abs(),
        referenceType: 'manual_adjustment',
      ));
    }

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${isAdd ? 'Added' : 'Deducted'} $points points ${isAdd ? 'to' : 'from'} ${_selectedCustomer!.name}',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Reset form
    setState(() {
      _selectedCustomer = null;
      _pointsController.clear();
      _reasonController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty Adjustment'),
        centerTitle: true,
      ),
      body: BlocProvider(
        create: (_) => sl<LoyaltyBloc>(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerSelector(),
              const SizedBox(height: 20),
              _buildPointsInput(),
              const SizedBox(height: 16),
              _buildReasonInput(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the customer search and selection section.
  Widget _buildCustomerSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedCustomer != null)
              _buildSelectedCustomer()
            else
              _buildCustomerSearch(),
          ],
        ),
      ),
    );
  }

  /// Displays the currently selected customer with a clear button.
  Widget _buildSelectedCustomer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green[100],
            child: Text(
              _selectedCustomer!.name.isNotEmpty
                  ? _selectedCustomer!.name[0].toUpperCase()
                  : '?',
              style: TextStyle(color: Colors.green[800]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCustomer!.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  _selectedCustomer!.phone ?? 'No phone',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                Text(
                  'Balance: ${_selectedCustomer!.loyaltyPoints} pts',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _clearCustomer,
            tooltip: 'Clear selection',
          ),
        ],
      ),
    );
  }

  /// Builds the customer search input field.
  Widget _buildCustomerSearch() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name or phone...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                        _hasSearched = false;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onSubmitted: _searchCustomers,
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_isSearching && _hasSearched && _searchResults.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No customers found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        if (_searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final customer = _searchResults[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    radius: 16,
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(customer.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    customer.phone ?? 'No phone',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    '${customer.loyaltyPoints} pts',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  onTap: () => _selectCustomer(customer),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Builds the points input field with +/- buttons.
  Widget _buildPointsInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Points Adjustment',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter points (use - for deduction)',
                prefixIcon: const Icon(Icons.monetization_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixText: 'points',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildQuickButton('+10', 10),
                const SizedBox(width: 8),
                _buildQuickButton('+50', 50),
                const SizedBox(width: 8),
                _buildQuickButton('+100', 100),
                const SizedBox(width: 8),
                _buildQuickButton('-10', -10),
                const SizedBox(width: 8),
                _buildQuickButton('-50', -50),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a quick-select button for common point values.
  Widget _buildQuickButton(String label, int value) {
    final isNegative = value < 0;
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          _pointsController.text = value.toString();
          setState(() {});
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: isNegative ? Colors.red : Colors.green,
          side: BorderSide(
            color: isNegative ? Colors.red[300]! : Colors.green[300]!,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  /// Builds the reason input field (required).
  Widget _buildReasonInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Reason',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for this adjustment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the submit button.
  Widget _buildSubmitButton() {
    final hasInput = _selectedCustomer != null &&
        _pointsController.text.isNotEmpty &&
        _reasonController.text.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: hasInput ? _showConfirmationDialog : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: const Text(
          'Process Adjustment',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
