import 'package:flutter/material.dart';

/// Page for managing role-based access control and permissions.
class PermissionControlPage extends StatefulWidget {
  const PermissionControlPage({super.key});

  @override
  State<PermissionControlPage> createState() => _PermissionControlPageState();
}

class _PermissionControlPageState extends State<PermissionControlPage> {
  final Map<String, Map<String, bool>> _permissions = {
    'admin': {
      'Billing': true, 'Products': true, 'Customers': true, 'Inventory': true,
      'Purchases': true, 'Employees': true, 'Reports': true, 'Settings': true,
      'Import/Export': true, 'Sync': true, 'Audit Logs': true,
    },
    'manager': {
      'Billing': true, 'Products': true, 'Customers': true, 'Inventory': true,
      'Purchases': true, 'Employees': true, 'Reports': true, 'Settings': false,
      'Import/Export': true, 'Sync': true, 'Audit Logs': false,
    },
    'cashier': {
      'Billing': true, 'Products': true, 'Customers': true, 'Inventory': false,
      'Purchases': false, 'Employees': false, 'Reports': false, 'Settings': false,
      'Import/Export': false, 'Sync': false, 'Audit Logs': false,
    },
    'inventory': {
      'Billing': false, 'Products': true, 'Customers': true, 'Inventory': true,
      'Purchases': true, 'Employees': false, 'Reports': true, 'Settings': false,
      'Import/Export': true, 'Sync': false, 'Audit Logs': false,
    },
    'viewer': {
      'Billing': false, 'Products': true, 'Customers': true, 'Inventory': false,
      'Purchases': false, 'Employees': false, 'Reports': true, 'Settings': false,
      'Import/Export': false, 'Sync': false, 'Audit Logs': false,
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _permissions.entries.map((roleEntry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              leading: Icon(
                roleEntry.key == 'admin' ? Icons.admin_panel_settings :
                roleEntry.key == 'manager' ? Icons.manage_accounts :
                roleEntry.key == 'cashier' ? Icons.point_of_sale :
                roleEntry.key == 'inventory' ? Icons.inventory : Icons.visibility,
              ),
              title: Text(roleEntry.key.toUpperCase()),
              children: roleEntry.value.entries.map((perm) {
                return SwitchListTile(
                  title: Text(perm.key),
                  value: perm.value,
                  onChanged: roleEntry.key == 'admin'
                      ? null
                      : (value) {
                          setState(() {
                            _permissions[roleEntry.key]![perm.key] = value;
                          });
                        },
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
