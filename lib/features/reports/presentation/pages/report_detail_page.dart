import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/usecases/export_report_usecase.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import '../bloc/reports_state.dart';

class ReportDetailPage extends StatelessWidget {
  final ReportType reportType;

  const ReportDetailPage({super.key, required this.reportType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(reportType)),
        actions: [
          PopupMenuButton<ExportType>(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export',
            onSelected: (exportType) {
              context.read<ReportsBloc>().add(ExportReport(
                    type: reportType,
                    exportType: exportType,
                  ));
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ExportType.pdf,
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text('Export as PDF'),
                ),
              ),
              const PopupMenuItem(
                value: ExportType.excel,
                child: ListTile(
                  leading: Icon(Icons.table_chart, color: Colors.green),
                  title: Text('Export as Excel (CSV)'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocConsumer<ReportsBloc, ReportsState>(
        listener: (context, state) {
          if (state is ReportExported) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Report exported to: ${state.filePath}'),
                action: SnackBarAction(
                  label: 'OK',
                  onPressed: () {},
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          if (state is ReportsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ReportsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ReportLoaded) {
            return _buildReportContent(context, state.data);
          }

          if (state is ReportsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context
                          .read<ReportsBloc>()
                          .add(LoadReport(type: reportType));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return const Center(child: Text('Select a report to view'));
        },
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, ReportData data) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                data.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(data.generatedAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
        ),
        if (data.summary != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: data.summary!.entries
                  .map((e) => Chip(
                        label: Text(
                          '${e.key}: ${e.value}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ))
                  .toList(),
            ),
          ),
        Expanded(
          child: data.rows.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No data available for this report'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      columns: data.columns
                          .map((col) => DataColumn(
                                label: Text(
                                  col,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ))
                          .toList(),
                      rows: data.rows
                          .map((row) => DataRow(
                                cells: data.columns
                                    .map((col) => DataCell(
                                          Text('${row[col] ?? ''}'),
                                        ))
                                    .toList(),
                              ))
                          .toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  String _getTitle(ReportType type) {
    switch (type) {
      case ReportType.dailySales:
        return 'Daily Sales';
      case ReportType.monthlySales:
        return 'Monthly Sales';
      case ReportType.salesByProduct:
        return 'Sales by Product';
      case ReportType.salesByCategory:
        return 'Sales by Category';
      case ReportType.stockSummary:
        return 'Stock Summary';
      case ReportType.lowStockAlert:
        return 'Low Stock Alert';
      case ReportType.stockMovement:
        return 'Stock Movement';
      case ReportType.expiryReport:
        return 'Expiry Report';
      case ReportType.topCustomers:
        return 'Top Customers';
      case ReportType.customerBalance:
        return 'Customer Balance';
      case ReportType.loyaltySummary:
        return 'Loyalty Summary';
      case ReportType.profitLoss:
        return 'Profit & Loss';
      case ReportType.gstReport:
        return 'GST Report';
      case ReportType.expenseReport:
        return 'Expense Report';
      case ReportType.attendanceReport:
        return 'Attendance Report';
      case ReportType.salesByEmployee:
        return 'Sales by Employee';
      case ReportType.purchaseSummary:
        return 'Purchase Summary';
      case ReportType.supplierWise:
        return 'Supplier-wise';
      case ReportType.purchaseVsSales:
        return 'Purchase vs Sales';
      case ReportType.hsnGstSummary:
        return 'HSN-wise GST Summary';
      case ReportType.gstr1:
        return 'GSTR-1';
      case ReportType.gstr3b:
        return 'GSTR-3B';
      case ReportType.paymentSummary:
        return 'Payment Summary';
      case ReportType.commissionSummary:
        return 'Commission Summary';
      case ReportType.agingReport:
        return 'Aging Report';
    }
  }
}
