/// Database layer for the SS Mart ERP mobile application.
///
/// This file defines the complete SQLite schema using the Drift (formerly Moor)
/// ORM framework. It contains all table definitions and the main database class.
///
/// ## Architecture
///
/// The database is structured around these major domains:
///
/// - **Product Catalog**: [Products], [Stock] — master data for inventory items
///   and per-location stock quantities with batch/expiry tracking.
/// - **Sales**: [Bills], [BillItems] — transactional sales records and their
///   line items. Supports returns via [Bills.isReturn] + [Bills.referenceBillId].
/// - **Purchases**: [Purchases], [PurchaseItems] — supplier purchase orders
///   and their line items.
/// - **Customers & Loyalty**: [Customers], [LoyaltyTransactions] — customer
///   master data with a loyalty points earn/redeem ledger.
/// - **Suppliers**: [Suppliers] — vendor master data with credit terms.
/// - **Workforce**: [Employees], [Attendance] — staff roster and daily
///   clock-in/out records.
/// - **Auth & Users**: [AuthSessions], [UserProfiles] — JWT session storage
///   and user profile data.
/// - **Sync & Audit**: [SyncQueue], [AuditLogs] — offline-first sync queue
///   for pending mutations and immutable audit trail entries.
/// - **Config**: [AppSettings], [BusinessProfiles] — key-value app settings
///   and business entity master data.
/// - **Import**: [ImportLogs] — tracks bulk data import jobs with rollback
///   capability.
///
/// ## Schema Decisions
///
/// - All primary keys are UUID strings (generated client-side) to support
///   offline-first operation without auto-increment conflicts.
/// - Every mutable entity carries `version` (optimistic concurrency) and
///   `syncStatus` (pending/in_sync/failed) columns for the sync engine.
/// - Monetary values are stored as **integer paise** (not floating point)
///   to avoid rounding errors. Divide by 100 for display.
/// - Dates are stored as SQLite TEXT in ISO-8601 via Drift's DateTimeColumn.
/// - The database file is lazily opened from the app's documents directory
///   as `ss_mart.sqlite` using [NativeDatabase] for performance.
///
/// ## Testing
///
/// The [AppDatabase.test] constructor accepts an external [DatabaseConnection]
/// to allow injection of in-memory databases for unit and integration tests.
library;

export 'database_dao.dart';
export 'package:drift/drift.dart' show Value, InsertMode;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'app_database.g.dart';

/// Master product catalog table.
///
/// Stores every sellable/stockable item the business trades in. Each product
/// has pricing at three levels: [mrp] (maximum retail price), [sellingPrice]
/// (current sale price), and [purchasePrice] (cost price from supplier).
///
/// The [currentStock] column is denormalized from the [Stock] table for fast
/// POS lookups; the canonical stock lives in [Stock] per-location.
///
/// [syncStatus] tracks whether the local row has been pushed to the server.
/// [version] is used for optimistic concurrency during sync merges.
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get hsnCode => text()();
  TextColumn get unit => text().withDefault(const Constant('PCS'))();
  RealColumn get packSize => real().withDefault(const Constant(1.0))();
  IntColumn get mrp => integer()();
  IntColumn get sellingPrice => integer()();
  IntColumn get purchasePrice => integer().nullable()();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  TextColumn get taxType => text().withDefault(const Constant('GST'))();
  TextColumn get categoryId => text().nullable()();
  TextColumn get supplierId => text().nullable()();
  IntColumn get reorderLevel => integer().withDefault(const Constant(10))();
  IntColumn get currentStock => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customer master data table.
///
/// Holds contact information, GSTIN (for B2B invoicing), credit terms,
/// and loyalty program state. The [type] column distinguishes B2B vs B2C
/// customers, which affects invoice formatting and tax handling.
///
/// [currentBalance] tracks outstanding credit (positive = customer owes us).
/// [loyaltyPoints] is the denormalized running total; the authoritative
/// ledger is in [LoyaltyTransactions].
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get state => text().nullable()();
  TextColumn get pincode => text().nullable()();
  TextColumn get gstin => text().nullable()();
  TextColumn get type => text().withDefault(const Constant('B2C'))();
  IntColumn get creditLimit => integer().withDefault(const Constant(0))();
  IntColumn get currentBalance => integer().withDefault(const Constant(0))();
  IntColumn get loyaltyPoints => integer().withDefault(const Constant(0))();
  TextColumn get loyaltyCardNumber => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sales invoice / bill header table.
///
/// Each row represents one completed (or returned) sales transaction. The
/// [isReturn] flag plus [referenceBillId] form a self-referencing link that
/// ties a return bill back to the original sale.
///
/// Financial columns:
/// - [subtotal] — sum of line-item totals before tax/discount
/// - [taxAmount] — total GST collected on this bill
/// - [discountAmount] — any bill-level discount
/// - [roundOff] — rounding adjustment (typically -1, 0, or +1 paise)
/// - [totalAmount] — final payable (subtotal + tax - discount + roundOff)
/// - [paidAmount] / [dueAmount] — payment tracking for credit sales
///
/// [paymentMode] records how the customer paid (CASH, UPI, CARD, CREDIT, etc.).
/// [status] progresses through: pending → completed → cancelled.
class Bills extends Table {
  TextColumn get id => text()();
  TextColumn get billNumber => text()();
  TextColumn get invoiceNumber => text().nullable()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().nullable()();
  DateTimeColumn get billDate => dateTime()();
  IntColumn get subtotal => integer()();
  IntColumn get taxAmount => integer().withDefault(const Constant(0))();
  IntColumn get discountAmount => integer().withDefault(const Constant(0))();
  IntColumn get roundOff => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer()();
  IntColumn get paidAmount => integer().withDefault(const Constant(0))();
  IntColumn get dueAmount => integer().withDefault(const Constant(0))();
  TextColumn get paymentMode => text().withDefault(const Constant('CASH'))();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  BoolColumn get isReturn => boolean().withDefault(const Constant(false))();
  TextColumn get referenceBillId => text().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Line-item detail rows for a sales bill.
///
/// Each row represents one product sold on a particular [Bills] transaction,
/// identified by [billId]. Product data is partially denormalized ([productName])
/// to preserve historical accuracy even if the product master is later edited.
///
/// [quantity] is a real to support fractional units (e.g., 1.5 kg).
/// [batchNumber] is optional and used for items with batch/lot tracking.
class BillItems extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
  IntColumn get unitPrice => integer()();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  IntColumn get discountAmount => integer().withDefault(const Constant(0))();
  IntColumn get taxAmount => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer()();
  TextColumn get batchNumber => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-location inventory stock levels.
///
/// Tracks physical stock for a product at a specific warehouse/store location.
/// Supports batch-level tracking via [batchNumber] and [expiryDate] for
/// perishable goods (FIFO expiry management).
///
/// [reservedQuantity] holds stock committed to pending orders but not yet
/// dispatched. Available stock = [quantity] - [reservedQuantity].
///
/// The default [locationId] of 'MAIN' represents the primary store/warehouse.
class Stock extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text().withDefault(const Constant(''))();
  TextColumn get locationId => text().withDefault(const Constant('MAIN'))();
  IntColumn get quantity => integer()();
  IntColumn get reservedQuantity => integer().withDefault(const Constant(0))();
  TextColumn get batchNumber => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Loyalty points earn/redeem ledger.
///
/// An append-only ledger that records every loyalty points movement for a
/// customer. [transactionType] is either 'earn' or 'redeem'. The customer's
/// current balance is computed as SUM(earn points) - SUM(redeem points).
///
/// [referenceType] + [referenceId] optionally link the transaction back to
/// the originating entity (e.g., a bill that triggered the earn).
/// [expiryDate] supports point expiration policies.
class LoyaltyTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get customerName => text().withDefault(const Constant(''))();
  TextColumn get transactionType => text()();
  IntColumn get points => integer()();
  TextColumn get referenceType => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Employee / staff roster table.
///
/// Stores basic employee info and their [role] (e.g., 'cashier', 'manager',
/// 'stock_clerk'). The [pin] field is used for quick POS login authentication.
///
/// Only active employees ([isActive] = true) appear in selection dropdowns
/// and attendance screens.
class Employees extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get role => text().withDefault(const Constant('cashier'))();
  TextColumn get pin => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Employee daily attendance / time-tracking table.
///
/// Records clock-in and clock-out times for each employee on a given date.
/// [status] can be 'present', 'absent', 'half_day', or 'leave'.
/// [notes] allows free-text justification (e.g., "late due to traffic").
///
/// One row per employee per day; [attendanceDate] is date-only (time component
/// is ignored for daily grouping).
class Attendance extends Table {
  TextColumn get id => text()();
  TextColumn get employeeId => text()();
  DateTimeColumn get attendanceDate => dateTime()();
  DateTimeColumn get clockIn => dateTime().nullable()();
  DateTimeColumn get clockOut => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('present'))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Supplier / vendor master data table.
///
/// Stores vendor contact details, GSTIN/PAN for tax compliance, and credit
/// terms. [outstandingBalance] tracks how much we owe this supplier.
/// [creditDays] defines the payment window (e.g., 30 = Net-30).
class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get state => text().nullable()();
  TextColumn get pincode => text().nullable()();
  TextColumn get gstin => text().nullable()();
  TextColumn get pan => text().nullable()();
  IntColumn get outstandingBalance => integer().withDefault(const Constant(0))();
  IntColumn get creditDays => integer().withDefault(const Constant(30))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Supplier purchase order header table.
///
/// Records a purchase transaction from a [Suppliers] vendor. Line items
/// are stored in [PurchaseItems] linked by [purchaseId].
///
/// [status] progresses through: pending → received → cancelled.
/// Financial columns mirror [Bills] but represent costs rather than revenue.
class Purchases extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseNumber => text()();
  TextColumn get supplierId => text().nullable()();
  TextColumn get supplierName => text().nullable()();
  DateTimeColumn get purchaseDate => dateTime()();
  IntColumn get subtotal => integer()();
  IntColumn get taxAmount => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Line-item detail rows for a supplier purchase order.
///
/// Each row represents one product purchased, linked to [Purchases] via
/// [purchaseId]. [batchNumber] is recorded here so received stock can be
/// tracked at the batch level in [Stock].
class PurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseId => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
  IntColumn get unitPrice => integer()();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  IntColumn get taxAmount => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer()();
  TextColumn get batchNumber => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Offline-first sync queue for pending mutations.
///
/// Every local create/update/delete is enqueued here as a serialized [payload]
/// along with the [entityType] and [entityId] it affects. The sync engine
/// processes items in FIFO order ([createdAt] ascending).
///
/// [operation] is one of: 'create', 'update', 'delete'.
/// [status] transitions: pending → syncing → completed / failed.
/// Failed items are retried up to [maxRetries] times; the last [error]
/// message is preserved for diagnostics.
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(3))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get error => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Immutable audit trail for data changes.
///
/// Records who ([userId]) did what ([action]) to which entity
/// ([entityType]/[entityId]), with before/after snapshots ([oldValue]/[newValue]).
/// Used for compliance, debugging, and rollback capabilities.
///
/// [ipAddress] and [deviceId] provide forensic context.
/// This table is append-only; rows are never updated or deleted.
class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get action => text()();
  TextColumn get entityType => text().nullable()();
  TextColumn get entityId => text().nullable()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  TextColumn get ipAddress => text().nullable()();
  TextColumn get deviceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// JWT authentication session storage.
///
/// Stores access and refresh tokens for the currently logged-in user.
/// [status] is 'active' or 'inactive'; [deactivateAllSessions] is called
/// on logout or password change.
///
/// [deviceId] ties the session to a specific physical device for security.
/// [expiresAt] is checked on app resume to trigger silent token refresh.
class AuthSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text()();
  DateTimeColumn get expiresAt => dateTime()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User profile data (cached from server).
///
/// Stores the user's display name, email, phone, role, and avatar URL.
/// [jsonMetadata] is an extensible JSON blob for future custom fields
/// without requiring schema migrations.
///
/// This is distinct from [Employees] — UserProfiles is the auth-level
/// identity, while Employees is the business-level HR record.
class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().nullable()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get role => text().withDefault(const Constant('cashier'))();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get jsonMetadata => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key-value application settings store.
///
/// A generic key-value table for persisting app configuration such as
/// business hours, tax rates, printer settings, feature flags, etc.
///
/// [valueType] ('string', 'int', 'bool', 'json') hints at serialization
/// format. All values are stored as text; the caller is responsible for
/// parsing based on [valueType].
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  TextColumn get valueType => text().withDefault(const Constant('string'))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Business entity master data.
///
/// Stores the legal entity details (company name, GSTIN, PAN, address)
/// that appear on printed invoices and GST returns. Supports multi-business
/// profiles via [isActive] toggle.
class BusinessProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get companyName => text()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get state => text().nullable()();
  TextColumn get pincode => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get gstin => text().nullable()();
  TextColumn get pan => text().nullable()();
  TextColumn get logoUrl => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bulk data import job tracking.
///
/// Records each bulk import operation (e.g., CSV product upload) with its
/// [jobId], [entityType], and row count. [canRollback] indicates whether
/// the import supports undo (used with [AuditLogs] for rollback).
///
/// [error] captures any failure message. [completedAt] is null while the
/// import is still in progress.
class ImportLogs extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text()();
  TextColumn get entityType => text()();
  TextColumn get action => text()();
  IntColumn get rowCount => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get canRollback => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Product category master table.
///
/// Organizes products into logical groups for reporting, filtering,
/// and pricing. Categories are hierarchical but stored flat in this
/// implementation (no parent-child relationship in v1).
///
/// [name] must be unique within the store. [sortOrder] controls display
/// ordering in category selection dropdowns.
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get colorCode => text().withDefault(const Constant('#4CAF50'))();
  TextColumn get iconName => text().withDefault(const Constant('category'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Employee shift definition table.
///
/// Defines reusable shift templates (e.g., "Morning 9AM-5PM") that
/// can be assigned to employees via [ShiftSchedules]. Each shift has
/// a fixed start/end time and optional break configuration.
class Shifts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  TextColumn get breakMinutes => text().withDefault(const Constant('60'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Employee shift assignment table.
///
/// Links an [Employees] row to a [Shifts] template for a specific date.
/// One employee can have only one shift per day (enforced at application level).
class ShiftSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get employeeId => text()();
  TextColumn get shiftId => text()();
  DateTimeColumn get scheduleDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customer segmentation group table.
///
/// Groups customers into logical segments (e.g., "Wholesale", "VIP",
/// "Regular") for bulk pricing, targeted marketing, and reporting.
/// A customer can belong to multiple groups via [CustomerGroupMembers].
class CustomerGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get discountType => text().withDefault(const Constant('percentage'))();
  RealColumn get discountValue => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customer-to-group mapping table.
///
/// Many-to-many junction between [Customers] and [CustomerGroups].
/// A single customer can belong to multiple groups.
class CustomerGroupMembers extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get groupId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customer tagging table for ad-hoc labeling.
///
/// Provides flexible, user-defined tags (e.g., "festive-offer",
/// "high-priority", "referral-source") that can be applied to customers
/// for filtering and segmentation without formal group structures.
class CustomerTags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get colorCode => text().withDefault(const Constant('#FF9800'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customer-to-tag mapping table.
///
/// Many-to-many junction between [Customers] and [CustomerTags].
class CustomerTagMembers extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get tagId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customer communication log table.
///
/// Records every customer touchpoint (calls, SMS, WhatsApp, email)
/// for CRM purposes. [communicationType] is one of: 'call', 'sms',
/// 'whatsapp', 'email', 'visit'. [outcome] captures the result
/// (e.g., "interested", "no-answer", "follow-up-needed").
class CommunicationHistory extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get communicationType => text()();
  TextColumn get subject => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get outcome => text().nullable()();
  TextColumn get performedBy => text()();
  DateTimeColumn get communicationDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Physical stock count / stocktake record header.
///
/// Represents one physical count session. Items are stored in
/// [PhysicalCountItems]. [status] progresses: draft → in_progress →
/// completed → reconciled. Supports multi-location counting.
class PhysicalCounts extends Table {
  TextColumn get id => text()();
  TextColumn get countNumber => text()();
  TextColumn get locationId => text().withDefault(const Constant('MAIN'))();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get notes => text().nullable()();
  TextColumn get performedBy => text()();
  DateTimeColumn get countDate => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Physical stock count line items.
///
/// Each row represents a counted product within a [PhysicalCounts] session.
/// [systemQuantity] is the expected quantity from [Stock]; [countedQuantity]
/// is the actual physically counted value. [variance] = counted - system.
class PhysicalCountItems extends Table {
  TextColumn get id => text()();
  TextColumn get physicalCountId => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text().withDefault(const Constant(''))();
  IntColumn get systemQuantity => integer()();
  IntColumn get countedQuantity => integer()();
  IntColumn get variance => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Inventory audit trail for stock changes.
///
/// Records every stock-affecting operation (sale, purchase, adjustment,
/// transfer, physical count) with before/after snapshots for forensic
/// auditing and inventory reconciliation.
class StockAuditTrail extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text().withDefault(const Constant(''))();
  TextColumn get operationType => text()();
  TextColumn get referenceType => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  IntColumn get quantityBefore => integer()();
  IntColumn get quantityChange => integer()();
  IntColumn get quantityAfter => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get performedBy => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Physical/digital loyalty card tracking table.
///
/// Manages loyalty card lifecycle: issuance, activation, blocking,
/// and transfer. Each card has a unique [cardNumber] and is linked
/// to a [Customers] row. [status] is one of: 'active', 'blocked',
/// 'expired', 'pending'.
class LoyaltyCards extends Table {
  TextColumn get id => text()();
  TextColumn get cardNumber => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get cardType => text().withDefault(const Constant('standard'))();
  DateTimeColumn get issuedDate => dateTime()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Invoice/bill numbering configuration.
///
/// Stores the next sequence number for each document type (bill, purchase,
/// etc.) with customizable prefix and format. Enables configurable
/// invoice numbering per business requirement.
class NumberingConfig extends Table {
  TextColumn get id => text()();
  TextColumn get documentType => text()();
  TextColumn get prefix => text().withDefault(const Constant('BILL'))();
  IntColumn get nextSequence => integer().withDefault(const Constant(1))();
  TextColumn get format => text().withDefault(const Constant('PREFIX-YYYYMMDD-NNNN'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Product image storage table.
///
/// Stores one or more image URLs per product. [isPrimary] marks the
/// main display image. [sortOrder] controls gallery ordering.
class ProductImages extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get imageUrl => text()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Main Drift database class for the SS Mart ERP application.
///
/// This class registers all 32 tables and provides the migration strategy.
/// It extends the generated `_$AppDatabase` which provides the table
/// accessors, DAOs, and query builders.
///
/// ## Construction
///
/// - **[AppDatabase()]** — Production constructor. Lazily opens the SQLite
///   file at `<app_documents_dir>/ss_mart.sqlite` using [NativeDatabase]
///   for background-thread performance. This is the normal entry point.
/// - **[AppDatabase.test(connection)]** — Test constructor. Accepts an
///   externally provided [DatabaseConnection] (typically an in-memory
///   database) so unit/integration tests can run without touching the
///   filesystem and can be isolated per test case.
///
/// ## Migration
///
/// Currently at schema version 2. The [MigrationStrategy] creates all
/// tables on first run via [onCreate]. [onUpgrade] handles migrations
/// from v1 to v2 (adds imageUrl column to Products and creates 14 new
/// tables).
@DriftDatabase(tables: [
  Products,
  Customers,
  Bills,
  BillItems,
  Stock,
  LoyaltyTransactions,
  Employees,
  Attendance,
  Suppliers,
  Purchases,
  PurchaseItems,
  SyncQueue,
  AuditLogs,
  AuthSessions,
  UserProfiles,
  AppSettings,
  BusinessProfiles,
  ImportLogs,
  Categories,
  Shifts,
  ShiftSchedules,
  CustomerGroups,
  CustomerGroupMembers,
  CustomerTags,
  CustomerTagMembers,
  CommunicationHistory,
  PhysicalCounts,
  PhysicalCountItems,
  StockAuditTrail,
  LoyaltyCards,
  NumberingConfig,
  ProductImages,
])
class AppDatabase extends _$AppDatabase {
  /// Production constructor — opens the on-disk SQLite database.
  AppDatabase() : super(_openConnection());

  /// Test constructor — accepts an injected [DatabaseConnection] for
  /// deterministic, isolated testing without filesystem side effects.
  AppDatabase.test(DatabaseConnection super.connection);

  /// Current database schema version. Increment this when adding/removing
  /// columns or tables, and add a migration step in [migration].
  @override
  int get schemaVersion => 2;

  /// Migration strategy for schema lifecycle management.
  ///
  /// [onCreate] runs on first install — creates all tables defined in
  /// the [DriftDatabase] annotation. [onUpgrade] handles schema migrations:
  /// - v1 → v2: Adds [imageUrl] column to [Products] and creates 14 new
  ///   tables (Categories, Shifts, ShiftSchedules, CustomerGroups,
  ///   CustomerGroupMembers, CustomerTags, CustomerTagMembers,
  ///   CommunicationHistory, PhysicalCounts, PhysicalCountItems,
  ///   StockAuditTrail, LoyaltyCards, NumberingConfig, ProductImages).
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Add imageUrl column to Products table
            await m.addColumn(products, products.imageUrl);

            // Create all new v2 tables
            await m.createTable(categories);
            await m.createTable(shifts);
            await m.createTable(shiftSchedules);
            await m.createTable(customerGroups);
            await m.createTable(customerGroupMembers);
            await m.createTable(customerTags);
            await m.createTable(customerTagMembers);
            await m.createTable(communicationHistory);
            await m.createTable(physicalCounts);
            await m.createTable(physicalCountItems);
            await m.createTable(stockAuditTrail);
            await m.createTable(loyaltyCards);
            await m.createTable(numberingConfig);
            await m.createTable(productImages);
          }
        },
      );
}

/// Lazily initializes the SQLite database connection.
///
/// Uses [LazyDatabase] so the actual file I/O only happens on the first
/// query, not at app startup. The database file is stored in the platform's
/// application documents directory as `ss_mart.sqlite`.
///
/// [NativeDatabase.createInBackground] offloads file operations to a
/// background isolate to avoid blocking the UI thread.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ss_mart.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
