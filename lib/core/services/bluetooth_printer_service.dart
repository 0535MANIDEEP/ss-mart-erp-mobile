import 'dart:async';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/billing/domain/entities/bill_entity.dart';

/// Connection state of the thermal printer.
enum PrinterConnectionState {
  disconnected,
  connecting,
  connected,
  printing,
  error,
}

/// Service for managing thermal printer connections and printing receipts.
///
/// ## Architecture
/// This service provides a unified interface for printing receipts. It supports:
/// - **System print dialog** (Windows/macOS/Linux) via the `printing` package
/// - **Bluetooth/USB thermal printers** via ESC/POS (when platform supports it)
///
/// On Windows desktop, printing goes through the system print dialog.
/// On Android/iOS, this can be extended to use Bluetooth ESC/POS printers.
///
/// ## Paper Widths
/// Supports standard thermal paper widths:
/// - 58mm (receipt width: 32 characters per line)
/// - 80mm (receipt width: 48 characters per line)
///
/// ## Usage
/// ```dart
/// final printer = BluetoothPrinterService();
/// await printer.initialize();
/// await printer.printReceipt(bill, items, storeName: 'SS MART');
/// ```
class BluetoothPrinterService {
  PrinterConnectionState _state = PrinterConnectionState.disconnected;
  String _printerName = 'Default Printer';
  String _paperWidth = '80mm';
  bool _autoPrint = false;

  final _stateController = StreamController<PrinterConnectionState>.broadcast();

  static const String _prefPrinterName = 'printer_name';
  static const String _prefPaperWidth = 'paper_width';
  static const String _prefAutoPrint = 'auto_print_enabled';

  /// Stream of printer connection state changes.
  Stream<PrinterConnectionState> get printerState => _stateController.stream;

  /// Whether a printer is currently connected.
  bool get isConnected => _state == PrinterConnectionState.connected;

  /// Whether auto-print is enabled.
  bool get autoPrint => _autoPrint;

  /// Current printer name.
  String get printerName => _printerName;

  /// Current paper width setting.
  String get paperWidth => _paperWidth;

  /// Initializes the service and loads saved settings.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _printerName = prefs.getString(_prefPrinterName) ?? 'Default Printer';
    _paperWidth = prefs.getString(_prefPaperWidth) ?? '80mm';
    _autoPrint = prefs.getBool(_prefAutoPrint) ?? false;
  }

  /// Updates the printer name setting.
  Future<void> setPrinterName(String name) async {
    _printerName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPrinterName, name);
  }

  /// Updates the paper width setting.
  Future<void> setPaperWidth(String width) async {
    _paperWidth = width;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPaperWidth, width);
  }

  /// Toggles auto-print setting.
  Future<void> setAutoPrint(bool enabled) async {
    _autoPrint = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoPrint, enabled);
  }

  /// Connects to a Bluetooth printer.
  ///
  /// On desktop platforms, this marks the system printer as "connected"
  /// since actual Bluetooth communication requires platform-specific plugins.
  Future<bool> connectPrinter({String? printerAddress}) async {
    _updateState(PrinterConnectionState.connecting);
    try {
      // On desktop, we use the system print dialog
      // On mobile, this would use flutter_blue_plus for Bluetooth
      _updateState(PrinterConnectionState.connected);
      return true;
    } catch (e) {
      _updateState(PrinterConnectionState.error);
      return false;
    }
  }

  /// Disconnects from the current printer.
  Future<void> disconnectPrinter() async {
    _updateState(PrinterConnectionState.disconnected);
  }

  /// Prints a complete bill receipt.
  ///
  /// Generates a formatted receipt with:
  /// - Store name, address, GSTIN
  /// - Bill number and date
  /// - Itemized product list with quantities and prices
  /// - Tax breakdown (CGST/SGST or IGST)
  /// - Subtotal, discount, total
  /// - Payment mode
  /// - Thank you message
  Future<void> printReceipt({
    required String storeName,
    required String? storeAddress,
    required String? storeGstin,
    required String billNumber,
    required DateTime billDate,
    required List<BillItem> items,
    required int subtotal,
    required int taxAmount,
    required int discountAmount,
    required int totalAmount,
    required String paymentMode,
    required String? customerName,
    int roundOff = 0,
  }) async {
    _updateState(PrinterConnectionState.printing);
    try {
      final pdfBytes = await _generateReceiptPdf(
        storeName: storeName,
        storeAddress: storeAddress,
        storeGstin: storeGstin,
        billNumber: billNumber,
        billDate: billDate,
        items: items,
        subtotal: subtotal,
        taxAmount: taxAmount,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        paymentMode: paymentMode,
        customerName: customerName,
        roundOff: roundOff,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => Uint8List.fromList(pdfBytes),
        name: 'Receipt_$billNumber',
      );

      _updateState(PrinterConnectionState.connected);
    } catch (e) {
      _updateState(PrinterConnectionState.error);
      rethrow;
    }
  }

  /// Prints a test page to verify printer connectivity.
  Future<void> printTestPage() async {
    _updateState(PrinterConnectionState.printing);
    try {
      final pdf = pw.Document();
      final font = pw.Font.helvetica();
      final fontBold = pw.Font.helveticaBold();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            _paperWidth == '58mm' ? 48 * PdfPageFormat.mm : 80 * PdfPageFormat.mm,
            200 * PdfPageFormat.mm,
          ),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('SS MART',
                    style: pw.TextStyle(font: fontBold, fontSize: 18)),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Printer Test Page',
                  style: pw.TextStyle(font: font, fontSize: 14)),
              pw.SizedBox(height: 16),
              pw.Text('Paper Width: $_paperWidth',
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text('Printer: $_printerName',
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text('0123456789',
                  style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 16),
              pw.Text('Print successful!',
                  style: pw.TextStyle(font: fontBold, fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.Text('${DateTime.now()}',
                  style: pw.TextStyle(font: font, fontSize: 9)),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Test_Page',
      );

      _updateState(PrinterConnectionState.connected);
    } catch (e) {
      _updateState(PrinterConnectionState.error);
      rethrow;
    }
  }

  /// Generates receipt PDF bytes for a bill.
  Future<List<int>> _generateReceiptPdf({
    required String storeName,
    required String? storeAddress,
    required String? storeGstin,
    required String billNumber,
    required DateTime billDate,
    required List<BillItem> items,
    required int subtotal,
    required int taxAmount,
    required int discountAmount,
    required int totalAmount,
    required String paymentMode,
    required String? customerName,
    int roundOff = 0,
  }) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final pageWidth = _paperWidth == '58mm'
        ? 48 * PdfPageFormat.mm
        : 80 * PdfPageFormat.mm;

    final centerAlign = pw.TextAlign.center;
    final rightAlign = pw.TextAlign.right;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, 200 * PdfPageFormat.mm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Store Header
            pw.Center(
              child: pw.Text(storeName,
                  style: pw.TextStyle(font: fontBold, fontSize: 16)),
            ),
            if (storeAddress != null && storeAddress.isNotEmpty)
              pw.Center(
                child: pw.Text(storeAddress,
                    style: pw.TextStyle(font: font, fontSize: 9)),
              ),
            if (storeGstin != null && storeGstin.isNotEmpty)
              pw.Center(
                child: pw.Text('GSTIN: $storeGstin',
                    style: pw.TextStyle(font: font, fontSize: 9)),
              ),
            pw.SizedBox(height: 4),
            pw.Divider(),
            pw.SizedBox(height: 4),

            // Bill Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Bill #: $billNumber',
                    style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Text(_formatDate(billDate),
                    style: pw.TextStyle(font: font, fontSize: 10)),
              ],
            ),
            if (customerName != null && customerName.isNotEmpty)
              pw.Text('Customer: $customerName',
                  style: pw.TextStyle(font: font, fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Divider(),
            pw.SizedBox(height: 4),

            // Items Header
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Text('Item',
                      style: pw.TextStyle(font: fontBold, fontSize: 9)),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text('Qty',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                      textAlign: centerAlign),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text('Rate',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                      textAlign: rightAlign),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text('Amount',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                      textAlign: rightAlign),
                ),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 2),

            // Items
            ...items.map((item) => pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(item.productName,
                          style: pw.TextStyle(font: font, fontSize: 9),
                          maxLines: 1),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text('${item.quantity.round()}',
                          style: pw.TextStyle(font: font, fontSize: 9),
                          textAlign: centerAlign),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('₹${item.unitPrice}',
                          style: pw.TextStyle(font: font, fontSize: 9),
                          textAlign: rightAlign),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('₹${item.totalAmount}',
                          style: pw.TextStyle(font: font, fontSize: 9),
                          textAlign: rightAlign),
                    ),
                  ],
                )),

            pw.SizedBox(height: 4),
            pw.Divider(),
            pw.SizedBox(height: 4),

            // Totals
            _buildTotalRow(font, 'Subtotal', '₹$subtotal'),
            if (discountAmount > 0)
              _buildTotalRow(font, 'Discount', '-₹$discountAmount'),
            _buildTotalRow(font, 'Tax', '₹$taxAmount'),
            if (roundOff != 0)
              _buildTotalRow(font, 'Round Off', '₹$roundOff'),
            pw.Divider(),
            _buildTotalRow(fontBold, 'TOTAL', '₹$totalAmount', bold: true),
            pw.Divider(),
            pw.SizedBox(height: 4),

            // Payment
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Payment Mode:',
                    style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Text(paymentMode,
                    style: pw.TextStyle(font: fontBold, fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Footer
            pw.Center(
              child: pw.Text('Thank you for shopping!',
                  style: pw.TextStyle(font: fontBold, fontSize: 12)),
            ),
            pw.Center(
              child: pw.Text('Visit us again',
                  style: pw.TextStyle(font: font, fontSize: 9)),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                  'Generated: ${_formatDateTime(DateTime.now())}',
                  style: pw.TextStyle(font: font, fontSize: 7)),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildTotalRow(pw.Font font, String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(font: font, fontSize: bold ? 11 : 10);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _updateState(PrinterConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Disposes resources.
  void dispose() {
    _stateController.close();
  }
}
