// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_dao.dart';

// ignore_for_file: type=lint
mixin _$DatabaseDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProductsTable get products => attachedDatabase.products;
  $CustomersTable get customers => attachedDatabase.customers;
  $BillsTable get bills => attachedDatabase.bills;
  $BillItemsTable get billItems => attachedDatabase.billItems;
  $StockTable get stock => attachedDatabase.stock;
  $LoyaltyTransactionsTable get loyaltyTransactions =>
      attachedDatabase.loyaltyTransactions;
  $EmployeesTable get employees => attachedDatabase.employees;
  $AttendanceTable get attendance => attachedDatabase.attendance;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $PurchaseItemsTable get purchaseItems => attachedDatabase.purchaseItems;
  $SyncQueueTable get syncQueue => attachedDatabase.syncQueue;
  $AuditLogsTable get auditLogs => attachedDatabase.auditLogs;
  $AuthSessionsTable get authSessions => attachedDatabase.authSessions;
  $UserProfilesTable get userProfiles => attachedDatabase.userProfiles;
  $AppSettingsTable get appSettings => attachedDatabase.appSettings;
  $BusinessProfilesTable get businessProfiles =>
      attachedDatabase.businessProfiles;
  $ImportLogsTable get importLogs => attachedDatabase.importLogs;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ShiftsTable get shifts => attachedDatabase.shifts;
  $ShiftSchedulesTable get shiftSchedules => attachedDatabase.shiftSchedules;
  $CustomerGroupsTable get customerGroups => attachedDatabase.customerGroups;
  $CustomerGroupMembersTable get customerGroupMembers =>
      attachedDatabase.customerGroupMembers;
  $CustomerTagsTable get customerTags => attachedDatabase.customerTags;
  $CustomerTagMembersTable get customerTagMembers =>
      attachedDatabase.customerTagMembers;
  $CommunicationHistoryTable get communicationHistory =>
      attachedDatabase.communicationHistory;
  $PhysicalCountsTable get physicalCounts => attachedDatabase.physicalCounts;
  $PhysicalCountItemsTable get physicalCountItems =>
      attachedDatabase.physicalCountItems;
  $StockAuditTrailTable get stockAuditTrail => attachedDatabase.stockAuditTrail;
  $LoyaltyCardsTable get loyaltyCards => attachedDatabase.loyaltyCards;
  $NumberingConfigTable get numberingConfig => attachedDatabase.numberingConfig;
  $ProductImagesTable get productImages => attachedDatabase.productImages;
  $ProductRatesTable get productRates => attachedDatabase.productRates;
  $PartyRatesTable get partyRates => attachedDatabase.partyRates;
  $DiscountRulesTable get discountRules => attachedDatabase.discountRules;
  $SchemeRulesTable get schemeRules => attachedDatabase.schemeRules;
  $BundlePacksTable get bundlePacks => attachedDatabase.bundlePacks;
  $BundlePackItemsTable get bundlePackItems => attachedDatabase.bundlePackItems;
  $InvoiceFormatsTable get invoiceFormats => attachedDatabase.invoiceFormats;
  $BarcodeLabelTemplatesTable get barcodeLabelTemplates =>
      attachedDatabase.barcodeLabelTemplates;
  $ChallansTable get challans => attachedDatabase.challans;
  $ChallanItemsTable get challanItems => attachedDatabase.challanItems;
  $SalesOrdersTable get salesOrders => attachedDatabase.salesOrders;
  $SalesOrderItemsTable get salesOrderItems => attachedDatabase.salesOrderItems;
  $PurchaseOrdersTable get purchaseOrders => attachedDatabase.purchaseOrders;
  $PurchaseOrderItemsTable get purchaseOrderItems =>
      attachedDatabase.purchaseOrderItems;
  $PurchaseDealHistoryTable get purchaseDealHistory =>
      attachedDatabase.purchaseDealHistory;
  DatabaseDaoManager get managers => DatabaseDaoManager(this);
}

class DatabaseDaoManager {
  final _$DatabaseDaoMixin _db;
  DatabaseDaoManager(this._db);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$BillsTableTableManager get bills =>
      $$BillsTableTableManager(_db.attachedDatabase, _db.bills);
  $$BillItemsTableTableManager get billItems =>
      $$BillItemsTableTableManager(_db.attachedDatabase, _db.billItems);
  $$StockTableTableManager get stock =>
      $$StockTableTableManager(_db.attachedDatabase, _db.stock);
  $$LoyaltyTransactionsTableTableManager get loyaltyTransactions =>
      $$LoyaltyTransactionsTableTableManager(
          _db.attachedDatabase, _db.loyaltyTransactions);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db.attachedDatabase, _db.employees);
  $$AttendanceTableTableManager get attendance =>
      $$AttendanceTableTableManager(_db.attachedDatabase, _db.attendance);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db.attachedDatabase, _db.purchases);
  $$PurchaseItemsTableTableManager get purchaseItems =>
      $$PurchaseItemsTableTableManager(_db.attachedDatabase, _db.purchaseItems);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db.attachedDatabase, _db.syncQueue);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db.attachedDatabase, _db.auditLogs);
  $$AuthSessionsTableTableManager get authSessions =>
      $$AuthSessionsTableTableManager(_db.attachedDatabase, _db.authSessions);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db.attachedDatabase, _db.userProfiles);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db.attachedDatabase, _db.appSettings);
  $$BusinessProfilesTableTableManager get businessProfiles =>
      $$BusinessProfilesTableTableManager(
          _db.attachedDatabase, _db.businessProfiles);
  $$ImportLogsTableTableManager get importLogs =>
      $$ImportLogsTableTableManager(_db.attachedDatabase, _db.importLogs);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ShiftsTableTableManager get shifts =>
      $$ShiftsTableTableManager(_db.attachedDatabase, _db.shifts);
  $$ShiftSchedulesTableTableManager get shiftSchedules =>
      $$ShiftSchedulesTableTableManager(
          _db.attachedDatabase, _db.shiftSchedules);
  $$CustomerGroupsTableTableManager get customerGroups =>
      $$CustomerGroupsTableTableManager(
          _db.attachedDatabase, _db.customerGroups);
  $$CustomerGroupMembersTableTableManager get customerGroupMembers =>
      $$CustomerGroupMembersTableTableManager(
          _db.attachedDatabase, _db.customerGroupMembers);
  $$CustomerTagsTableTableManager get customerTags =>
      $$CustomerTagsTableTableManager(_db.attachedDatabase, _db.customerTags);
  $$CustomerTagMembersTableTableManager get customerTagMembers =>
      $$CustomerTagMembersTableTableManager(
          _db.attachedDatabase, _db.customerTagMembers);
  $$CommunicationHistoryTableTableManager get communicationHistory =>
      $$CommunicationHistoryTableTableManager(
          _db.attachedDatabase, _db.communicationHistory);
  $$PhysicalCountsTableTableManager get physicalCounts =>
      $$PhysicalCountsTableTableManager(
          _db.attachedDatabase, _db.physicalCounts);
  $$PhysicalCountItemsTableTableManager get physicalCountItems =>
      $$PhysicalCountItemsTableTableManager(
          _db.attachedDatabase, _db.physicalCountItems);
  $$StockAuditTrailTableTableManager get stockAuditTrail =>
      $$StockAuditTrailTableTableManager(
          _db.attachedDatabase, _db.stockAuditTrail);
  $$LoyaltyCardsTableTableManager get loyaltyCards =>
      $$LoyaltyCardsTableTableManager(_db.attachedDatabase, _db.loyaltyCards);
  $$NumberingConfigTableTableManager get numberingConfig =>
      $$NumberingConfigTableTableManager(
          _db.attachedDatabase, _db.numberingConfig);
  $$ProductImagesTableTableManager get productImages =>
      $$ProductImagesTableTableManager(_db.attachedDatabase, _db.productImages);
  $$ProductRatesTableTableManager get productRates =>
      $$ProductRatesTableTableManager(_db.attachedDatabase, _db.productRates);
  $$PartyRatesTableTableManager get partyRates =>
      $$PartyRatesTableTableManager(_db.attachedDatabase, _db.partyRates);
  $$DiscountRulesTableTableManager get discountRules =>
      $$DiscountRulesTableTableManager(_db.attachedDatabase, _db.discountRules);
  $$SchemeRulesTableTableManager get schemeRules =>
      $$SchemeRulesTableTableManager(_db.attachedDatabase, _db.schemeRules);
  $$BundlePacksTableTableManager get bundlePacks =>
      $$BundlePacksTableTableManager(_db.attachedDatabase, _db.bundlePacks);
  $$BundlePackItemsTableTableManager get bundlePackItems =>
      $$BundlePackItemsTableTableManager(
          _db.attachedDatabase, _db.bundlePackItems);
  $$InvoiceFormatsTableTableManager get invoiceFormats =>
      $$InvoiceFormatsTableTableManager(
          _db.attachedDatabase, _db.invoiceFormats);
  $$BarcodeLabelTemplatesTableTableManager get barcodeLabelTemplates =>
      $$BarcodeLabelTemplatesTableTableManager(
          _db.attachedDatabase, _db.barcodeLabelTemplates);
  $$ChallansTableTableManager get challans =>
      $$ChallansTableTableManager(_db.attachedDatabase, _db.challans);
  $$ChallanItemsTableTableManager get challanItems =>
      $$ChallanItemsTableTableManager(_db.attachedDatabase, _db.challanItems);
  $$SalesOrdersTableTableManager get salesOrders =>
      $$SalesOrdersTableTableManager(_db.attachedDatabase, _db.salesOrders);
  $$SalesOrderItemsTableTableManager get salesOrderItems =>
      $$SalesOrderItemsTableTableManager(
          _db.attachedDatabase, _db.salesOrderItems);
  $$PurchaseOrdersTableTableManager get purchaseOrders =>
      $$PurchaseOrdersTableTableManager(
          _db.attachedDatabase, _db.purchaseOrders);
  $$PurchaseOrderItemsTableTableManager get purchaseOrderItems =>
      $$PurchaseOrderItemsTableTableManager(
          _db.attachedDatabase, _db.purchaseOrderItems);
  $$PurchaseDealHistoryTableTableManager get purchaseDealHistory =>
      $$PurchaseDealHistoryTableTableManager(
          _db.attachedDatabase, _db.purchaseDealHistory);
}
