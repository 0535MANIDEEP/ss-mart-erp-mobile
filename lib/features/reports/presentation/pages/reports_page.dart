import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../domain/entities/report_entity.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import 'report_detail_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildReportCard(
            context,
            title: 'Sales Reports',
            icon: Icons.receipt_long,
            color: Colors.green,
            reports: [
              ReportItem('Daily Sales', 'Today\'s transactions', ReportType.dailySales),
              ReportItem('Monthly Sales', 'This month\'s summary', ReportType.monthlySales),
              ReportItem('Sales by Product', 'Product-wise sales', ReportType.salesByProduct),
              ReportItem('Sales by Category', 'Category-wise sales', ReportType.salesByCategory),
            ],
          ),

          _buildReportCard(
            context,
            title: 'Inventory Reports',
            icon: Icons.inventory,
            color: Colors.blue,
            reports: [
              ReportItem('Stock Summary', 'Current stock levels', ReportType.stockSummary),
              ReportItem('Low Stock Alert', 'Items below reorder level', ReportType.lowStockAlert),
              ReportItem('Stock Movement', 'In/out history', ReportType.stockMovement),
              ReportItem('Expiry Report', 'Near-expiry items', ReportType.expiryReport),
            ],
          ),

          _buildReportCard(
            context,
            title: 'Customer Reports',
            icon: Icons.people,
            color: Colors.orange,
            reports: [
              ReportItem('Top Customers', 'By purchase amount', ReportType.topCustomers),
              ReportItem('Customer Balance', 'Outstanding dues', ReportType.customerBalance),
              ReportItem('Loyalty Summary', 'Points earned/redeemed', ReportType.loyaltySummary),
            ],
          ),

          _buildReportCard(
            context,
            title: 'Financial Reports',
            icon: Icons.account_balance_wallet,
            color: Colors.purple,
            reports: [
              ReportItem('Profit & Loss', 'Revenue vs expenses', ReportType.profitLoss),
              ReportItem('GST Report', 'Tax collected/paid', ReportType.gstReport),
              ReportItem('HSN-wise GST Summary', 'HSN-wise tax breakdown for GSTR filing', ReportType.hsnGstSummary),
              ReportItem('Expense Report', 'Category-wise expenses', ReportType.expenseReport),
              ReportItem('GSTR-1', 'Outward supplies for GST filing', ReportType.gstr1),
              ReportItem('GSTR-3B', 'Monthly GST return summary', ReportType.gstr3b),
              ReportItem('Payment Summary', 'Collection and dues', ReportType.paymentSummary),
            ],
          ),

          _buildReportCard(
            context,
            title: 'Commission Reports',
            icon: Icons.attach_money,
            color: Colors.amber,
            reports: [
              ReportItem('Commission Summary', 'Employee-wise commissions', ReportType.commissionSummary),
            ],
          ),

          _buildReportCard(
            context,
            title: 'Employee Reports',
            icon: Icons.badge,
            color: Colors.teal,
            reports: [
              ReportItem('Attendance Report', 'Employee attendance', ReportType.attendanceReport),
              ReportItem('Sales by Employee', 'Individual performance', ReportType.salesByEmployee),
            ],
          ),

          _buildReportCard(
            context,
            title: 'Purchase Reports',
            icon: Icons.shopping_cart,
            color: Colors.indigo,
            reports: [
              ReportItem('Purchase Summary', 'Total purchases', ReportType.purchaseSummary),
              ReportItem('Supplier-wise', 'By supplier', ReportType.supplierWise),
              ReportItem('Purchase vs Sales', 'Margin analysis', ReportType.purchaseVsSales),
            ],
          ),

          const SizedBox(height: 24),

          const Text(
            'Export Reports',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Select a report first, then use the export menu in the report detail view.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export to PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Select a report first, then use the export menu in the report detail view.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Export to Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<ReportItem> reports,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...reports.map((report) => ListTile(
                title: Text(report.name),
                subtitle: Text(report.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<dynamic>(
                      builder: (_) => BlocProvider(
                        create: (_) => GetIt.instance<ReportsBloc>()
                          ..add(LoadReport(type: report.reportType)),
                        child: ReportDetailPage(reportType: report.reportType),
                      ),
                    ),
                  );
                },
              )),
        ],
      ),
    );
  }
}

class ReportItem {
  final String name;
  final String description;
  final ReportType reportType;

  ReportItem(this.name, this.description, this.reportType);
}
