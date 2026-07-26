import 'package:flutter/material.dart';
import '../../../../core/services/bluetooth_printer_service.dart';
import 'package:get_it/get_it.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final _printerService = GetIt.instance<BluetoothPrinterService>();
  bool _autoPrint = false;
  String _paperWidth = '80mm';
  String _printerName = 'Default Printer';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _printerService.initialize();
    _autoPrint = _printerService.autoPrint;
    _paperWidth = _printerService.paperWidth;
    _printerName = _printerService.printerName;
    _isConnected = _printerService.isConnected;
    if (mounted) setState(() {});
  }

  Future<void> _connectPrinter() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await _printerService.connectPrinter();
      Navigator.pop(context);

      if (success) {
        setState(() => _isConnected = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('System printer ready'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect to printer'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await _printerService.disconnectPrinter();
    setState(() => _isConnected = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer disconnected'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _toggleAutoPrint(bool value) async {
    await _printerService.setAutoPrint(value);
    setState(() => _autoPrint = value);
  }

  Future<void> _setPaperWidth(String width) async {
    await _printerService.setPaperWidth(width);
    setState(() => _paperWidth = width);
  }

  Future<void> _testPrint() async {
    try {
      await _printerService.printTestPage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test page printed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Auto-print receipt'),
              subtitle: const Text('Automatically print after bill completion'),
              value: _autoPrint,
              onChanged: _toggleAutoPrint,
              secondary: const Icon(Icons.print),
            ),
            const Divider(),

            ListTile(
              leading: Icon(
                _isConnected ? Icons.print : Icons.print_disabled,
                color: _isConnected ? Colors.blue : Colors.grey,
              ),
              title: Text(_printerName),
              subtitle: Text(_isConnected ? 'Ready' : 'Not connected'),
              trailing: _isConnected
                  ? TextButton(
                      onPressed: _disconnect,
                      child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                    )
                  : TextButton(
                      onPressed: _connectPrinter,
                      child: const Text('Connect'),
                    ),
            ),
            const Divider(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Paper Width',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            RadioListTile<String>(
              title: const Text('80mm (Standard)'),
              value: '80mm',
              groupValue: _paperWidth,
              onChanged: (v) => v != null ? _setPaperWidth(v) : null,
            ),
            RadioListTile<String>(
              title: const Text('58mm (Compact)'),
              value: '58mm',
              groupValue: _paperWidth,
              onChanged: (v) => v != null ? _setPaperWidth(v) : null,
            ),
            const Divider(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _testPrint,
                  icon: const Icon(Icons.print),
                  label: const Text('Test Print'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
