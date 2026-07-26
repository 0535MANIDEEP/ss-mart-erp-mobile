import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/stock_entity.dart';
import '../bloc/inventory_bloc.dart';
import '../../../../injection/injection_container.dart';

/// Page displaying products approaching expiry or already expired.
///
/// Shows a filterable list of stock items sorted by urgency (most urgent first).
/// Includes a summary card at the top with counts for each category.
///
/// ## Filter Tabs
/// - **All**: All products with expiry tracking enabled.
/// - **Near Expiry**: Products expiring within 30 days.
/// - **Expired**: Products past their expiry date.
///
/// ## Color Coding
/// - **Red**: Expired products.
/// - **Orange**: Near-expiry products (≤30 days remaining).
/// - **Green**: Products with sufficient time before expiry.
///
/// ## Usage
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const ExpiryAlertPage(),
/// ));
/// ```
class ExpiryAlertPage extends StatefulWidget {
  const ExpiryAlertPage({super.key});

  @override
  State<ExpiryAlertPage> createState() => _ExpiryAlertPageState();
}

class _ExpiryAlertPageState extends State<ExpiryAlertPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Stock> _allStock = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExpiryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExpiryData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bloc = sl<InventoryBloc>();
      bloc.add(const LoadStock());
      // Listen to state changes to capture loaded data
      final subscription = bloc.stream.listen((state) {
        if (state is InventoryLoaded) {
          setState(() {
            _allStock = state.stock.where((s) => s.expiryDate != null).toList();
            _isLoading = false;
          });
        } else if (state is InventoryError) {
          setState(() {
            _error = state.message;
            _isLoading = false;
          });
        }
      });
      // Cancel subscription after initial load completes
      Future.delayed(const Duration(seconds: 5), () => subscription.cancel());
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Stock> get _expiredItems =>
      _allStock.where((s) => s.isExpired).toList()
        ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

  List<Stock> get _nearExpiryItems =>
      _allStock.where((s) => !s.isExpired && s.isNearExpiry).toList()
        ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

  List<Stock> get _safeItems =>
      _allStock.where((s) => !s.isExpired && !s.isNearExpiry).toList()
        ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

  List<Stock> get _currentItems {
    switch (_tabController.index) {
      case 0:
        return _allStock;
      case 1:
        return [..._nearExpiryItems, ..._expiredItems];
      case 2:
        return _expiredItems;
      default:
        return _allStock;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiry Alerts'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: [
            Tab(text: 'All (${_allStock.length})'),
            Tab(text: 'Near Expiry (${_nearExpiryItems.length})'),
            Tab(text: 'Expired (${_expiredItems.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : Column(
                  children: [
                    _buildSummaryCard(),
                    Expanded(
                      child: _currentItems.isEmpty
                          ? _buildEmptyState()
                          : _buildExpiryList(),
                    ),
                  ],
                ),
    );
  }

  /// Builds the summary card showing counts by urgency category.
  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[700]!, Colors.orange[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(
              'Expired',
              '${_expiredItems.length}',
              Icons.event_busy,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white30,
            ),
            _buildSummaryItem(
              'Near Expiry',
              '${_nearExpiryItems.length}',
              Icons.warning_amber,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white30,
            ),
            _buildSummaryItem(
              'Total',
              '${_allStock.length}',
              Icons.inventory_2,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single summary statistic column inside the summary card.
  Widget _buildSummaryItem(String label, String count, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  /// Builds the scrollable list of expiry items.
  Widget _buildExpiryList() {
    return RefreshIndicator(
      onRefresh: _loadExpiryData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _currentItems.length,
        itemBuilder: (context, index) {
          final stock = _currentItems[index];
          return _buildExpiryCard(stock);
        },
      ),
    );
  }

  /// Builds a single expiry item card with color-coded urgency indicator.
  Widget _buildExpiryCard(Stock stock) {
    final daysRemaining = stock.expiryDate!.difference(DateTime.now()).inDays;
    final isExpired = stock.isExpired;
    final color = isExpired
        ? Colors.red
        : stock.isNearExpiry
            ? Colors.orange
            : Colors.green;

    final expiryText =
        '${stock.expiryDate!.day}/${stock.expiryDate!.month}/${stock.expiryDate!.year}';
    final daysText = isExpired
        ? 'Expired ${-daysRemaining} days ago'
        : daysRemaining == 0
            ? 'Expires today'
            : '$daysRemaining days remaining';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
              // Urgency icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isExpired ? Icons.event_busy : Icons.warning_amber,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Batch: ${stock.batchNumber ?? 'N/A'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Qty: ${stock.availableQuantity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: stock.availableQuantity <= 10
                                ? Colors.orange[700]
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Exp: $expiryText',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Days remaining badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  daysText,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Empty state when no products match the current filter.
  Widget _buildEmptyState() {
    final message = _tabController.index == 0
        ? 'No products with expiry tracking'
        : _tabController.index == 1
            ? 'No products near expiry'
            : 'No expired products';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All products are within safe expiry range',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Error state widget when data loading fails.
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load expiry data',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadExpiryData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
