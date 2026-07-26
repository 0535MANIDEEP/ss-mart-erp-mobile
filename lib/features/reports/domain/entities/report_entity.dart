import 'package:equatable/equatable.dart';

enum ReportType {
  dailySales,
  monthlySales,
  salesByProduct,
  salesByCategory,
  stockSummary,
  lowStockAlert,
  stockMovement,
  expiryReport,
  topCustomers,
  customerBalance,
  loyaltySummary,
  profitLoss,
  gstReport,
  expenseReport,
  attendanceReport,
  salesByEmployee,
  purchaseSummary,
  supplierWise,
  purchaseVsSales,
  hsnGstSummary,
  gstr1,
  gstr3b,
  paymentSummary,
  commissionSummary,
  agingReport,
}

class ReportData extends Equatable {
  final ReportType type;
  final String title;
  final String description;
  final DateTime generatedAt;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? summary;

  const ReportData({
    required this.type,
    required this.title,
    required this.description,
    required this.generatedAt,
    required this.columns,
    required this.rows,
    this.summary,
  });

  @override
  List<Object?> get props => [
        type,
        title,
        description,
        generatedAt,
        columns,
        rows,
        summary,
      ];
}
