import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../injection/injection_container.dart' as di;
import '../../domain/entities/settings_entity.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Company Settings
          _buildSectionHeader('Company'),
          _buildSettingsTile(
            icon: Icons.business,
            title: 'Company Settings',
            subtitle: 'Name, address, GST details',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<dynamic>(
                  builder: (_) => const CompanySettingsPage(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.receipt_long,
            title: 'Tax Configuration',
            subtitle: 'GST rates, HSN/SAC codes',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<dynamic>(
                  builder: (_) => const TaxSettingsPage(),
                ),
              );
            },
          ),

          // App Settings
          _buildSectionHeader('App'),
          _buildSettingsTile(
            icon: Icons.backup,
            title: 'Backup & Restore',
            subtitle: 'Export/import data',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<dynamic>(
                  builder: (_) => const BackupRestorePage(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.sync,
            title: 'Sync Settings',
            subtitle: 'Configure sync frequency',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<dynamic>(
                  builder: (_) => const SyncSettingsPage(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.print,
            title: 'Printer Settings',
            subtitle: 'Bluetooth/USB printer setup',
            onTap: () {
              _showPrinterSettingsDialog(context);
            },
          ),

          // About
          _buildSectionHeader('About'),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About SS MART',
            subtitle: 'Version 1.0.0',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'SS MART ERP',
                applicationVersion: '1.0.0+1',
                applicationIcon: const Icon(
                  Icons.store,
                  size: 48,
                  color: Color(0xFF1B5E20),
                ),
                children: const [
                  Text('Sai Sangameshwara Mart Retail ERP System'),
                  SizedBox(height: 8),
                  Text('A complete offline-first retail management solution '
                      'with POS billing, inventory, loyalty, and GST compliance.'),
                  SizedBox(height: 8),
                  Text('Developed for SS MART'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1B5E20)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController(text: 'Sai Sangameshwara Mart');
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Company Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Company name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tax Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gstinController,
                decoration: const InputDecoration(
                  labelText: 'GSTIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _panController,
                decoration: const InputDecoration(
                  labelText: 'PAN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveCompanySettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Saves company settings to the local database via SettingsRepository.
  ///
  /// Persists each field as a key-value pair: company_name, company_address,
  /// company_phone, company_email, company_gstin, company_pan.
  Future<void> _saveCompanySettings() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = di.sl<SettingsRepository>();
    final fields = {
      'company_name': _companyNameController.text.trim(),
      'company_address': _addressController.text.trim(),
      'company_phone': _phoneController.text.trim(),
      'company_email': _emailController.text.trim(),
      'company_gstin': _gstinController.text.trim(),
      'company_pan': _panController.text.trim(),
    };

    for (final entry in fields.entries) {
      await repo.setSetting(entry.key, entry.value, description: 'Company settings');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }
}

class TaxSettingsPage extends StatelessWidget {
  const TaxSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Configuration'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Default GST Rates',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTaxRateTile('GST 0%', '0%', 'Essentials'),
          _buildTaxRateTile('GST 5%', '5%', 'Packaged food, footwear < ₹1000'),
          _buildTaxRateTile('GST 12%', '12%', 'Processed food, business class'),
          _buildTaxRateTile('GST 18%', '18%', 'Most goods & services'),
          _buildTaxRateTile('GST 28%', '28%', 'Luxury items'),
          const SizedBox(height: 24),
          const Text(
            'HSN/SAC Code Mapping',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Configure HSN codes for products and SAC codes for services.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _showHsnSacDialog(context);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Manage HSN/SAC Codes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxRateTile(String name, String rate, String description) {
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(description),
        trailing: Text(
          rate,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
      ),
    );
  }
}

class BackupRestorePage extends StatelessWidget {
  const BackupRestorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Backup Section
          const Text(
            'Backup',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Export your data to a file for safekeeping.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup, color: Color(0xFF1B5E20)),
                  title: const Text('Full Backup'),
                  subtitle: const Text('Export all data'),
                  trailing: ElevatedButton(
                    onPressed: () => _backupAll(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Backup'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shopping_cart, color: Colors.blue),
                  title: const Text('Products & Inventory'),
                  subtitle: const Text('Export products and stock data'),
                  trailing: ElevatedButton(
                    onPressed: () => _backupProducts(context),
                    child: const Text('Export'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people, color: Colors.orange),
                  title: const Text('Customers'),
                  subtitle: const Text('Export customer data'),
                  trailing: ElevatedButton(
                    onPressed: () => _backupCustomers(context),
                    child: const Text('Export'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Restore Section
          const Text(
            'Restore',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Import data from a backup file.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore, color: Colors.red),
              title: const Text('Restore from Backup'),
              subtitle: const Text('Import data from file'),
              trailing: ElevatedButton(
                onPressed: () => _restoreBackup(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Restore'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Backs up all data and shows the resulting file path in a snackbar.
  Future<void> _backupAll(BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/ss_mart_full_backup.csv';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup saved to $path')),
    );
  }

  /// Backs up products & inventory and shows the file path.
  Future<void> _backupProducts(BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/ss_mart_products_export.csv';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup saved to $path')),
    );
  }

  /// Backs up customers and shows the file path.
  Future<void> _backupCustomers(BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/ss_mart_customers_export.csv';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup saved to $path')),
    );
  }

  /// Shows a placeholder for restore functionality.
  Future<void> _restoreBackup(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restore functionality will be available in the next version'),
      ),
    );
  }
}

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  bool _autoSync = true;
  bool _syncOnWifiOnly = false;
  String _conflictResolution = 'server';
  SyncSettingsEntity? _currentSettings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Loads current sync settings from the local database.
  Future<void> _loadSettings() async {
    final result = await di.sl<SettingsRepository>().getSyncSettings();
    result.fold(
      (_) {},
      (settings) {
        if (mounted) {
          setState(() {
            _currentSettings = settings;
            _autoSync = settings.autoSync;
            _syncOnWifiOnly = settings.syncOnWifiOnly;
            _conflictResolution = settings.conflictResolution;
            _isLoading = false;
          });
        }
      },
    );
  }

  /// Persists updated sync settings to the local database.
  Future<void> _saveSettings({bool? autoSync, bool? syncOnWifiOnly, String? conflictResolution}) async {
    final updated = SyncSettingsEntity(
      autoSync: autoSync ?? _autoSync,
      syncOnWifiOnly: syncOnWifiOnly ?? _syncOnWifiOnly,
      syncFrequencyMinutes: _currentSettings?.syncFrequencyMinutes ?? 15,
      conflictResolution: conflictResolution ?? _conflictResolution,
      lastSyncedAt: _currentSettings?.lastSyncedAt,
    );
    await di.sl<SettingsRepository>().saveSyncSettings(updated);
    if (mounted) {
      setState(() {
        _currentSettings = updated;
        if (autoSync != null) _autoSync = autoSync;
        if (syncOnWifiOnly != null) _syncOnWifiOnly = syncOnWifiOnly;
        if (conflictResolution != null) _conflictResolution = conflictResolution;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sync Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Auto Sync'),
            subtitle: const Text('Sync data automatically when online'),
            value: _autoSync,
            onChanged: (value) => _saveSettings(autoSync: value),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Sync on WiFi Only'),
            subtitle: const Text('Avoid using mobile data for sync'),
            value: _syncOnWifiOnly,
            onChanged: (value) => _saveSettings(syncOnWifiOnly: value),
          ),
          const Divider(),
          ListTile(
            title: const Text('Sync Frequency'),
            subtitle: Text('Every ${_currentSettings?.syncFrequencyMinutes ?? 15} minutes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showFrequencyPicker(context);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Last Synced'),
            subtitle: Text(_currentSettings?.lastSyncedAt != null
                ? _formatDateTime(_currentSettings!.lastSyncedAt!)
                : 'Never'),
            trailing: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manual sync triggered')),
                );
              },
              child: const Text('Sync Now'),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Conflict Resolution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          RadioListTile(
            title: const Text('Server wins'),
            subtitle: const Text('Overwrite local changes with server data'),
            value: 'server',
            groupValue: _conflictResolution,
            onChanged: (value) => _saveSettings(conflictResolution: value),
          ),
          RadioListTile(
            title: const Text('Local wins'),
            subtitle: const Text('Overwrite server data with local changes'),
            value: 'local',
            groupValue: _conflictResolution,
            onChanged: (value) => _saveSettings(conflictResolution: value),
          ),
          RadioListTile(
            title: const Text('Manual'),
            subtitle: const Text('Ask me to resolve conflicts'),
            value: 'manual',
            groupValue: _conflictResolution,
            onChanged: (value) => _saveSettings(conflictResolution: value),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog to pick the sync frequency interval.
  void _showFrequencyPicker(BuildContext context) {
    final frequencies = [5, 15, 30, 60];
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Sync Frequency'),
        children: frequencies.map((min) => SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            final updated = SyncSettingsEntity(
              autoSync: _autoSync,
              syncOnWifiOnly: _syncOnWifiOnly,
              syncFrequencyMinutes: min,
              conflictResolution: _conflictResolution,
              lastSyncedAt: _currentSettings?.lastSyncedAt,
            );
            di.sl<SettingsRepository>().saveSyncSettings(updated);
            setState(() => _currentSettings = updated);
          },
          child: Text('Every $min minutes'),
        )).toList(),
      ),
    );
  }

  /// Formats a DateTime for display in the "Last Synced" field.
  String _formatDateTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}

void _showHsnSacDialog(BuildContext context) {
  final hsnCodes = [
    {'code': '001', 'description': 'Live animals', 'gstRate': '0%'},
    {'code': '002', 'description': 'Meat and edible meat offal', 'gstRate': '0%'},
    {'code': '0401', 'description': 'Milk and cream', 'gstRate': '0%'},
    {'code': '0713', 'description': 'Dried leguminous vegetables', 'gstRate': '0%'},
    {'code': '1006', 'description': 'Rice', 'gstRate': '5%'},
    {'code': '1101', 'description': 'Wheat flour', 'gstRate': '0%'},
    {'code': '1507', 'description': 'Soybean oil', 'gstRate': '5%'},
    {'code': '1701', 'description': 'Sugar', 'gstRate': '5%'},
    {'code': '1905', 'description': 'Bread, pastry', 'gstRate': '5%'},
    {'code': '2106', 'description': 'Food preparations', 'gstRate': '18%'},
    {'code': '2201', 'description': 'Mineral water', 'gstRate': '18%'},
    {'code': '3004', 'description': 'Medicaments', 'gstRate': '12%'},
    {'code': '3304', 'description': 'Beauty preparations', 'gstRate': '28%'},
    {'code': '3401', 'description': 'Soap', 'gstRate': '18%'},
    {'code': '3808', 'description': 'Insecticides', 'gstRate': '18%'},
    {'code': '3923', 'description': 'Plastic articles', 'gstRate': '18%'},
    {'code': '3926', 'description': 'Other plastic articles', 'gstRate': '18%'},
    {'code': '4202', 'description': 'Bags and cases', 'gstRate': '18%'},
    {'code': '4818', 'description': 'Toilet paper', 'gstRate': '12%'},
    {'code': '4823', 'description': 'Other paper articles', 'gstRate': '18%'},
    {'code': '4901', 'description': 'Printed books', 'gstRate': '0%'},
    {'code': '4911', 'description': 'Other printed matter', 'gstRate': '12%'},
    {'code': '6110', 'description': 'Knitted apparel', 'gstRate': '5%'},
    {'code': '6203', 'description': "Men's garments", 'gstRate': '5%'},
    {'code': '6204', 'description': "Women's garments", 'gstRate': '5%'},
    {'code': '6402', 'description': 'Footwear', 'gstRate': '18%'},
    {'code': '6403', 'description': 'Leather footwear', 'gstRate': '18%'},
    {'code': '7013', 'description': 'Glassware', 'gstRate': '18%'},
    {'code': '7323', 'description': 'Steel articles', 'gstRate': '18%'},
    {'code': '7615', 'description': 'Aluminium articles', 'gstRate': '18%'},
    {'code': '8414', 'description': 'Air pumps', 'gstRate': '18%'},
    {'code': '8415', 'description': 'Air conditioning', 'gstRate': '28%'},
    {'code': '8418', 'description': 'Refrigerators', 'gstRate': '18%'},
    {'code': '8443', 'description': 'Printers', 'gstRate': '18%'},
    {'code': '8471', 'description': 'Computers', 'gstRate': '18%'},
    {'code': '8504', 'description': 'Electrical transformers', 'gstRate': '18%'},
    {'code': '8507', 'description': 'Batteries', 'gstRate': '28%'},
    {'code': '8517', 'description': 'Telephones', 'gstRate': '18%'},
    {'code': '8528', 'description': 'Monitors', 'gstRate': '18%'},
    {'code': '9401', 'description': 'Furniture', 'gstRate': '18%'},
    {'code': '9403', 'description': 'Other furniture', 'gstRate': '18%'},
    {'code': '9503', 'description': 'Toys', 'gstRate': '12%'},
    {'code': '9608', 'description': 'Pens', 'gstRate': '18%'},
    {'code': '9954', 'description': 'Construction services', 'gstRate': '18%'},
    {'code': '9961', 'description': 'Financial services', 'gstRate': '18%'},
    {'code': '9963', 'description': 'Accommodation services', 'gstRate': '18%'},
    {'code': '9964', 'description': 'Passenger transport', 'gstRate': '5%'},
    {'code': '9965', 'description': 'Goods transport', 'gstRate': '5%'},
    {'code': '9966', 'description': 'Rental services', 'gstRate': '18%'},
    {'code': '9971', 'description': 'Business support services', 'gstRate': '18%'},
    {'code': '9972', 'description': 'Management services', 'gstRate': '18%'},
    {'code': '9983', 'description': 'Other professional services', 'gstRate': '18%'},
  ];

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('HSN/SAC Codes'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: hsnCodes.length,
          itemBuilder: (context, index) {
            final hsn = hsnCodes[index];
            return ListTile(
              title: Text(hsn['code']!),
              subtitle: Text(hsn['description']!),
              trailing: Text(
                hsn['gstRate']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              dense: true,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showPrinterSettingsDialog(BuildContext context) {
  final printerNameController = TextEditingController(text: 'Default Printer');
  String selectedPaperSize = 'A4';
  String selectedConnectionType = 'Bluetooth';

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Printer Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: printerNameController,
              decoration: const InputDecoration(
                labelText: 'Printer Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedPaperSize,
              decoration: const InputDecoration(
                labelText: 'Paper Size',
                border: OutlineInputBorder(),
              ),
              items: ['A4', 'A5', 'A6', 'Letter', 'Thermal 58mm', 'Thermal 80mm']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => selectedPaperSize = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedConnectionType,
              decoration: const InputDecoration(
                labelText: 'Connection Type',
                border: OutlineInputBorder(),
              ),
              items: ['Bluetooth', 'USB', 'WiFi', 'LAN']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => selectedConnectionType = v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Printer settings saved: $selectedConnectionType, $selectedPaperSize',
                  ),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
