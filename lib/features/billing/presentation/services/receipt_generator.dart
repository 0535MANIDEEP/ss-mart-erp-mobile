import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw show PdfGoogleFonts;
import 'package:pdf/widgets.dart' as pw show PdfPageFormat;
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/gst_calculator.dart';

class ReceiptGenerator {
  static final ReceiptGenerator _instance = ReceiptGenerator._internal();
  factory ReceiptGenerator() => _instance;
  ReceiptGenerator._internal();

  Future<Uint8List> generateBillPdf(Bill bill) async {
    final pdf = pw.Document();

    // Try to load a custom font for better rendering
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 1000 * PdfPageFormat.mm), // 80mm thermal printer width
        margin: const pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(bill, font, fontBold),
              pw.SizedBox(height: 8),
              _buildCustomerInfo(bill, font, fontBold),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 4),
              _buildItemsTable(bill, font, fontBold),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 4),
              _buildTotals(bill, font, fontBold),
              pw.SizedBox(height: 8),
              _buildPaymentInfo(bill, font, fontBold),
              pw.SizedBox(height: 12),
              _buildFooter(bill, font, fontBold),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateA4InvoicePdf(Bill bill) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInvoiceHeader(bill, font, fontBold),
              pw.SizedBox(height: 16),
              _buildInvoiceCustomerInfo(bill, font, fontBold),
              pw.SizedBox(height: 16),
              _buildInvoiceItemsTable(bill, font, fontBold),
              pw.SizedBox(height: 16),
              _buildInvoiceTotals(bill, font, fontBold),
              pw.SizedBox(height: 24),
              _buildInvoiceFooter(bill, font, fontBold),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'SS MART',
          style: pw.TextStyle(font: fontBold, fontSize: 18),
        ),
        pw.Text(
          'Sai Sangameshwara Mart',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
        pw.Text(
          'GSTIN: 29ABCDE1234F1Z5',
          style: pw.TextStyle(font: font, fontSize: 8),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          bill.isReturn ? 'RETURN INVOICE' : 'TAX INVOICE',
          style: pw.TextStyle(font: fontBold, fontSize: 12),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Bill No: ${bill.billNumber}',
              style: pw.TextStyle(font: font, fontSize: 9),
            ),
            pw.Text(
              'Date: ${_formatDate(bill.billDate)}',
              style: pw.TextStyle(font: font, fontSize: 9),
            ),
          ],
        ),
        if (bill.invoiceNumber != null)
          pw.Text(
            'Invoice: ${bill.invoiceNumber}',
            style: pw.TextStyle(font: font, fontSize: 9),
          ),
      ],
    );
  }

  pw.Widget _buildCustomerInfo(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Customer: ${bill.customerName ?? 'Walk-in Customer'}',
          style: pw.TextStyle(font: fontBold, fontSize: 10),
        ),
        if (bill.customerId != null)
          pw.Text(
            'ID: ${bill.customerId}',
            style: pw.TextStyle(font: font, fontSize: 8),
          ),
      ],
    );
  }

  pw.Widget _buildItemsTable(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 8),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      columnWidths: {
        0: const pw.FlexColumnWidth(3), // Item
        1: const pw.FlexColumnWidth(1), // Qty
        2: const pw.FlexColumnWidth(1.5), // Rate
        3: const pw.FlexColumnWidth(1.5), // Tax
        4: const pw.FlexColumnWidth(1.5), // Total
      },
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      data: [
        ['Item', 'Qty', 'Rate', 'Tax', 'Total'],
        ...bill.items.map((item) => [
              item.productName,
              item.quantity.toStringAsFixed(item.quantity == item.quantity.round() ? 0 : 2),
              '₹${item.unitPrice}',
              '₹${item.taxAmount}',
              '₹${item.totalAmount}',
            ]),
      ],
    );
  }

  pw.Widget _buildTotals(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _buildTotalRow('Subtotal', '₹${bill.subtotal}', font, fontBold, isTotal: false),
        if (bill.discountAmount > 0)
          _buildTotalRow('Discount', '-₹${bill.discountAmount}', font, fontBold, isTotal: false),
        _buildTotalRow('Tax (GST)', '₹${bill.taxAmount}', font, fontBold, isTotal: false),
        if (bill.roundOff != 0)
          _buildTotalRow('Round Off', '₹${bill.roundOff}', font, fontBold, isTotal: false),
        pw.Divider(),
        _buildTotalRow('TOTAL', '₹${bill.totalAmount}', font, fontBold, isTotal: true, fontSize: 12),
      ],
    );
  }

  pw.Widget _buildTotalRow(String label, String value, pw.Font font, pw.Font fontBold,
      {bool isTotal = false, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: isTotal ? fontBold : font,
              fontSize: fontSize,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: isTotal ? fontBold : font,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPaymentInfo(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Payment: ${bill.paymentMode}',
          style: pw.TextStyle(font: fontBold, fontSize: 9),
        ),
        if (bill.isCreditSale)
          pw.Text(
            'Due: ₹${bill.dueAmount} | Paid: ₹${bill.paidAmount}',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.red),
          )
        else
          pw.Text(
            'Paid: ₹${bill.paidAmount}',
            style: pw.TextStyle(font: font, fontSize: 9),
          ),
      ],
    );
  }

  pw.Widget _buildFooter(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 4),
        pw.Text(
          'Thank you for shopping with us!',
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
        pw.Text(
          'Visit again',
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generated by SS MART ERP',
          style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey),
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceHeader(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('SS MART', style: pw.TextStyle(font: fontBold, fontSize: 28)),
            pw.Text('Sai Sangameshwara Mart', style: pw.TextStyle(font: font, fontSize: 12)),
            pw.Text('GSTIN: 29ABCDE1234F1Z5', style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Text('Phone: +91-9876543210', style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: bill.isReturn ? PdfColors.red100 : PdfColors.green100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                bill.isReturn ? 'RETURN INVOICE' : 'TAX INVOICE',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 14,
                  color: bill.isReturn ? PdfColors.red : PdfColors.green,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Bill No: ${bill.billNumber}', style: pw.TextStyle(font: fontBold, fontSize: 12)),
            pw.Text('Date: ${_formatDate(bill.billDate)}', style: pw.TextStyle(font: font, fontSize: 10)),
            if (bill.invoiceNumber != null)
              pw.Text('Invoice: ${bill.invoiceNumber}', style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceCustomerInfo(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Bill To:', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                pw.Text(bill.customerName ?? 'Walk-in Customer', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                if (bill.customerId != null)
                  pw.Text('Customer ID: ${bill.customerId}', style: pw.TextStyle(font: font, fontSize: 9)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Payment: ${bill.paymentMode}', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                if (bill.isCreditSale)
                  pw.Text('Credit Due: ₹${bill.dueAmount}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.red))
                else
                  pw.Text('Paid: ₹${bill.paidAmount}', style: pw.TextStyle(font: font, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceItemsTable(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(4), // Item
        1: const pw.FlexColumnWidth(1), // HSN
        2: const pw.FlexColumnWidth(1), // Qty
        3: const pw.FlexColumnWidth(1), // Unit
        4: const pw.FlexColumnWidth(1.5), // Rate
        5: const pw.FlexColumnWidth(1.5), // Tax%
        6: const pw.FlexColumnWidth(1.5), // Tax Amt
        7: const pw.FlexColumnWidth(1.5), // Total
      },
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignment: pw.Alignment.centerLeft,
      data: [
        ['Item', 'HSN', 'Qty', 'Unit', 'Rate', 'Tax%', 'Tax', 'Total'],
        ...bill.items.map((item) => [
              item.productName,
              '', // HSN - would come from product
              item.quantity.toStringAsFixed(item.quantity == item.quantity.round() ? 0 : 2),
              'PCS',
              '₹${item.unitPrice}',
              '', // Tax%
              '₹${item.taxAmount}',
              '₹${item.totalAmount}',
            ]),
      ],
    );
  }

  pw.Widget _buildInvoiceTotals(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 250,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _buildInvoiceTotalRow('Subtotal', '₹${bill.subtotal}', font, fontBold),
            if (bill.discountAmount > 0)
              _buildInvoiceTotalRow('Discount', '-₹${bill.discountAmount}', font, fontBold),
            _buildInvoiceTotalRow('CGST + SGST / IGST', '₹${bill.taxAmount}', font, fontBold),
            if (bill.roundOff != 0)
              _buildInvoiceTotalRow('Round Off', '₹${bill.roundOff}', font, fontBold),
            pw.Divider(thickness: 1),
            _buildInvoiceTotalRow('Grand Total', '₹${bill.totalAmount}', font, fontBold, isTotal: true, fontSize: 14),
            pw.SizedBox(height: 8),
            pw.Text(
              'Amount in words: ${_amountInWords(bill.totalAmount)}',
              style: pw.TextStyle(font: font, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildInvoiceTotalRow(String label, String value, pw.Font font, pw.Font fontBold,
      {bool isTotal = false, double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: isTotal ? fontBold : font,
              fontSize: fontSize,
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: isTotal ? fontBold : font,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceFooter(Bill bill, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(
          'Thank you for shopping with SS MART!',
          style: pw.TextStyle(font: fontBold, fontSize: 11),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Terms & Conditions Apply | E.& O.E.',
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'This is a computer generated invoice',
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _amountInWords(int amount) {
    // Simplified implementation - in production use a proper library
    return '$amount Rupees Only';
  }

  Future<void> printBill(Bill bill) async {
    final pdfBytes = await generateBillPdf(bill);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Bill_${bill.billNumber}',
    );
  }

  Future<void> shareBill(Bill bill) async {
    final pdfBytes = await generateBillPdf(bill);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Bill_${bill.billNumber}.pdf',
    );
  }

  Future<void> printInvoice(Bill bill) async {
    final pdfBytes = await generateA4InvoicePdf(bill);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${bill.invoiceNumber ?? bill.billNumber}',
    );
  }

  Future<void> shareInvoice(Bill bill) async {
    final pdfBytes = await generateA4InvoicePdf(bill);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${bill.invoiceNumber ?? bill.billNumber}.pdf',
    );
  }
}