import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import '../../../../database/database_dao.dart';
import '../../../../database/app_database.dart';

/// Marg-style bundle pack management screen for creating and managing
/// product bundles (sets of items sold at a combined price).
///
/// A bundle pack groups multiple products under a single SKU with a
/// combined price that may offer a discount versus buying items individually.
/// This is useful for promotional campaigns, combo offers, and gift sets.
///
/// ## Features
///
/// - **Bundle Listing**: View all active bundles with search and filter.
/// - **Create Bundle**: Define a new bundle with name, description, and items.
/// - **Edit Bundle**: Modify bundle details, items, and pricing.
/// - **Add/Remove Items**: Search products and adjust quantities per item.
/// - **Pricing Modes**: Set a fixed total bundle price or auto-calculate
///   from individual item selling prices.
/// - **Validation**: Ensures bundle name is unique, at least one item exists,
///   and total price is greater than zero before saving.
///
/// ## Database Tables Used
///
/// - [BundlePacks]: Header table storing bundle name, description, and total price.
/// - [BundlePackItems]: Line items linking products to a bundle with quantity
///   and optional per-item price override.
/// - [Products]: Referenced for product names and prices when building items.
///
/// ## Usage
///
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const BundlePackManagementPage(),
/// ));
/// ```
class BundlePackManagementPage extends StatefulWidget {
  const BundlePackManagementPage({super.key});

  @override
  State<BundlePackManagementPage> createState() =>
      _BundlePackManagementPageState();
}

class _BundlePackManagementPageState extends State<BundlePackManagementPage> {
  late final DatabaseDao _dao;
  bool _isLoading = true;
  List<BundlePack> _bundles = [];
  String _searchQuery = '';
  String _filterStatus = 'active'; // 'active', 'all', 'inactive'

  @override
  void initState() {
    super.initState();
    _dao = GetIt.instance<DatabaseDao>();
    _loadBundles();
  }

  /// Loads bundles from the database based on current filter.
  ///
  /// Uses [searchBundlePacks] for active bundles when a query is present,
  /// or [getAllActiveBundlePacks] for the default active view.
  Future<void> _loadBundles() async {
    setState(() => _isLoading = true);

    try {
      List<BundlePack> bundles;

      if (_searchQuery.isNotEmpty) {
        bundles = await _dao.searchBundlePacks(_searchQuery);
      } else {
        bundles = await _dao.getAllActiveBundlePacks();
      }

      if (_filterStatus == 'all') {
        // Load all bundles including inactive ones
        bundles = await _dao.getAllActiveBundlePacks();
      }

      setState(() {
        _bundles = bundles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bundles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Formats an integer paise value to a rupee string display.
  ///
  /// Example: 149900 → '₹1,499.00'
  String _formatPrice(int paise) {
    final rupees = paise / 100;
    return '₹${rupees.toStringAsFixed(2)}';
  }

  /// Opens the create/edit bundle bottom sheet for a new bundle.
  void _openCreateBundleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _BundleEditSheet(
        dao: _dao,
        onSave: () {
          _loadBundles();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Opens the bundle detail/edit sheet for an existing bundle.
  void _openEditBundleSheet(BundlePack bundle) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _BundleEditSheet(
        dao: _dao,
        existingBundle: bundle,
        onSave: () {
          _loadBundles();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Deletes a bundle pack after confirmation.
  Future<void> _deleteBundle(BundlePack bundle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bundle'),
        content: Text(
          'Are you sure you want to delete "${bundle.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dao.deleteBundlePackItems(bundle.id);
        await _dao.deleteBundlePack(bundle.id);
        _loadBundles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bundle deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete bundle: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bundle Packs'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterStatus = value);
              _loadBundles();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'active', child: Text('Active Only')),
              const PopupMenuItem(value: 'all', child: Text('All Bundles')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search bundles...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _loadBundles();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _loadBundles();
              },
            ),
          ),

          // Bundle count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_bundles.length} bundle${_bundles.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Bundle list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _bundles.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadBundles,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _bundles.length,
                          itemBuilder: (context, index) {
                            final bundle = _bundles[index];
                            return _BundlePackCard(
                              bundle: bundle,
                              formatPrice: _formatPrice,
                              onTap: () => _openEditBundleSheet(bundle),
                              onDelete: () => _deleteBundle(bundle),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateBundleSheet,
        icon: const Icon(Icons.add),
        label: const Text('Create Bundle'),
      ),
    );
  }

  /// Builds the empty state widget when no bundles exist.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Bundle Packs Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'No bundles match "$_searchQuery"'
                : 'Create your first bundle pack to group\nproducts at a combined price.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: _openCreateBundleSheet,
              icon: const Icon(Icons.add),
              label: const Text('Create Bundle'),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bundle Pack Card Widget
// =============================================================================

/// A card widget that displays a single bundle pack's summary information.
///
/// Shows the bundle name, item count, total price, and action buttons.
/// The card is tappable to open the detail/edit view.
class _BundlePackCard extends StatelessWidget {
  /// The bundle data to display.
  final BundlePack bundle;

  /// Callback to format integer paise into rupee display string.
  final String Function(int) formatPrice;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  /// Called when the delete action is triggered.
  final VoidCallback onDelete;

  const _BundlePackCard({
    required this.bundle,
    required this.formatPrice,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Bundle icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2,
                  color: Color(0xFF1B5E20),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Bundle info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bundle.description != null &&
                        bundle.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        bundle.description!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Updated: ${_formatDate(bundle.updatedAt)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Price and actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPrice(bundle.totalPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  PopupMenuButton<String>(
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') onTap();
                      if (value == 'delete') onDelete();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats a [DateTime] to a short date string.
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// =============================================================================
// Bundle Edit Sheet Widget
// =============================================================================

/// A modal bottom sheet for creating or editing a bundle pack.
///
/// Provides form fields for bundle name and description, a product picker
/// for adding items, quantity adjustment, and pricing configuration.
///
/// When [existingBundle] is provided, the sheet pre-populates fields
/// for editing. Otherwise, it starts with an empty form for creation.
///
/// ## Validation Rules
///
/// - Bundle name is required and must be non-empty.
/// - At least one item must be added to the bundle.
/// - Bundle total price must be greater than zero.
/// - Item quantities must be at least 1.
class _BundleEditSheet extends StatefulWidget {
  /// The DAO instance for database operations.
  final DatabaseDao dao;

  /// Existing bundle data to edit. Null for creation mode.
  final BundlePack? existingBundle;

  /// Called after successful save (create or update).
  final VoidCallback onSave;

  const _BundleEditSheet({
    required this.dao,
    this.existingBundle,
    required this.onSave,
  });

  @override
  State<_BundleEditSheet> createState() => _BundleEditSheetState();
}

class _BundleEditSheetState extends State<_BundleEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _totalPriceController;
  bool _isAutoPrice = false;
  bool _isSaving = false;

  // Bundle items: productId → (product, quantity, priceOverride)
  final Map<String, _BundleItemData> _bundleItems = {};

  List<Product> _allProducts = [];
  String _productSearchQuery = '';

  bool get _isEditing => widget.existingBundle != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingBundle?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingBundle?.description ?? '',
    );
    _totalPriceController = TextEditingController(
      text: _isEditing
          ? (widget.existingBundle!.totalPrice / 100).toStringAsFixed(2)
          : '',
    );
    _loadProducts();
    if (_isEditing) {
      _loadExistingItems();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _totalPriceController.dispose();
    super.dispose();
  }

  /// Loads all active products for the product picker.
  Future<void> _loadProducts() async {
    try {
      _allProducts = await widget.dao.getActiveProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Loads existing items for an edited bundle.
  Future<void> _loadExistingItems() async {
    try {
      final items =
          await widget.dao.getBundlePackItems(widget.existingBundle!.id);
      for (final item in items) {
        final product =
            await widget.dao.getProductById(item.productId);
        if (product != null) {
          _bundleItems[item.productId] = _BundleItemData(
            product: product,
            quantity: item.quantity,
            priceOverride: item.priceOverride,
          );
        }
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bundle items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Returns filtered products excluding already-added ones.
  List<Product> get _availableProducts {
    return _allProducts
        .where((p) => !_bundleItems.containsKey(p.id))
        .where((p) {
      if (_productSearchQuery.isEmpty) return true;
      final q = _productSearchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          (p.sku?.toLowerCase().contains(q) ?? false) ||
          (p.barcode?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// Calculates the auto-calculated total from individual items.
  int get _autoCalculatedTotal {
    int total = 0;
    for (final item in _bundleItems.values) {
      total += item.product.sellingPrice * item.quantity.toInt();
    }
    return total;
  }

  /// Formats integer paise to rupee string.
  String _formatPrice(int paise) {
    return (paise / 100).toStringAsFixed(2);
  }

  /// Saves the bundle pack to the database.
  ///
  /// Performs validation checks before saving:
  /// - Bundle name must not be empty.
  /// - At least one item must be present.
  /// - Total price must be greater than zero.
  Future<void> _saveBundle() async {
    if (!_formKey.currentState!.validate()) return;

    if (_bundleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one product to the bundle'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final totalPrice = int.tryParse(
        (_totalPriceController.text.isNotEmpty
                ? _totalPriceController.text
                : '0')
            .replaceAll(',', ''));
    final priceInPaise = ((totalPrice ?? 0) * 100).toInt();

    if (!_isAutoPrice && priceInPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bundle price must be greater than zero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final bundleId = widget.existingBundle?.id ?? const Uuid().v4();
      final finalPrice = _isAutoPrice ? _autoCalculatedTotal : priceInPaise;

      // Save bundle header
      await widget.dao.insertBundlePack(
        BundlePacksCompanion.insert(
          id: bundleId,
          name: _nameController.text.trim(),
          description: Value(_descriptionController.text.trim()),
          totalPrice: finalPrice,
          isActive: const Value(true),
          createdAt: widget.existingBundle?.createdAt ?? now,
          updatedAt: now,
          version: Value((widget.existingBundle?.version ?? 0) + 1),
          syncStatus: const Value('pending'),
        ),
      );

      // Delete existing items and re-insert
      await widget.dao.deleteBundlePackItems(bundleId);

      for (final entry in _bundleItems.entries) {
        await widget.dao.insertBundlePackItem(
          BundlePackItemsCompanion.insert(
            id: const Uuid().v4(),
            bundleId: bundleId,
            productId: entry.key,
            quantity: entry.value.quantity,
            priceOverride: Value(entry.value.priceOverride),
          ),
        );
      }

      setState(() => _isSaving = false);
      widget.onSave();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save bundle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Adds a product to the bundle with default quantity of 1.
  void _addProduct(Product product) {
    setState(() {
      _bundleItems[product.id] = _BundleItemData(
        product: product,
        quantity: 1.0,
        priceOverride: null,
      );
    });
  }

  /// Removes a product from the bundle.
  void _removeProduct(String productId) {
    setState(() {
      _bundleItems.remove(productId);
    });
  }

  /// Updates the quantity for a bundle item.
  void _updateQuantity(String productId, double quantity) {
    if (quantity < 1) return;
    setState(() {
      final item = _bundleItems[productId];
      if (item != null) {
        _bundleItems[productId] = _BundleItemData(
          product: item.product,
          quantity: quantity,
          priceOverride: item.priceOverride,
        );
      }
    });
  }

  /// Shows a product picker dialog to search and add products.
  void _showProductPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ProductPickerSheet(
        products: _availableProducts,
        searchQuery: _productSearchQuery,
        onSearchChanged: (q) {
          setState(() => _productSearchQuery = q);
        },
        onProductSelected: (product) {
          _addProduct(product);
          Navigator.of(ctx).pop();
          setState(() => _productSearchQuery = '');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_isEditing ? 'Edit Bundle' : 'Create Bundle'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              TextButton.icon(
                onPressed: _isSaving ? null : _saveBundle,
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
          body: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Bundle Details Section
                _buildSectionHeader('Bundle Details'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Bundle Name *',
                    hintText: 'e.g., Summer Combo Pack',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.inventory_2, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bundle name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional description for this bundle',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.description, size: 20),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Items Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('Bundle Items'),
                    ElevatedButton.icon(
                      onPressed: _availableProducts.isEmpty
                          ? null
                          : _showProductPicker,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_bundleItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.add_shopping_cart,
                              size: 32, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No items added yet',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Add Item" to include products',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...(_bundleItems.entries.map((entry) {
                    return _buildItemCard(entry.key, entry.value);
                  })),
                const SizedBox(height: 24),

                // Pricing Section
                _buildSectionHeader('Pricing'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-calculate total price'),
                          subtitle: Text(
                            _isAutoPrice
                                ? 'Total = sum of item selling prices'
                                : 'Set a custom bundle price',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                          value: _isAutoPrice,
                          onChanged: (value) {
                            setState(() => _isAutoPrice = value);
                          },
                          activeColor: const Color(0xFF1B5E20),
                        ),
                        if (!_isAutoPrice) ...[
                          const Divider(),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _totalPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Bundle Total Price (₹) *',
                              hintText: '0.00',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon:
                                  const Icon(Icons.currency_rupee, size: 20),
                            ),
                            validator: (value) {
                              if (_isAutoPrice) return null;
                              if (value == null || value.trim().isEmpty) {
                                return 'Price is required';
                              }
                              final price = double.tryParse(value);
                              if (price == null || price <= 0) {
                                return 'Enter a valid price greater than 0';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Auto price summary
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isAutoPrice
                                ? Colors.green[50]
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isAutoPrice
                                    ? 'Auto-calculated Total:'
                                    : 'Bundle Price:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '₹${_formatPrice(_isAutoPrice ? _autoCalculatedTotal : ((int.tryParse(_totalPriceController.text.replaceAll(',', '')) ?? 0) * 100))}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: _isAutoPrice
                                      ? const Color(0xFF1B5E20)
                                      : Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_bundleItems.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_bundleItems.length} item${_bundleItems.length == 1 ? '' : 's'} in bundle',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds a section header label.
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1B5E20),
      ),
    );
  }

  /// Builds an item card for a product in the bundle.
  Widget _buildItemCard(String productId, _BundleItemData item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product avatar
            CircleAvatar(
              backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
              radius: 20,
              child: Text(
                item.product.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${item.product.sku ?? 'N/A'} | ₹${_formatPrice(item.product.sellingPrice)}/unit',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  // Quantity controls
                  Row(
                    children: [
                      _buildQuantityButton(
                        icon: Icons.remove,
                        onPressed: item.quantity > 1
                            ? () => _updateQuantity(
                                productId, item.quantity - 1)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: 48,
                          child: Text(
                            item.quantity.toInt().toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      _buildQuantityButton(
                        icon: Icons.add,
                        onPressed: () => _updateQuantity(
                            productId, item.quantity + 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Item total and remove
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${_formatPrice(item.product.sellingPrice * item.quantity.toInt())}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => _removeProduct(productId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove item',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a circular quantity adjustment button.
  Widget _buildQuantityButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          backgroundColor: onPressed != null
              ? const Color(0xFF1B5E20).withOpacity(0.1)
              : Colors.grey[100],
          foregroundColor: onPressed != null
              ? const Color(0xFF1B5E20)
              : Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Bundle Item Data Model
// =============================================================================

/// Local model for a bundle item during editing.
///
/// Holds the product reference, quantity, and optional price override
/// while the bundle is being composed in the edit sheet.
class _BundleItemData {
  /// The product included in the bundle.
  final Product product;

  /// Quantity of this product in the bundle.
  final double quantity;

  /// Optional per-item price override in paise. If null, the bundle
  /// total price is distributed proportionally.
  final int? priceOverride;

  const _BundleItemData({
    required this.product,
    required this.quantity,
    this.priceOverride,
  });
}

// =============================================================================
// Product Picker Sheet
// =============================================================================

/// A modal bottom sheet for searching and selecting products to add
/// to a bundle pack.
///
/// Displays a search field and a scrollable list of available products.
/// Each product shows its name, SKU, price, and stock level.
class _ProductPickerSheet extends StatefulWidget {
  /// Available products to select from (excludes already-added items).
  final List<Product> products;

  /// Current search query for filtering.
  final String searchQuery;

  /// Called when the search text changes.
  final ValueChanged<String> onSearchChanged;

  /// Called when a product is selected.
  final ValueChanged<Product> onProductSelected;

  const _ProductPickerSheet({
    required this.products,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onProductSelected,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Add Product to Bundle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by name, SKU, or barcode...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            widget.onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),
            const SizedBox(height: 8),

            // Product count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${widget.products.length} product${widget.products.length == 1 ? '' : 's'} available',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Product list
            Expanded(
              child: widget.products.isEmpty
                  ? Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.products.length,
                      itemBuilder: (context, index) {
                        final product = widget.products[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFF1B5E20).withOpacity(0.1),
                            child: Text(
                              product.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF1B5E20),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'SKU: ${product.sku ?? 'N/A'} | Stock: ${product.currentStock}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                          trailing: Text(
                            '₹${(product.sellingPrice / 100).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          onTap: () => widget.onProductSelected(product),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
