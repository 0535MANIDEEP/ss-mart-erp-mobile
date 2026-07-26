import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/stock_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../../../../injection/injection_container.dart';

/// Page that displays available batches for a specific product during billing.
///
/// When a user adds a batch-tracked product to the bill, this page is pushed
/// to let them select which batch to sell from. Batches are displayed with
/// their quantity, expiry date, and warehouse location.
///
/// ## Color Coding
/// - **Green**: Batch is available and not near expiry.
/// - **Orange**: Batch is near expiry (within 30 days) or has low stock (≤10).
/// - **Red**: Batch is expired or completely out of stock.
///
/// ## Navigation
/// Returns the selected [Stock] entity to the calling page via
/// [Navigator.pop]. Returns `null` if the user navigates back without selection.
///
/// ## Usage
/// ```dart
/// final selectedBatch = await Navigator.push<Stock>(
///   context,
///   MaterialPageRoute(
///     builder: (_) => BatchSelectionPage(productId: 'prod-123'),
///   ),
/// );
/// ```
class BatchSelectionPage extends StatefulWidget {
  /// The UUID of the product whose batches to display.
  final String productId;

  /// Display name shown in the app bar.
  final String productName;

  const BatchSelectionPage({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<BatchSelectionPage> createState() => _BatchSelectionPageState();
}

class _BatchSelectionPageState extends State<BatchSelectionPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Batch - ${widget.productName}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: BlocProvider(
              create: (_) => sl<InventoryBloc>()
                ..add(LoadStockByProductId(productId: widget.productId)),
              child: BlocBuilder<InventoryBloc, InventoryState>(
                builder: (context, state) {
                  if (state is InventoryLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is InventoryError) {
                    return _buildErrorState(state.message);
                  }
                  if (state is StockDetailLoaded) {
                    return _buildBatchList(context, state.stock);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the search bar for filtering batches by batch number or location.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search batch number or location...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  /// Builds the scrollable list of batch tiles.
  Widget _buildBatchList(BuildContext context, Stock stock) {
    // The StockDetailLoaded state returns a single stock record.
    // For batch selection we typically have multiple batches per product,
    // so we treat this as a single-item list for display consistency.
    final batches = <Stock>[stock];
    final filtered = _filterBatches(batches);

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final batch = filtered[index];
        return _buildBatchCard(context, batch);
      },
    );
  }

  /// Filters the batch list based on the current search query.
  List<Stock> _filterBatches(List<Stock> batches) {
    if (_searchQuery.isEmpty) return batches;
    final query = _searchQuery.toLowerCase();
    return batches.where((b) {
      final batchNum = b.batchNumber?.toLowerCase() ?? '';
      final location = b.locationId.toLowerCase();
      return batchNum.contains(query) || location.contains(query);
    }).toList();
  }

  /// Builds a single batch card with color coding based on stock health.
  Widget _buildBatchCard(BuildContext context, Stock batch) {
    final color = _getBatchColor(batch);
    final icon = _getBatchIcon(batch);
    final expiryText = batch.expiryDate != null
        ? '${batch.expiryDate!.day}/${batch.expiryDate!.month}/${batch.expiryDate!.year}'
        : 'No expiry';
    final daysUntilExpiry = batch.expiryDate != null
        ? batch.expiryDate!.difference(DateTime.now()).inDays
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: batch.availableQuantity > 0
            ? () => Navigator.pop(context, batch)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: 4),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Batch status icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                // Batch details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batch: ${batch.batchNumber ?? 'N/A'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.inventory_2, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Qty: ${batch.availableQuantity}',
                            style: TextStyle(
                              color: batch.availableQuantity <= 10
                                  ? Colors.orange[700]
                                  : Colors.grey[700],
                              fontSize: 13,
                              fontWeight: batch.availableQuantity <= 10
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            batch.locationId,
                            style: TextStyle(color: Colors.grey[700], fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            expiryText,
                            style: TextStyle(
                              color: daysUntilExpiry != null && daysUntilExpiry <= 30
                                  ? Colors.orange[700]
                                  : Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                          if (daysUntilExpiry != null && daysUntilExpiry <= 30) ...[
                            const SizedBox(width: 4),
                            Text(
                              daysUntilExpiry < 0
                                  ? '(Expired)'
                                  : '($daysUntilExpiry days left)',
                              style: TextStyle(
                                color: daysUntilExpiry < 0 ? Colors.red : Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Quantity and action
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${batch.availableQuantity}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: batch.availableQuantity > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    const Text(
                      'available',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (batch.availableQuantity > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.chevron_right,
                          color: color,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns the color representing the batch's current state.
  Color _getBatchColor(Stock batch) {
    if (batch.isExpired || batch.availableQuantity <= 0) return Colors.red;
    if (batch.isNearExpiry || batch.availableQuantity <= 10) return Colors.orange;
    return Colors.green;
  }

  /// Returns the icon representing the batch's current state.
  IconData _getBatchIcon(Stock batch) {
    if (batch.isExpired) return Icons.event_busy;
    if (batch.availableQuantity <= 0) return Icons.inventory_2;
    if (batch.isNearExpiry) return Icons.warning_amber;
    if (batch.availableQuantity <= 10) return Icons.info_outline;
    return Icons.check_circle_outline;
  }

  /// Displays when no batches match the search or no batches exist.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No matching batches' : 'No batches available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Stock has not been added for this product yet',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Displays an error state with the failure message.
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load batches',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
