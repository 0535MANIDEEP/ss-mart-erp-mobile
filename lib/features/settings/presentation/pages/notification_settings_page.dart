import 'package:flutter/material.dart';

/// Notification settings page for managing SMS, Email, and WhatsApp templates.
///
/// Displays notification templates grouped by channel type with toggle
/// switches to enable/disable individual templates. Provides template
/// preview with variable substitution and test send functionality.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_NotifTemplate> _templates = [
    _NotifTemplate(name: 'Bill Receipt', type: 'sms', event: 'bill_created',
      body: 'Dear {{customer_name}}, your bill {{bill_number}} of ₹{{total_amount}} is generated. Thank you for shopping with SS Mart!',
      isActive: true),
    _NotifTemplate(name: 'Payment Received', type: 'sms', event: 'payment_received',
      body: 'Dear {{customer_name}}, we have received ₹{{amount}} against bill {{bill_number}}. Balance: ₹{{balance}}. Thank you!',
      isActive: true),
    _NotifTemplate(name: 'Payment Reminder', type: 'sms', event: 'payment_reminder',
      body: 'Dear {{customer_name}}, you have an outstanding of ₹{{balance}}. Please clear your dues at the earliest. — SS Mart',
      isActive: true),
    _NotifTemplate(name: 'Low Stock Alert', type: 'email', event: 'low_stock',
      body: 'Product {{product_name}} (SKU: {{sku}}) is running low. Current stock: {{current_stock}}. Reorder level: {{reorder_level}}.',
      isActive: true),
    _NotifTemplate(name: 'Daily Sales Summary', type: 'email', event: 'daily_summary',
      body: 'Total sales: ₹{{total_sales}}. Bills: {{bill_count}}. Average bill: ₹{{avg_bill}}. Top product: {{top_product}}.',
      isActive: true),
    _NotifTemplate(name: 'Order Confirmation', type: 'whatsapp', event: 'order_confirmed',
      body: 'Hi {{customer_name}}! Your order {{order_number}} is confirmed. Total: ₹{{total_amount}}. Expected delivery: {{delivery_date}}.',
      isActive: false),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'SMS', icon: Icon(Icons.sms)),
            Tab(text: 'Email', icon: Icon(Icons.email)),
            Tab(text: 'WhatsApp', icon: Icon(Icons.chat)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplateList('sms'),
          _buildTemplateList('email'),
          _buildTemplateList('whatsapp'),
        ],
      ),
    );
  }

  Widget _buildTemplateList(String type) {
    final templates = _templates.where((t) => t.type == type).toList();
    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No $type templates configured', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: template.isActive
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              child: Icon(
                _getIcon(type),
                color: template.isActive ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
            title: Text(
              template.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              template.event.replaceAll('_', ' '),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Switch(
              value: template.isActive,
              onChanged: (value) {
                setState(() => template.isActive = value);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${template.name} ${value ? "enabled" : "disabled"}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Template Body:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        template.body,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showPreview(context, template),
                          icon: const Icon(Icons.preview, size: 16),
                          label: const Text('Preview'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Test notification sent!')),
                            );
                          },
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Test Send'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showEditDialog(context, template),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPreview(BuildContext context, _NotifTemplate template) {
    var preview = template.body;
    final sampleVars = {
      'customer_name': 'Rajesh Kumar',
      'bill_number': 'BILL-0001',
      'total_amount': '442',
      'amount': '442',
      'balance': '0',
      'product_name': 'Basmati Rice 5kg',
      'sku': 'BR5',
      'current_stock': '5',
      'reorder_level': '10',
      'order_number': 'ORD-001',
      'delivery_date': '01 Feb 2026',
      'total_sales': '25000',
      'bill_count': '12',
      'avg_bill': '2083',
      'top_product': 'Maggi Noodles',
    };
    for (final kv in sampleVars.entries) {
      preview = preview.replaceAll('{{${kv.key}}}', kv.value);
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Preview: ${template.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(label: Text(template.type.toUpperCase(), style: const TextStyle(fontSize: 11))),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(preview, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 8),
            Text(
              '${preview.length} characters',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, _NotifTemplate template) {
    final bodyController = TextEditingController(text: template.body);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit: ${template.name}'),
        content: TextField(
          controller: bodyController,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Template body...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() => template.body = bodyController.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'sms': return Icons.sms;
      case 'email': return Icons.email;
      case 'whatsapp': return Icons.chat;
      default: return Icons.notifications;
    }
  }
}

class _NotifTemplate {
  String name;
  String type;
  String event;
  String body;
  bool isActive;

  _NotifTemplate({
    required this.name,
    required this.type,
    required this.event,
    required this.body,
    required this.isActive,
  });
}
