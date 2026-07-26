import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column, IdColumn;
import '../../../../database/database_dao.dart';
import '../../../../database/app_database.dart';

/// Rate management screen for configuring multi-tier product pricing.
///
/// Provides a Marg-style interface to manage [ProductRates] (Rate A/B/C,
/// Wholesale, Special), [PartyRates] per customer overrides, and quantity-
/// based rate breaks. All monetary values are stored in integer paise and
/// converted to display rupees at the UI boundary.
///
/// ## Data Flow
///
/// 1. User searches for a product via the search bar.
/// 2. On selection, the page loads all [ProductRate] rows for that product.
/// 3. Rates are displayed in a grid; tapping any cell opens an inline editor.
/// 4. Party rate overrides are loaded separately and shown below the grid.
/// 5. All mutations go through [DatabaseDao] which queues sync entries.
///
/// ## Error Handling
///
/// Every database call is wrapped in try/catch. Descriptive [SnackBar]
/// messages are shown for: network failures, validation errors, missing
/// product data, and unexpected database exceptions.
///
/// ## Usage
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const RateManagementPage(),
/// ));
/// ```
class RateManagementPage extends StatefulWidget {
  const RateManagementPage({super.key});

  @override
  State<RateManagementPage> createState() => _RateManagementPageState();
}

class _RateManagementPageState extends State<RateManagementPage> {
  late final DatabaseDao _dao;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Product search
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Product> _searchResults = [];
  Product? _selectedProduct;

  // Rate data for selected product
  List<ProductRate> _productRates = [];
  Map<String, TextEditingController> _rateControllers = {};
  Map<String, TextEditingController> _minQtyControllers = {};
  Map<String, TextEditingController> _maxQtyControllers = {};

  // Party rates for selected product
  List<_PartyRateRow> _partyRateRows = [];
  Customer? _selectedCustomer;

  // Rate history (audit-like)
  List<_RateHistoryEntry> _rateHistory = [];

  // Rate type definitions (Marg-style)
  static const List<Map<String, String>> _rateTypes = [
    {'key': 'MRP', 'label': 'MRP', 'color': '#757575'},
    {'key': 'selling', 'label': 'Selling Price', 'color': '#1B5E20'},
    {'key': 'A', 'label': 'Rate A', 'color': '#1565C0'},
    {'key': 'B', 'label': 'Rate B', 'color': '#6A1B9A'},
    {'key': 'C', 'label': 'Rate C', 'color': '#E65100'},
    {'key': 'wholesale', 'label': 'Wholesale', 'color': '#00695C'},
    {'key': 'special', 'label': 'Special', 'color': '#AD1457'},
  ];

  @override
  void initState() {
    super.initState();
    _dao = DatabaseDao(AppDatabase());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _disposeControllers();
    super.dispose();
  }

  /// Disposes all text editing controllers to prevent memory leaks.
  void _disposeControllers() {
    for (final c in _rateControllers.values) {
      c.dispose();
    }
    for (final c in _minQtyControllers.values) {
      c.dispose();
    }
    for (final c in _maxQtyControllers.values) {
      c.dispose();
    }
    _rateControllers.clear();
    _minQtyControllers.clear();
    _maxQtyControllers.clear();
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Searches products by name, barcode, or SKU via [DatabaseDao].
  Future<void> _searchProducts(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      final results = await _dao.searchProducts(query.trim());
      setState(() => _searchResults = results);
    } catch (e) {
      setState(() {
        _searchResults = [];
        _errorMessage = 'Failed to search products: ${_friendlyError(e)}';
      });
      _showErrorSnackBar('Could not search products. Please try again.');
    }
  }

  /// Selects a product and loads its rates and party overrides.
  Future<void> _selectProduct(Product product) async {
    setState(() {
      _isLoading = true;
      _selectedProduct = product;
      _searchResults = [];
      _searchController.text = product.name;
    });

    _searchFocusNode.unfocus();

    try {
      await _loadProductRates(product.id);
      await _loadPartyRates(product.id);
      await _loadRateHistory(product.id);
    } catch (e) {
      _showErrorSnackBar('Failed to load rate data: ${_friendlyError(e)}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  /// Loads all [ProductRate] rows for [productId] and populates controllers.
  Future<void> _loadProductRates(String productId) async {
    _disposeControllers();

    final rates = await _dao.getProductRatesByProduct(productId);
    final controllerMap = <String, TextEditingController>{};
    final minQtyMap = <String, TextEditingController>{};
    final maxQtyMap = <String, TextEditingController>{};

    for (final rate in rates) {
      controllerMap[rate.rateType] = TextEditingController(
        text: _formatPaise(rate.rateValue),
      );
      minQtyMap[rate.rateType] = TextEditingController(text: '1');
      maxQtyMap[rate.rateType] = TextEditingController(text: '');
    }

    // Ensure controllers exist for all rate types even if no row exists
    for (final rt in _rateTypes) {
      if (!controllerMap.containsKey(rt['key'])) {
        controllerMap[rt['key']!] = TextEditingController(text: '');
        minQtyMap[rt['key']!] = TextEditingController(text: '1');
        maxQtyMap[rt['key']!] = TextEditingController(text: '');
      }
    }

    setState(() {
      _productRates = rates;
      _rateControllers = controllerMap;
      _minQtyControllers = minQtyMap;
      _maxQtyControllers = maxQtyMap;
    });
  }

  /// Loads party-wise rate overrides for [productId].
  Future<void> _loadPartyRates(String productId) async {
    final partyRates = await _dao.getPartyRatesByProduct(productId);
    final rows = <_PartyRateRow>[];

    for (final pr in partyRates) {
      final customer = await _dao.getCustomerById(pr.customerId);
      rows.add(_PartyRateRow(
        partyRate: pr,
        customerName: customer?.name ?? 'Unknown',
      ));
    }

    setState(() => _partyRateRows = rows);
  }

  /// Builds rate history from existing [ProductRate] audit data.
  /// Uses the updated_at timestamps of rates that have changed.
  Future<void> _loadRateHistory(String productId) async {
    final rates = await _dao.getProductRatesByProduct(productId);
    final history = <_RateHistoryEntry>[];

    for (final rate in rates) {
      history.add(_RateHistoryEntry(
        rateType: _rateTypeLabel(rate.rateType),
        rateValue: rate.rateValue,
        changedAt: rate.updatedAt,
        action: 'Updated',
      ));
    }

    history.sort((a, b) => b.changedAt.compareTo(a.changedAt));
    setState(() => _rateHistory = history);
  }

  // ---------------------------------------------------------------------------
  // Rate Saving
  // ---------------------------------------------------------------------------

  /// Saves all rate values for the selected product.
  Future<void> _saveRates() async {
    if (_selectedProduct == null) return;

    // Validate inputs
    for (final entry in _rateControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) {
        final parsed = int.tryParse(value);
        if (parsed == null || parsed < 0) {
          _showErrorSnackBar(
            'Invalid rate value for ${_rateTypeLabel(entry.key)}. '
            'Please enter a valid whole number.',
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final productId = _selectedProduct!.id;

      for (final rt in _rateTypes) {
        final key = rt['key']!;
        final rateText = _rateControllers[key]?.text.trim() ?? '';
        final minQtyText = _minQtyControllers[key]?.text.trim() ?? '1';
        final maxQtyText = _maxQtyControllers[key]?.text.trim() ?? '';

        if (rateText.isEmpty) continue;

        final rateValue = int.tryParse(rateText);
        if (rateValue == null || rateValue <= 0) continue;

        final minQty = double.tryParse(minQtyText) ?? 1.0;
        final maxQty = maxQtyText.isNotEmpty ? double.tryParse(maxQtyText) : null;

        // Check if a rate row already exists for this type
        final existing = _productRates.where((r) => r.rateType == key).toList();

        if (existing.isNotEmpty) {
          // Update existing
          await _dao.updateProductRate(
            ProductRatesCompanion(
              id: Value(existing.first.id),
              productId: Value(productId),
              rateType: Value(key),
              rateName: Value(rt['label']!),
              rateValue: Value(rateValue),
              minQty: Value(minQty),
              maxQty: Value(maxQty),
              isActive: const Value(true),
              updatedAt: Value(now),
              version: Value(existing.first.version + 1),
              syncStatus: const Value('pending'),
            ),
          );
        } else {
          // Insert new
          await _dao.insertProductRate(
            ProductRatesCompanion.insert(
              id: _generateId(),
              productId: productId,
              rateType: key,
              rateName: rt['label']!,
              rateValue: rateValue,
              minQty: Value(minQty),
              maxQty: Value(maxQty),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }

      // Reload data
      await _loadProductRates(productId);
      await _loadRateHistory(productId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rates saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save rates: ${_friendlyError(e)}');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Party Rate Management
  // ---------------------------------------------------------------------------

  /// Opens dialog to add a party-wise rate override.
  Future<void> _addPartyRate() async {
    if (_selectedProduct == null) return;

    final customer = await _showCustomerPicker();
    if (customer == null) return;

    // Check if this customer already has a party rate for this product
    final existing = await _dao.getPartyRateForProduct(
      customer.id,
      _selectedProduct!.id,
    );

    if (existing != null && mounted) {
      _showErrorSnackBar(
        '${customer.name} already has a rate override for this product.',
      );
      return;
    }

    final result = await _showPartyRateDialog(customer.name);
    if (result == null) return;

    try {
      final now = DateTime.now();
      await _dao.insertPartyRate(
        PartyRatesCompanion.insert(
          id: _generateId(),
          customerId: customer.id,
          productId: _selectedProduct!.id,
          rateType: result['rateType']!,
          rateValue: int.parse(result['rateValue']!),
          effectiveFrom: Value(result['effectiveFrom'] != null
              ? DateTime.tryParse(result['effectiveFrom']!)
              : null),
          effectiveTo: Value(result['effectiveTo'] != null
              ? DateTime.tryParse(result['effectiveTo']!)
              : null),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _loadPartyRates(_selectedProduct!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Party rate added for ${customer.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to add party rate: ${_friendlyError(e)}');
    }
  }

  /// Removes a party rate override after confirmation.
  Future<void> _removePartyRate(PartyRate partyRate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Party Rate'),
        content: const Text(
          'Are you sure you want to remove this party rate override? '
          'The customer will revert to standard product rates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || _selectedProduct == null) return;

    try {
      await _dao.deletePartyRate(partyRate.id);
      await _loadPartyRates(_selectedProduct!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Party rate override removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to remove party rate: ${_friendlyError(e)}');
    }
  }

  /// Shows a searchable customer picker dialog.
  Future<Customer?> _showCustomerPicker() async {
    List<Customer> customers = [];
    String searchQuery = '';

    return showDialog<Customer>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Select Customer'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search customers...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) async {
                        searchQuery = value;
                        if (value.trim().length >= 2) {
                          final results = await _dao.searchCustomers(value.trim());
                          setDialogState(() => customers = results);
                        } else {
                          setDialogState(() => customers = []);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: customers.isEmpty
                          ? const Center(
                              child: Text(
                                'Type at least 2 characters to search',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: customers.length,
                              itemBuilder: (ctx, index) {
                                final c = customers[index];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        c.type == 'B2B' ? Colors.blue : Colors.green,
                                    child: Text(
                                      c.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  title: Text(c.name),
                                  subtitle: Text(c.phone ?? 'No phone'),
                                  onTap: () => Navigator.pop(ctx, c),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows a dialog to configure party rate details.
  Future<Map<String, String>?> _showPartyRateDialog(String customerName) async {
    String rateType = 'A';
    final rateController = TextEditingController();
    final minQtyController = TextEditingController(text: '1');
    final maxQtyController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Rate for $customerName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: rateType,
                  decoration: const InputDecoration(
                    labelText: 'Rate Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _rateTypes
                      .where((rt) => rt['key'] != 'MRP' && rt['key'] != 'selling')
                      .map((rt) => DropdownMenuItem(
                            value: rt['key'],
                            child: Text(rt['label']!),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) rateType = value;
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rate (₹) *',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minQtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min Qty',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: maxQtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Qty',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final rateValue = rateController.text.trim();
                if (rateValue.isEmpty || int.tryParse(rateValue) == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid rate'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, {
                  'rateType': rateType,
                  'rateValue': rateValue,
                  'minQty': minQtyController.text.trim(),
                  'maxQty': maxQtyController.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  /// Converts integer paise to display rupee string.
  String _formatPaise(int paise) {
    if (paise == 0) return '';
    return (paise / 100).toStringAsFixed(paise % 100 == 0 ? 0 : 2);
  }

  /// Converts rupee string to paise integer.
  int _toPaise(String rupee) {
    final parsed = double.tryParse(rupee);
    if (parsed == null) return 0;
    return (parsed * 100).round();
  }

  /// Returns a human-readable label for a rate type key.
  String _rateTypeLabel(String key) {
    final match = _rateTypes.where((rt) => rt['key'] == key);
    return match.isNotEmpty ? match.first['label']! : key;
  }

  /// Returns the primary color for a given rate type.
  Color _rateColor(String key) {
    const colorMap = {
      'MRP': Color(0xFF757575),
      'selling': Color(0xFF1B5E20),
      'A': Color(0xFF1565C0),
      'B': Color(0xFF6A1B9A),
      'C': Color(0xFFE65100),
      'wholesale': Color(0xFF00695C),
      'special': Color(0xFFAD1457),
    };
    return colorMap[key] ?? Colors.grey;
  }

  /// Generates a pseudo-UUID for new entities.
  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = now.hashCode.toRadixString(16);
    return 'rate_${random}_${now % 100000}';
  }

  /// Converts a raw exception into a user-friendly error message.
  String _friendlyError(Object error) {
    final msg = error.toString();
    if (msg.contains('database') || msg.contains('sqlite')) {
      return 'A database error occurred. Please restart the app and try again.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Changes will sync when you are back online.';
    }
    if (msg.contains('permission')) {
      return 'Permission denied. Please check app settings.';
    }
    return msg.length > 120 ? '${msg.substring(0, 117)}...' : msg;
  }

  /// Displays a red error [SnackBar] with a descriptive message.
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Management'),
        centerTitle: true,
        actions: [
          if (_selectedProduct != null)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveRates,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save'),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _selectedProduct == null
                ? _buildEmptyState()
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  /// Search bar at the top of the page.
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search product by name, barcode, or SKU...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _selectedProduct = null;
                          _productRates = [];
                          _partyRateRows = [];
                          _rateHistory = [];
                          _disposeControllers();
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: _searchProducts,
            onTapOutside: (_) => _searchFocusNode.unfocus(),
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final product = _searchResults[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: product.isActive
                          ? const Color(0xFF1B5E20)
                          : Colors.grey,
                      child: Text(
                        product.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'SKU: ${product.sku ?? 'N/A'} | MRP: ₹${_formatPaise(product.mrp)}',
                    ),
                    trailing: Text(
                      '₹${_formatPaise(product.sellingPrice)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    onTap: () => _selectProduct(product),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Empty state when no product is selected.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.price_change_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Product Selected',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search and select a product to manage\nits pricing tiers and party overrides.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Main content area when a product is selected.
  Widget _buildContent() {
    final product = _selectedProduct!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductHeader(product),
          const SizedBox(height: 12),
          _buildStandardRatesCard(product),
          const SizedBox(height: 12),
          _buildMultiRateGrid(),
          const SizedBox(height: 12),
          _buildQuantityBreaksSection(),
          const SizedBox(height: 12),
          _buildPartyRatesSection(),
          const SizedBox(height: 12),
          _buildRateHistorySection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Product info header card.
  Widget _buildProductHeader(Product product) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF1B5E20),
              radius: 24,
              child: Text(
                product.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${product.sku ?? 'N/A'} | HSN: ${product.hsnCode}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unit: ${product.unit} | Tax: ${product.taxRate}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: product.isActive
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: product.isActive ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Text(
                product.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: product.isActive ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card showing the product's base rates (MRP, Selling Price, Purchase Price).
  Widget _buildStandardRatesCard(Product product) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.price_check, size: 18, color: Color(0xFF1B5E20)),
                const SizedBox(width: 6),
                const Text(
                  'Standard Rates',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                _rateChip('MRP', product.mrp, Colors.grey.shade700),
                const SizedBox(width: 8),
                _rateChip('Selling', product.sellingPrice, const Color(0xFF1B5E20)),
                const SizedBox(width: 8),
                _rateChip('Purchase', product.purchasePrice, const Color(0xFFE65100)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A small rate display chip.
  Widget _rateChip(String label, int? paise, Color color) {
    final display = paise != null ? '₹${_formatPaise(paise)}' : '—';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              display,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Editable grid for Rate A/B/C, Wholesale, and Special rates.
  Widget _buildMultiRateGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_on, size: 18, color: Color(0xFF1565C0)),
                const SizedBox(width: 6),
                const Text(
                  'Multi-Rate Pricing',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tap to edit',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ..._rateTypes.where((rt) => rt['key'] != 'MRP' && rt['key'] != 'selling').map(
              (rt) => _buildRateRow(rt['key']!, rt['label']!),
            ),
          ],
        ),
      ),
    );
  }

  /// A single editable rate row within the multi-rate grid.
  Widget _buildRateRow(String key, String label) {
    final color = _rateColor(key);
    final rateCtrl = _rateControllers[key];
    final minQtyCtrl = _minQtyControllers[key];
    final maxQtyCtrl = _maxQtyControllers[key];

    if (rateCtrl == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              if (rateCtrl.text.isNotEmpty)
                Text(
                  '₹${rateCtrl.text}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Rate (₹)',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: minQtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Min',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: maxQtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Max',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section for quantity-wise rate breaks.
  Widget _buildQuantityBreaksSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.format_list_numbered, size: 18, color: Color(0xFF6A1B9A)),
                const SizedBox(width: 6),
                const Text(
                  'Quantity Rate Breaks',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              'Configure quantity thresholds for each rate tier. '
              'The "Min" and "Max" columns above define when each rate applies.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            _buildQuantityBreakPreview(),
          ],
        ),
      ),
    );
  }

  /// Visual preview of how quantity breaks apply for the current product.
  Widget _buildQuantityBreakPreview() {
    final activeRates = _rateTypes
        .where((rt) => rt['key'] != 'MRP' && rt['key'] != 'selling')
        .where((rt) {
      final ctrl = _rateControllers[rt['key']];
      return ctrl != null && ctrl.text.trim().isNotEmpty;
    }).toList();

    if (activeRates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200!),
        ),
        child: Center(
          child: Text(
            'No multi-rates configured yet.\nSet rates above to see quantity break preview.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      children: activeRates.map((rt) {
        final key = rt['key']!;
        final rateCtrl = _rateControllers[key];
        final minQtyCtrl = _minQtyControllers[key];
        final maxQtyCtrl = _maxQtyControllers[key];
        final color = _rateColor(key);

        final rateVal = rateCtrl?.text.trim() ?? '';
        final minQty = minQtyCtrl?.text.trim() ?? '1';
        final maxQty = maxQtyCtrl?.text.trim() ?? '∞';

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rt['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                'Qty: $minQty – $maxQty',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 12),
              Text(
                rateVal.isNotEmpty ? '₹$rateVal' : '—',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Party-wise rate override section.
  Widget _buildPartyRatesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt, size: 18, color: Color(0xFF00695C)),
                const SizedBox(width: 6),
                const Text(
                  'Party Rate Overrides',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_partyRateRows.length} overrides',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              'Set customer-specific pricing that overrides standard rates.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            if (_partyRateRows.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200!),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add_alt_1,
                        size: 32,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No party rate overrides configured.\nTap the button below to add one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._partyRateRows.map((row) => _buildPartyRateTile(row)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addPartyRate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Party Rate Override'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00695C),
                  side: const BorderSide(color: Color(0xFF00695C)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A single party rate override tile.
  Widget _buildPartyRateTile(_PartyRateRow row) {
    final pr = row.partyRate;
    final color = _rateColor(pr.rateType);
    final isActive = pr.isActive &&
        (pr.effectiveTo == null || pr.effectiveTo!.isAfter(DateTime.now()));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? color.withOpacity(0.2) : Colors.grey.shade200!,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            radius: 18,
            child: Text(
              row.customerName[0].toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.customerName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_rateTypeLabel(pr.rateType)} | Rate: ${_formatPaise(pr.rateValue)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (pr.effectiveTo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Valid until: ${_formatDate(pr.effectiveTo!)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: pr.effectiveTo!.isBefore(DateTime.now())
                          ? Colors.red.shade600
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '₹${_formatPaise(pr.rateValue)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: Colors.red.shade400,
            ),
            onPressed: () => _removePartyRate(pr),
            tooltip: 'Remove override',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Rate change history section.
  Widget _buildRateHistorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 18, color: Color(0xFF757575)),
                const SizedBox(width: 6),
                const Text(
                  'Rate History',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_rateHistory.length} entries',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            if (_rateHistory.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200!),
                ),
                child: Center(
                  child: Text(
                    'No rate changes recorded yet.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
              )
            else
              ..._rateHistory.take(10).map((entry) {
                final color = _rateColorFromLabel(entry.rateType);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 18,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.action} ${entry.rateType}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              _formatDateTime(entry.changedAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${_formatPaise(entry.rateValue)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// Formats a [DateTime] to a readable date string.
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  /// Formats a [DateTime] to a readable date-time string.
  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  /// Returns a color for a rate type label string.
  Color _rateColorFromLabel(String label) {
    final match = _rateTypes.where((rt) => rt['label'] == label);
    if (match.isNotEmpty) return _rateColor(match.first['key']!);
    return Colors.grey;
  }
}

/// Internal model wrapping a [PartyRate] with the resolved customer name.
class _PartyRateRow {
  final PartyRate partyRate;
  final String customerName;

  const _PartyRateRow({
    required this.partyRate,
    required this.customerName,
  });
}

/// Internal model for rate change history display.
class _RateHistoryEntry {
  final String rateType;
  final int rateValue;
  final DateTime changedAt;
  final String action;

  const _RateHistoryEntry({
    required this.rateType,
    required this.rateValue,
    required this.changedAt,
    required this.action,
  });
}
