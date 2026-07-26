import 'package:go_router/go_router.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/billing/presentation/pages/billing_page.dart';
import '../features/products/presentation/pages/product_list_page.dart';
import '../features/products/presentation/pages/category_management_page.dart';
import '../features/customers/presentation/pages/customer_list_page.dart';
import '../features/customers/presentation/pages/customer_groups_page.dart';
import '../features/customers/presentation/pages/customer_tags_page.dart';
import '../features/customers/presentation/pages/communication_history_page.dart';
import '../features/inventory/presentation/pages/inventory_page.dart';
import '../features/inventory/presentation/pages/stock_adjustment_page.dart';
import '../features/inventory/presentation/pages/stock_transfer_page.dart';
import '../features/inventory/presentation/pages/physical_count_page.dart';
import '../features/inventory/presentation/pages/stock_audit_trail_page.dart';
import '../features/inventory/presentation/pages/expiry_alert_page.dart';
import '../features/inventory/presentation/pages/expiry_processing_page.dart';
import '../features/inventory/presentation/pages/day_end_page.dart';
import '../features/inventory/presentation/pages/batch_selection_page.dart';
import '../features/employees/presentation/pages/employee_list_page.dart';
import '../features/employees/presentation/pages/attendance_page.dart';
import '../features/employees/presentation/pages/shift_schedule_page.dart';
import '../features/employees/presentation/pages/performance_page.dart';
import '../features/loyalty/presentation/pages/loyalty_page.dart';
import '../features/loyalty/presentation/pages/loyalty_card_management_page.dart';
import '../features/loyalty/presentation/pages/loyalty_rules_config_page.dart';
import '../features/loyalty/presentation/pages/loyalty_adjustment_page.dart';
import '../features/purchases/presentation/pages/purchases_page.dart';
import '../features/purchases/presentation/pages/supplier_list_page.dart';
import '../features/purchases/presentation/pages/supplier_form_page.dart';
import '../features/products/presentation/pages/product_images_page.dart';
import '../features/reports/presentation/pages/reports_page.dart';
import '../features/reports/presentation/pages/custom_report_builder_page.dart';
import '../features/settings/presentation/pages/settings_page.dart' show SettingsPage;
import '../features/settings/presentation/pages/numbering_settings_page.dart';
import '../features/settings/presentation/pages/user_management_page.dart';
import '../features/settings/presentation/pages/permission_control_page.dart';
import '../features/settings/presentation/pages/audit_logs_page.dart';
import '../features/settings/presentation/pages/tax_configuration_page.dart';
import '../features/settings/presentation/pages/backup_restore_page.dart';
import '../features/settings/presentation/pages/printer_settings_page.dart';
import '../features/scanner/presentation/pages/barcode_scanner_page.dart';
import '../features/import_export/presentation/pages/import_export_page.dart';
import '../features/import_export/presentation/pages/import_mapping_page.dart';
import '../features/import_export/presentation/pages/import_preview_page.dart';
import '../features/sync/presentation/pages/sync_page.dart';
import '../features/sync/presentation/pages/sync_logs_page.dart';
import '../features/labels/presentation/pages/labels_page.dart';
import '../features/labels/presentation/pages/label_preview_page.dart';
import '../features/challans/presentation/pages/challans_page.dart';
import '../features/challans/presentation/pages/challan_form_page.dart';
import '../features/challans/presentation/pages/challan_detail_page.dart';
import '../features/accounting/presentation/pages/accounting_page.dart';
import '../features/expenses/presentation/pages/expenses_page.dart';
import '../features/payments/presentation/pages/payments_page.dart';
import '../features/settings/presentation/pages/notification_settings_page.dart';
import '../features/settings/presentation/pages/stores_page.dart';
import '../features/challans/domain/entities/delivery_challan.dart';
import '../features/orders/presentation/pages/orders_page.dart';
import '../features/orders/presentation/pages/order_detail_page.dart';
import '../shared/widgets/main_scaffold.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/billing',
          name: 'billing',
          builder: (context, state) => const BillingPage(),
        ),
        GoRoute(
          path: '/products',
          name: 'products',
          builder: (context, state) => const ProductListPage(),
        ),
        GoRoute(
          path: '/products/categories',
          name: 'categories',
          builder: (context, state) => const CategoryManagementPage(),
        ),
        GoRoute(
          path: '/products/:productId/images',
          name: 'product-images',
          builder: (context, state) {
            final productId = state.pathParameters['productId']!;
            final productName = state.uri.queryParameters['name'] ?? 'Product';
            return ProductImagesPage(productId: productId, productName: productName);
          },
        ),
        GoRoute(
          path: '/customers',
          name: 'customers',
          builder: (context, state) => const CustomerListPage(),
        ),
        GoRoute(
          path: '/customers/groups',
          name: 'customer-groups',
          builder: (context, state) => const CustomerGroupsPage(),
        ),
        GoRoute(
          path: '/customers/tags',
          name: 'customer-tags',
          builder: (context, state) => const CustomerTagsPage(),
        ),
        GoRoute(
          path: '/customers/:customerId/communications',
          name: 'communication-history',
          builder: (context, state) {
            final customerId = state.pathParameters['customerId']!;
            final customerName = state.uri.queryParameters['name'] ?? 'Customer';
            return CommunicationHistoryPage(customerId: customerId, customerName: customerName);
          },
        ),
        GoRoute(
          path: '/inventory',
          name: 'inventory',
          builder: (context, state) => const InventoryPage(),
        ),
        GoRoute(
          path: '/inventory/adjustment',
          name: 'stock-adjustment',
          builder: (context, state) => const StockAdjustmentPage(),
        ),
        GoRoute(
          path: '/inventory/transfer',
          name: 'stock-transfer',
          builder: (context, state) => const StockTransferPage(),
        ),
        GoRoute(
          path: '/inventory/physical-count',
          name: 'physical-count',
          builder: (context, state) => const PhysicalCountPage(),
        ),
        GoRoute(
          path: '/inventory/audit-trail',
          name: 'stock-audit-trail',
          builder: (context, state) => const StockAuditTrailPage(),
        ),
        GoRoute(
          path: '/inventory/expiry-alerts',
          name: 'expiry-alerts',
          builder: (context, state) => const ExpiryAlertPage(),
        ),
        GoRoute(
          path: '/inventory/expiry-processing',
          name: 'expiry-processing',
          builder: (context, state) => const ExpiryProcessingPage(),
        ),
        GoRoute(
          path: '/day-end',
          name: 'day-end',
          builder: (context, state) => const DayEndPage(),
        ),
        GoRoute(
          path: '/inventory/batch-selection',
          name: 'batch-selection',
          builder: (context, state) {
            final productId = state.uri.queryParameters['productId'] ?? '';
            final productName = state.uri.queryParameters['name'] ?? 'Product';
            return BatchSelectionPage(productId: productId, productName: productName);
          },
        ),
        GoRoute(
          path: '/employees',
          name: 'employees',
          builder: (context, state) => const EmployeeListPage(),
        ),
        GoRoute(
          path: '/employees/attendance',
          name: 'attendance',
          builder: (context, state) => const AttendancePage(),
        ),
        GoRoute(
          path: '/employees/shifts',
          name: 'shifts',
          builder: (context, state) => const ShiftSchedulePage(),
        ),
        GoRoute(
          path: '/employees/performance',
          name: 'performance',
          builder: (context, state) => const PerformancePage(),
        ),
        GoRoute(
          path: '/loyalty/:customerId',
          name: 'loyalty',
          builder: (context, state) {
            final customerId = state.pathParameters['customerId']!;
            final customerName = state.uri.queryParameters['name'] ?? 'Customer';
            return LoyaltyPage(customerId: customerId, customerName: customerName);
          },
        ),
        GoRoute(
          path: '/loyalty/cards',
          name: 'loyalty-cards',
          builder: (context, state) => const LoyaltyCardManagementPage(),
        ),
        GoRoute(
          path: '/loyalty/rules',
          name: 'loyalty-rules',
          builder: (context, state) => const LoyaltyRulesConfigPage(),
        ),
        GoRoute(
          path: '/loyalty/adjustment',
          name: 'loyalty-adjustment',
          builder: (context, state) => const LoyaltyAdjustmentPage(),
        ),
        GoRoute(
          path: '/purchases',
          name: 'purchases',
          builder: (context, state) => const PurchasesPage(),
        ),
        GoRoute(
          path: '/suppliers',
          name: 'suppliers',
          builder: (context, state) => const SupplierListPage(),
        ),
        GoRoute(
          path: '/suppliers/new',
          name: 'supplier-new',
          builder: (context, state) => const SupplierFormPage(),
        ),
        GoRoute(
          path: '/suppliers/:supplierId',
          name: 'supplier-detail',
          builder: (context, state) {
            final supplierId = state.pathParameters['supplierId']!;
            return SupplierFormPage(supplierId: supplierId);
          },
        ),
        GoRoute(
          path: '/reports',
          name: 'reports',
          builder: (context, state) => const ReportsPage(),
        ),
        GoRoute(
          path: '/reports/custom',
          name: 'custom-report',
          builder: (context, state) => const CustomReportBuilderPage(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/settings/numbering',
          name: 'numbering-settings',
          builder: (context, state) => const NumberingSettingsPage(),
        ),
        GoRoute(
          path: '/settings/users',
          name: 'user-management',
          builder: (context, state) => const UserManagementPage(),
        ),
        GoRoute(
          path: '/settings/permissions',
          name: 'permission-control',
          builder: (context, state) => const PermissionControlPage(),
        ),
        GoRoute(
          path: '/settings/audit-logs',
          name: 'audit-logs',
          builder: (context, state) => const AuditLogsPage(),
        ),
        GoRoute(
          path: '/settings/tax-configuration',
          name: 'tax-configuration',
          builder: (context, state) => const TaxConfigurationPage(),
        ),
        GoRoute(
          path: '/settings/backup-restore',
          name: 'backup-restore',
          builder: (context, state) => const BackupRestorePage(),
        ),
        GoRoute(
          path: '/import-export',
          name: 'import-export',
          builder: (context, state) => const ImportExportPage(),
        ),
        GoRoute(
          path: '/import-export/mapping',
          name: 'import-mapping',
          builder: (context, state) {
            final entityType = state.uri.queryParameters['type'] ?? 'Products';
            return ImportMappingPage(
              entityType: entityType,
              sourceColumns: const ['Name', 'Price', 'Stock'],
              destinationFields: const ['name', 'sellingPrice', 'currentStock'],
            );
          },
        ),
        GoRoute(
          path: '/import-export/preview',
          name: 'import-preview',
          builder: (context, state) {
            final entityType = state.uri.queryParameters['type'] ?? 'Products';
            return ImportPreviewPage(
              entityType: entityType,
              headers: const [],
              rows: const [],
              mappings: const {},
            );
          },
        ),
        GoRoute(
          path: '/sync',
          name: 'sync',
          builder: (context, state) => const SyncPage(),
        ),
        GoRoute(
          path: '/sync/logs',
          name: 'sync-logs',
          builder: (context, state) => const SyncLogsPage(),
        ),
        GoRoute(
          path: '/labels',
          name: 'labels',
          builder: (context, state) => const LabelsPage(),
        ),
        GoRoute(
          path: '/labels/preview',
          name: 'label-preview',
          builder: (context, state) => const LabelPreviewPage(),
        ),
        GoRoute(
          path: '/barcode-scanner',
          name: 'barcode-scanner',
          builder: (context, state) => const BarcodeScannerPage(),
        ),
        GoRoute(
          path: '/settings/printer',
          name: 'printer-settings',
          builder: (context, state) => const PrinterSettingsPage(),
        ),
        GoRoute(
          path: '/challans',
          name: 'challans',
          builder: (context, state) => const ChallansPage(),
        ),
        GoRoute(
          path: '/challans/new',
          name: 'challan-new',
          builder: (context, state) => const ChallanFormPage(),
        ),
        GoRoute(
          path: '/challans/:id',
          name: 'challan-detail',
          builder: (context, state) {
            final challanId = state.pathParameters['id']!;
            return ChallanDetailPage(
              challan: DeliveryChallan(
                id: challanId,
                challanNumber: state.uri.queryParameters['number'] ?? 'N/A',
                customerId: state.uri.queryParameters['customerId'] ?? '',
                customerName: state.uri.queryParameters['customer'] ?? 'Customer',
                challanDate: DateTime.now(),
                vehicleNumber: state.uri.queryParameters['vehicle'] ?? '',
                driverName: state.uri.queryParameters['driver'] ?? '',
                driverPhone: state.uri.queryParameters['phone'] ?? '',
                status: state.uri.queryParameters['status'] ?? 'pending',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
          },
        ),
        GoRoute(
          path: '/accounting',
          name: 'accounting',
          builder: (context, state) => const AccountingPage(),
        ),
        GoRoute(
          path: '/expenses',
          name: 'expenses',
          builder: (context, state) => const ExpensesPage(),
        ),
        GoRoute(
          path: '/payments',
          name: 'payments',
          builder: (context, state) => const PaymentsPage(),
        ),
        GoRoute(
          path: '/settings/notifications',
          name: 'notification-settings',
          builder: (context, state) => const NotificationSettingsPage(),
        ),
        GoRoute(
          path: '/settings/stores',
          name: 'stores',
          builder: (context, state) => const StoresPage(),
        ),
        GoRoute(
          path: '/orders',
          name: 'orders',
          builder: (context, state) => const OrdersPage(),
        ),
        GoRoute(
          path: '/orders/:orderId',
          name: 'order-detail',
          builder: (context, state) {
            final orderId = state.pathParameters['orderId']!;
            final orderType = state.uri.queryParameters['type'] ?? 'sales';
            return OrderDetailPage(
              orderId: orderId,
              orderType: orderType,
            );
          },
        ),
      ],
    ),
  ],
);
