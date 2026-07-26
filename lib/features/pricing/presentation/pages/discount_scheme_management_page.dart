/// Discount and Scheme Management screen for SS MART ERP.
///
/// Provides a Marg-style interface for creating and managing:
/// - **Discount rules**: percentage, fixed, and buy X get Y discounts
/// - **Promotional schemes**: date-wise, quantity-wise, and combo offers
///
/// The screen uses a tabbed layout with full CRUD operations for both
/// discount rules and scheme rules, backed by the local SQLite database
/// via Drift.
///
/// ## Architecture
///
/// This page directly accesses the [AppDatabase] and [DatabaseDao] layers
/// for data persistence. Each discount/scheme rule is stored in its
/// respective Drift table ([DiscountRules] / [SchemeRules]) and synced
/// to the server via the [SyncQueue].
///
/// ## Validation Rules
///
/// - Rule name is required and must be non-empty.
/// - Discount percentage must be between 0 and 100.
/// - Fixed discount amount must be non-negative.
/// - End date must be after start date when both are provided.
/// - Trigger quantity for Buy X Get Y must be at least 1.
library;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

import '../../../../database/database_dao.dart';
import '../../../../database/app_database.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/confirm_dialog.dart';

/// Top-level page for managing discount rules and promotional schemes.
///
/// Displays two tabs — "Discounts" and "Schemes" — each with a scrollable
/// list and a floating action button for creating new entries. Supports
/// edit and delete via context menu on each list item.
class DiscountSchemeManagementPage extends StatefulWidget {
  const DiscountSchemeManagementPage({super.key});

  @override
  State<DiscountSchemeManagementPage> createState() =>
      _DiscountSchemeManagementPageState();
}

class _DiscountSchemeManagementPageState
    extends State<DiscountSchemeManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final DatabaseDao _dao;

  List<DiscountRule> _discountRules = [];
  List<SchemeRule> _schemeRules = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dao = DatabaseDao(GetIt.instance<AppDatabase>());
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  /// Loads all discount rules and scheme rules from the database.
  ///
  /// Catches database errors and surfaces them as user-friendly messages
  /// in the UI.
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final discounts = await _dao.getAllActiveDiscountRules();
      final schemes = await _dao.getAllActiveSchemeRules();
      setState(() {
        _discountRules = discounts;
        _schemeRules = schemes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data. Please try again.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Delete Operations
  // ---------------------------------------------------------------------------

  /// Soft-deletes a discount rule by setting [DiscountRules.isActive] to false.
  ///
  /// Prompts the user with a confirmation dialog before proceeding.
  Future<void> _deleteDiscountRule(DiscountRule rule) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Discount Rule',
      message:
          'Are you sure you want to delete "${rule.ruleName}"? '
          'This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (!confirmed) return;

    try {
      await _dao.updateDiscountRule(
        DiscountRulesCompanion(
          id: Value(rule.id),
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
      _showSnackBar('Discount rule deleted');
      _loadData();
    } catch (e) {
      _showSnackBar('Failed to delete discount rule', isError: true);
    }
  }

  /// Soft-deletes a scheme rule by setting [SchemeRules.isActive] to false.
  Future<void> _deleteSchemeRule(SchemeRule rule) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Scheme',
      message:
          'Are you sure you want to delete "${rule.schemeName}"? '
          'This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (!confirmed) return;

    try {
      await _dao.updateSchemeRule(
        SchemeRulesCompanion(
          id: Value(rule.id),
          isActive: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
      _showSnackBar('Scheme deleted');
      _loadData();
    } catch (e) {
      _showSnackBar('Failed to delete scheme', isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // UI Helpers
  // ---------------------------------------------------------------------------

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
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
        title: const Text('Discounts & Schemes'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Discounts', icon: Icon(Icons.discount_outlined)),
            Tab(text: 'Schemes', icon: Icon(Icons.local_offer_outlined)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDiscountsTab(),
                    _buildSchemesTab(),
                  ],
                ),
      floatingActionButton: _buildFab(),
    );
  }

  /// Builds the FAB that creates the entry type matching the active tab.
  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: () {
        if (_tabController.index == 0) {
          _showDiscountRuleDialog();
        } else {
          _showSchemeRuleDialog();
        }
      },
      child: const Icon(Icons.add),
    );
  }

  /// Displays a retry-enabled error view when data loading fails.
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Discounts Tab
  // ===========================================================================

  Widget _buildDiscountsTab() {
    if (_discountRules.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.discount_outlined,
        title: 'No Discount Rules',
        subtitle: 'Create discount rules to apply percentage, fixed, '
            'or buy X get Y discounts.',
        actionText: 'Create Rule',
        onAction: () => _showDiscountRuleDialog(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        itemCount: _discountRules.length,
        itemBuilder: (context, index) =>
            _buildDiscountRuleCard(_discountRules[index]),
      ),
    );
  }

  /// Renders a single discount rule card with type chip, value, scope,
  /// and context menu.
  Widget _buildDiscountRuleCard(DiscountRule rule) {
    final typeInfo = _discountTypeInfo(rule.discountType);
    final isActive = _isRuleDateActive(rule.startDate, rule.endDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeInfo.$2.withValues(alpha: 0.15),
          child: Icon(typeInfo.$3, color: typeInfo.$2, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                rule.ruleName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: typeInfo.$2.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                typeInfo.$1,
                style: TextStyle(
                  fontSize: 11,
                  color: typeInfo.$2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _discountValueText(rule),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _discountScopeText(rule),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (!isActive)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Expired / Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _showDiscountRuleDialog(rule: rule);
            if (value == 'delete') _deleteDiscountRule(rule);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Schemes Tab
  // ===========================================================================

  Widget _buildSchemesTab() {
    if (_schemeRules.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.local_offer_outlined,
        title: 'No Promotional Schemes',
        subtitle: 'Create schemes like Buy X Get Y, quantity rate, '
            'date-wise, or combo offers.',
        actionText: 'Create Scheme',
        onAction: () => _showSchemeRuleDialog(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        itemCount: _schemeRules.length,
        itemBuilder: (context, index) =>
            _buildSchemeRuleCard(_schemeRules[index]),
      ),
    );
  }

  /// Renders a single scheme rule card with type badge, trigger info,
  /// validity, and context menu.
  Widget _buildSchemeRuleCard(SchemeRule rule) {
    final typeInfo = _schemeTypeInfo(rule.schemeType);
    final isActive = _isRuleDateActive(rule.startDate, rule.endDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeInfo.$2.withValues(alpha: 0.15),
          child: Icon(typeInfo.$3, color: typeInfo.$2, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                rule.schemeName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: typeInfo.$2.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                typeInfo.$1,
                style: TextStyle(
                  fontSize: 11,
                  color: typeInfo.$2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _schemeBenefitText(rule),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _schemeValidityText(rule),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (!isActive)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Expired / Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _showSchemeRuleDialog(rule: rule);
            if (value == 'delete') _deleteSchemeRule(rule);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Discount Rule Form Dialog
  // ===========================================================================

  /// Shows a full-screen bottom-sheet form for creating or editing a
  /// [DiscountRules] entry.
  ///
  /// Validates all fields before saving. For new rules, inserts with a
  /// fresh UUID. For edits, updates the existing row.
  void _showDiscountRuleDialog({DiscountRule? rule}) {
    final isEdit = rule != null;
    final formKey = GlobalKey<FormState>();

    final nameController =
        TextEditingController(text: rule?.ruleName ?? '');
    String discountType = rule?.discountType ?? 'percentage';
    final discountValueController = TextEditingController(
      text: rule != null ? rule.discountValue.toString() : '',
    );
    String appliesTo = rule?.appliesTo ?? 'item';
    final minQtyController = TextEditingController(
      text: rule?.minQty?.toString() ?? '',
    );
    final minAmountController = TextEditingController(
      text: rule?.minAmount?.toString() ?? '',
    );
    DateTime? startDate = rule?.startDate;
    DateTime? endDate = rule?.endDate;
    final priorityController = TextEditingController(
      text: rule?.priority.toString() ?? '0',
    );

    // For buy_x_get_y: stored in minQty and discountValue
    final buyQtyController = TextEditingController(
      text: rule?.minQty?.toString() ?? '',
    );
    final getQtyController = TextEditingController(
      text: rule?.discountValue.toString() ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        isEdit ? 'Edit Discount Rule' : 'New Discount Rule',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),

                      // Rule Name
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Rule Name *',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Discount Type
                      DropdownButtonFormField<String>(
                        value: discountType,
                        decoration: const InputDecoration(
                          labelText: 'Discount Type *',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Percentage (%)'),
                          ),
                          DropdownMenuItem(
                            value: 'fixed',
                            child: Text('Fixed Amount (\u20B9)'),
                          ),
                          DropdownMenuItem(
                            value: 'buy_x_get_y',
                            child: Text('Buy X Get Y'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => discountType = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Discount Value or Buy X Get Y fields
                      if (discountType == 'buy_x_get_y') ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: buyQtyController,
                                decoration: const InputDecoration(
                                  labelText: 'Buy Qty (X) *',
                                  prefixIcon: Icon(Icons.shopping_cart_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final n = int.tryParse(v.trim());
                                  if (n == null || n < 1) return 'Min 1';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: getQtyController,
                                decoration: const InputDecoration(
                                  labelText: 'Get Qty (Y) *',
                                  prefixIcon:
                                      Icon(Icons.card_giftcard_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  final n = int.tryParse(v.trim());
                                  if (n == null || n < 1) return 'Min 1';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ] else
                        TextFormField(
                          controller: discountValueController,
                          decoration: InputDecoration(
                            labelText: discountType == 'percentage'
                                ? 'Percentage (0-100) *'
                                : 'Amount (\u20B9) *',
                            prefixIcon: const Icon(Icons.percent_outlined),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            final num = double.tryParse(v.trim());
                            if (num == null || num < 0) return 'Invalid value';
                            if (discountType == 'percentage' &&
                                (num < 0 || num > 100)) {
                              return 'Must be 0-100';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 12),

                      // Applies To
                      DropdownButtonFormField<String>(
                        value: appliesTo,
                        decoration: const InputDecoration(
                          labelText: 'Applies To *',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'item', child: Text('Item')),
                          DropdownMenuItem(value: 'bill', child: Text('Bill')),
                          DropdownMenuItem(
                            value: 'category',
                            child: Text('Category'),
                          ),
                          DropdownMenuItem(
                            value: 'product',
                            child: Text('Product'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => appliesTo = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Min Qty and Min Amount
                      if (discountType != 'buy_x_get_y')
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: minQtyController,
                                decoration: const InputDecoration(
                                  labelText: 'Min Qty',
                                  prefixIcon: Icon(Icons.numbers),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: minAmountController,
                                decoration: const InputDecoration(
                                  labelText: 'Min Amount (\u20B9)',
                                  prefixIcon:
                                      Icon(Icons.currency_rupee_outlined),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),

                      // Priority
                      TextFormField(
                        controller: priorityController,
                        decoration: const InputDecoration(
                          labelText: 'Priority (higher = preferred)',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      // Date Range
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              label: 'Start Date',
                              date: startDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: startDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setSheetState(() => startDate = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(
                              label: 'End Date',
                              date: endDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: endDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setSheetState(() => endDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;

                                // Validate date range
                                if (startDate != null &&
                                    endDate != null &&
                                    endDate!.isBefore(startDate!)) {
                                  _showSnackBar(
                                    'End date must be after start date',
                                    isError: true,
                                  );
                                  return;
                                }

                                final id = isEdit ? rule.id : const Uuid().v4();
                                final now = DateTime.now();

                                // For buy_x_get_y, minQty = buy qty,
                                // discountValue = get qty
                                final double discValue;
                                final double? minQtyVal;
                                if (discountType == 'buy_x_get_y') {
                                  minQtyVal = double.tryParse(
                                      buyQtyController.text.trim());
                                  discValue = double.tryParse(
                                          getQtyController.text.trim()) ??
                                      0;
                                } else {
                                  discValue = double.tryParse(
                                          discountValueController.text
                                              .trim()) ??
                                      0;
                                  minQtyVal = double.tryParse(
                                      minQtyController.text.trim());
                                }

                                final entry = DiscountRulesCompanion(
                                  id: Value(id),
                                  ruleName: Value(nameController.text.trim()),
                                  discountType: Value(discountType),
                                  discountValue: Value(discValue),
                                  appliesTo: Value(appliesTo),
                                  minQty: Value(minQtyVal),
                                  minAmount: Value(
                                    int.tryParse(
                                        minAmountController.text.trim()),
                                  ),
                                  startDate: Value(startDate),
                                  endDate: Value(endDate),
                                  priority: Value(
                                    int.tryParse(
                                            priorityController.text.trim()) ??
                                        0,
                                  ),
                                  isActive: const Value(true),
                                  createdAt:
                                      Value(isEdit ? rule.createdAt : now),
                                  updatedAt: Value(now),
                                );

                                try {
                                  if (isEdit) {
                                    await _dao.updateDiscountRule(entry);
                                  } else {
                                    await _dao.insertDiscountRule(entry);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _showSnackBar(
                                    isEdit
                                        ? 'Discount rule updated'
                                        : 'Discount rule created',
                                  );
                                  _loadData();
                                } catch (e) {
                                  _showSnackBar(
                                    'Failed to save discount rule',
                                    isError: true,
                                  );
                                }
                              },
                              child: Text(isEdit ? 'Update' : 'Create'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // Scheme Rule Form Dialog
  // ===========================================================================

  /// Shows a full-screen bottom-sheet form for creating or editing a
  /// [SchemeRules] entry.
  ///
  /// Adapts the visible form fields based on the selected scheme type.
  void _showSchemeRuleDialog({SchemeRule? rule}) {
    final isEdit = rule != null;
    final formKey = GlobalKey<FormState>();

    final nameController =
        TextEditingController(text: rule?.schemeName ?? '');
    String schemeType = rule?.schemeType ?? 'buy_x_get_y';
    final triggerQtyController = TextEditingController(
      text: rule?.triggerQty.toString() ?? '',
    );
    final freeQtyController = TextEditingController(
      text: rule?.freeQty.toString() ?? '',
    );
    final discountPercentController = TextEditingController(
      text: rule?.discountPercent.toString() ?? '',
    );
    final discountAmountController = TextEditingController(
      text: rule?.discountAmount.toString() ?? '',
    );
    String appliesTo = rule?.appliesTo ?? 'product';
    DateTime? startDate = rule?.startDate;
    DateTime? endDate = rule?.endDate;
    final priorityController = TextEditingController(
      text: rule?.priority.toString() ?? '0',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final showQtyFields =
                schemeType == 'buy_x_get_y' || schemeType == 'quantity_rate';
            final showDiscountFields =
                schemeType == 'quantity_rate' || schemeType == 'date_wise';

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        isEdit ? 'Edit Scheme' : 'New Scheme',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),

                      // Scheme Name
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Scheme Name *',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Scheme Type
                      DropdownButtonFormField<String>(
                        value: schemeType,
                        decoration: const InputDecoration(
                          labelText: 'Scheme Type *',
                          prefixIcon: Icon(Icons.local_offer_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'buy_x_get_y',
                            child: Text('Buy X Get Y'),
                          ),
                          DropdownMenuItem(
                            value: 'quantity_rate',
                            child: Text('Quantity Rate'),
                          ),
                          DropdownMenuItem(
                            value: 'date_wise',
                            child: Text('Date-wise Discount'),
                          ),
                          DropdownMenuItem(
                            value: 'combo',
                            child: Text('Combo'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => schemeType = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Trigger Qty (buy_x_get_y, quantity_rate)
                      if (showQtyFields)
                        TextFormField(
                          controller: triggerQtyController,
                          decoration: const InputDecoration(
                            labelText: 'Trigger Quantity *',
                            prefixIcon: Icon(Icons.shopping_cart_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            final n = double.tryParse(v.trim());
                            if (n == null || n < 1) return 'Min 1';
                            return null;
                          },
                        ),

                      // Free Qty (buy_x_get_y)
                      if (schemeType == 'buy_x_get_y') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: freeQtyController,
                          decoration: const InputDecoration(
                            labelText: 'Free Quantity *',
                            prefixIcon: Icon(Icons.card_giftcard_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            final n = double.tryParse(v.trim());
                            if (n == null || n < 1) return 'Min 1';
                            return null;
                          },
                        ),
                      ],

                      // Discount Percent / Amount (quantity_rate, date_wise)
                      if (showDiscountFields) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: discountPercentController,
                                decoration: const InputDecoration(
                                  labelText: 'Discount %',
                                  prefixIcon: Icon(Icons.percent_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    if (discountAmountController
                                        .text.trim().isEmpty) {
                                      return 'Fill one';
                                    }
                                    return null;
                                  }
                                  final n = double.tryParse(v.trim());
                                  if (n == null || n < 0 || n > 100) {
                                    return '0-100';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: discountAmountController,
                                decoration: const InputDecoration(
                                  labelText: 'Amount (\u20B9)',
                                  prefixIcon:
                                      Icon(Icons.currency_rupee_outlined),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Applies To
                      DropdownButtonFormField<String>(
                        value: appliesTo,
                        decoration: const InputDecoration(
                          labelText: 'Applies To *',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Products'),
                          ),
                          DropdownMenuItem(
                            value: 'product',
                            child: Text('Specific Product'),
                          ),
                          DropdownMenuItem(
                            value: 'category',
                            child: Text('Category'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => appliesTo = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Priority
                      TextFormField(
                        controller: priorityController,
                        decoration: const InputDecoration(
                          labelText: 'Priority (higher = preferred)',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),

                      // Date Range
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              label: 'Start Date',
                              date: startDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: startDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setSheetState(() => startDate = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(
                              label: 'End Date',
                              date: endDate,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: endDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setSheetState(() => endDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;

                                if (startDate != null &&
                                    endDate != null &&
                                    endDate!.isBefore(startDate!)) {
                                  _showSnackBar(
                                    'End date must be after start date',
                                    isError: true,
                                  );
                                  return;
                                }

                                final id = isEdit ? rule.id : const Uuid().v4();
                                final now = DateTime.now();

                                final entry = SchemeRulesCompanion(
                                  id: Value(id),
                                  schemeName:
                                      Value(nameController.text.trim()),
                                  schemeType: Value(schemeType),
                                  triggerQty: Value(
                                    double.tryParse(
                                            triggerQtyController
                                                .text.trim()) ??
                                        0,
                                  ),
                                  freeQty: Value(
                                    double.tryParse(
                                            freeQtyController.text.trim()) ??
                                        0,
                                  ),
                                  discountPercent: Value(
                                    double.tryParse(
                                            discountPercentController
                                                .text.trim()) ??
                                        0,
                                  ),
                                  discountAmount: Value(
                                    int.tryParse(
                                            discountAmountController
                                                .text.trim()) ??
                                        0,
                                  ),
                                  appliesTo: Value(appliesTo),
                                  startDate: Value(startDate),
                                  endDate: Value(endDate),
                                  priority: Value(
                                    int.tryParse(
                                            priorityController.text.trim()) ??
                                        0,
                                  ),
                                  isActive: const Value(true),
                                  createdAt:
                                      Value(isEdit ? rule.createdAt : now),
                                  updatedAt: Value(now),
                                );

                                try {
                                  if (isEdit) {
                                    await _dao.updateSchemeRule(entry);
                                  } else {
                                    await _dao.insertSchemeRule(entry);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _showSnackBar(
                                    isEdit
                                        ? 'Scheme updated'
                                        : 'Scheme created',
                                  );
                                  _loadData();
                                } catch (e) {
                                  _showSnackBar(
                                    'Failed to save scheme',
                                    isError: true,
                                  );
                                }
                              },
                              child: Text(isEdit ? 'Update' : 'Create'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // Shared Helpers
  // ===========================================================================

  /// Builds a tappable date display field.
  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(
          date != null
              ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
              : 'Not set',
          style: TextStyle(
            color: date != null ? null : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  /// Returns (label, color, icon) for a discount type.
  (String, Color, IconData) _discountTypeInfo(String type) {
    switch (type) {
      case 'percentage':
        return ('%', Colors.blue, Icons.percent_outlined);
      case 'fixed':
        return ('Fixed', Colors.green, Icons.currency_rupee_outlined);
      case 'buy_x_get_y':
        return ('B2GY', Colors.orange, Icons.card_giftcard_outlined);
      default:
        return ('Other', Colors.grey, Icons.discount_outlined);
    }
  }

  /// Returns (label, color, icon) for a scheme type.
  (String, Color, IconData) _schemeTypeInfo(String type) {
    switch (type) {
      case 'buy_x_get_y':
        return ('B2GY', Colors.orange, Icons.card_giftcard_outlined);
      case 'quantity_rate':
        return ('Qty Rate', Colors.blue, Icons.trending_down_outlined);
      case 'date_wise':
        return ('Date', Colors.purple, Icons.date_range_outlined);
      case 'combo':
        return ('Combo', Colors.teal, Icons.merge_type_outlined);
      default:
        return ('Other', Colors.grey, Icons.local_offer_outlined);
    }
  }

  /// Formats the discount value as a readable string.
  String _discountValueText(DiscountRule rule) {
    switch (rule.discountType) {
      case 'percentage':
        return '${rule.discountValue.toStringAsFixed(1)}% off';
      case 'fixed':
        return '\u20B9${rule.discountValue.toStringAsFixed(0)} off';
      case 'buy_x_get_y':
        // minQty = buy qty, discountValue = get qty
        return 'Buy ${rule.minQty?.toStringAsFixed(0) ?? '?'} '
            'Get ${rule.discountValue.toStringAsFixed(0)} Free';
      default:
        return '${rule.discountValue}';
    }
  }

  /// Returns a human-readable scope string.
  String _discountScopeText(DiscountRule rule) {
    final scope =
        rule.appliesTo[0].toUpperCase() + rule.appliesTo.substring(1);
    final parts = <String>['Scope: $scope'];
    if (rule.minQty != null && rule.discountType != 'buy_x_get_y') {
      parts.add('Min qty: ${rule.minQty}');
    }
    if (rule.minAmount != null) {
      parts.add('Min \u20B9${rule.minAmount}');
    }
    if (rule.priority > 0) parts.add('Priority: ${rule.priority}');
    return parts.join(' \u2022 ');
  }

  /// Returns the benefit description for a scheme rule.
  String _schemeBenefitText(SchemeRule rule) {
    switch (rule.schemeType) {
      case 'buy_x_get_y':
        return 'Buy ${rule.triggerQty.toStringAsFixed(0)} '
            'Get ${rule.freeQty.toStringAsFixed(0)} Free';
      case 'quantity_rate':
        if (rule.discountPercent > 0) {
          return '${rule.discountPercent.toStringAsFixed(1)}% off '
              'on qty \u2265 ${rule.triggerQty.toStringAsFixed(0)}';
        }
        return '\u20B9${rule.discountAmount} off per unit '
            'on qty \u2265 ${rule.triggerQty.toStringAsFixed(0)}';
      case 'date_wise':
        if (rule.discountPercent > 0) {
          return '${rule.discountPercent.toStringAsFixed(1)}% seasonal discount';
        }
        return '\u20B9${rule.discountAmount} off per unit (seasonal)';
      case 'combo':
        return 'Combo offer';
      default:
        return 'Promotional scheme';
    }
  }

  /// Returns the validity date range text.
  String _schemeValidityText(SchemeRule rule) {
    final parts = <String>[];
    parts.add('Priority: ${rule.priority}');
    if (rule.startDate != null || rule.endDate != null) {
      final start = rule.startDate != null
          ? '${rule.startDate!.year}-'
              '${rule.startDate!.month.toString().padLeft(2, '0')}-'
              '${rule.startDate!.day.toString().padLeft(2, '0')}'
          : '---';
      final end = rule.endDate != null
          ? '${rule.endDate!.year}-'
              '${rule.endDate!.month.toString().padLeft(2, '0')}-'
              '${rule.endDate!.day.toString().padLeft(2, '0')}'
          : '---';
      parts.add('$start to $end');
    } else {
      parts.add('No expiry');
    }
    return parts.join(' \u2022 ');
  }

  /// Checks if a rule is currently within its valid date range.
  bool _isRuleDateActive(DateTime? start, DateTime? end) {
    final now = DateTime.now();
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }
}
