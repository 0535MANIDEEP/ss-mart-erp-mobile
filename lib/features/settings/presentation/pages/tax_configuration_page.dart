import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';
import '../../../../database/database_dao.dart';
import 'package:get_it/get_it.dart';

/// Page for configuring tax rates and GST settings.
///
/// Manages the application's tax configuration stored in the [AppSettings]
/// table. Supports setting a default GST rate, configuring HSN-wise tax
/// mappings, and viewing tax rate presets.
///
/// ## Settings Stored
/// - `tax_default_rate`: The default GST rate applied to new products.
/// - `tax_hsn_mapping`: JSON map of HSN codes to tax rates (simplified).
/// - `tax_include_in_price`: Whether tax is included in displayed prices.
///
/// ## Supported GST Rates (India)
/// - 0% (exempt goods)
/// - 5% (essential items)
/// - 12% (processed food, computers)
/// - 18% (most goods and services)
/// - 28% (luxury items, automobiles)
///
/// ## Usage
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const TaxConfigurationPage(),
/// ));
/// ```
class TaxConfigurationPage extends StatefulWidget {
  const TaxConfigurationPage({super.key});

  @override
  State<TaxConfigurationPage> createState() => _TaxConfigurationPageState();
}

class _TaxConfigurationPageState extends State<TaxConfigurationPage> {
  late final DatabaseDao _dao;
  bool _isLoading = true;
  bool _isSaving = false;

  // Current settings
  double _defaultTaxRate = 18.0;
  bool _taxIncludedInPrice = false;
  Map<String, double> _hsnTaxMapping = {};

  // HSN mapping controllers
  final _hsnController = TextEditingController();
  final _hsnRateController = TextEditingController();

  static const List<double> _presetRates = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    _dao = GetIt.instance<DatabaseDao>();
    _loadSettings();
  }

  @override
  void dispose() {
    _hsnController.dispose();
    _hsnRateController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final defaultRate = await _dao.getSettingValue('tax_default_rate');
      final taxIncluded = await _dao.getSettingValue('tax_include_in_price');
      final hsnMapping = await _dao.getSettingValue('tax_hsn_mapping');

      setState(() {
        _defaultTaxRate = double.tryParse(defaultRate ?? '') ?? 18.0;
        _taxIncludedInPrice = taxIncluded == 'true';
        _hsnTaxMapping = _parseHsnMapping(hsnMapping);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Parses the HSN mapping JSON string into a Map.
  Map<String, double> _parseHsnMapping(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      // Simple JSON-like parsing for key:value pairs
      // Format: "HSN1:rate1,HSN2:rate2"
      final map = <String, double>{};
      final pairs = json.split(',');
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final rate = double.tryParse(parts[1].trim());
          if (rate != null) {
            map[parts[0].trim()] = rate;
          }
        }
      }
      return map;
    } catch (e) {
      return {};
    }
  }

  /// Serializes the HSN mapping to a string for storage.
  String _serializeHsnMapping(Map<String, double> map) {
    return map.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();

      await _dao.insertOrUpdateSetting(
        AppSettingsCompanion.insert(
          key: 'tax_default_rate',
          value: _defaultTaxRate.toString(),
          description: const Value('Default GST rate applied to new products'),
          updatedAt: now,
        ),
      );

      await _dao.insertOrUpdateSetting(
        AppSettingsCompanion.insert(
          key: 'tax_include_in_price',
          value: _taxIncludedInPrice.toString(),
          description: const Value('Whether tax is included in displayed prices'),
          updatedAt: now,
        ),
      );

      await _dao.insertOrUpdateSetting(
        AppSettingsCompanion.insert(
          key: 'tax_hsn_mapping',
          value: _serializeHsnMapping(_hsnTaxMapping),
          description: const Value('HSN code to tax rate mapping'),
          updatedAt: now,
        ),
      );

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tax configuration saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addHsnMapping() {
    final hsn = _hsnController.text.trim();
    final rate = double.tryParse(_hsnRateController.text.trim());

    if (hsn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an HSN code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (rate == null || rate < 0 || rate > 28) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid tax rate (0-28%)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _hsnTaxMapping[hsn] = rate;
    });

    _hsnController.clear();
    _hsnRateController.clear();
  }

  void _removeHsnMapping(String hsn) {
    setState(() {
      _hsnTaxMapping.remove(hsn);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Configuration'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDefaultRateSection(),
                  const SizedBox(height: 20),
                  _buildTaxDisplaySection(),
                  const SizedBox(height: 20),
                  _buildHsnMappingSection(),
                ],
              ),
            ),
    );
  }

  /// Builds the default GST rate selection section.
  Widget _buildDefaultRateSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Default GST Rate',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Applied to new products by default',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetRates.map((rate) {
                final isSelected = _defaultTaxRate == rate;
                return ChoiceChip(
                  label: Text(
                    rate == 0 ? 'Exempt' : '${rate.toInt()}%',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1B5E20),
                  onSelected: (_) {
                    setState(() => _defaultTaxRate = rate);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Custom rate input
            Row(
              children: [
                const Text('Custom: '),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Rate',
                      suffixText: '%',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      final rate = double.tryParse(value);
                      if (rate != null && rate >= 0 && rate <= 28) {
                        setState(() => _defaultTaxRate = rate);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the tax display configuration section.
  Widget _buildTaxDisplaySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Display',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Tax included in price'),
              subtitle: Text(
                _taxIncludedInPrice
                    ? 'Prices shown include tax (e.g., ₹118 = ₹100 + 18% GST)'
                    : 'Prices shown exclude tax (e.g., ₹100 + 18% GST = ₹118)',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              value: _taxIncludedInPrice,
              onChanged: (value) {
                setState(() => _taxIncludedInPrice = value);
              },
              activeColor: const Color(0xFF1B5E20),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the HSN-wise tax mapping section.
  Widget _buildHsnMappingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HSN-wise Tax Mapping',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Override default rate for specific HSN codes',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_hsnTaxMapping.length} mapped',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Add new mapping
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _hsnController,
                    decoration: InputDecoration(
                      hintText: 'HSN Code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _hsnRateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Rate %',
                      suffixText: '%',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addHsnMapping,
                  icon: const Icon(Icons.add_circle),
                  color: const Color(0xFF1B5E20),
                  tooltip: 'Add mapping',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Existing mappings
            if (_hsnTaxMapping.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Center(
                  child: Text(
                    'No HSN mappings configured.\nAll products use the default rate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
              )
            else
              ..._hsnTaxMapping.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value.toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: Colors.red[400]),
                        onPressed: () => _removeHsnMapping(entry.key),
                        tooltip: 'Remove',
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
}
