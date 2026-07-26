import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';

/// Local data source for Supplier entity operations using Drift database.
///
/// Provides CRUD operations for the Suppliers table, enabling offline-first
/// supplier management with local persistence.
abstract class SupplierLocalDataSource {
  Future<List<Supplier>> getAll();
  Future<Supplier?> getById(String id);
  Future<Supplier> create(Map<String, dynamic> data);
  Future<void> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
  Future<List<Supplier>> search(String query);
}

class SupplierLocalDataSourceImpl implements SupplierLocalDataSource {
  final AppDatabase database;
  static const _uuid = Uuid();

  SupplierLocalDataSourceImpl({required this.database});

  @override
  Future<List<Supplier>> getAll() async {
    return await (database.select(database.suppliers)
      ..where((t) => t.isActive.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  @override
  Future<Supplier?> getById(String id) async {
    return await (database.select(database.suppliers)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<Supplier> create(Map<String, dynamic> data) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await database.into(database.suppliers).insert(SuppliersCompanion.insert(
      id: id,
      name: data['name'] as String,
      contactPerson: Value(data['contactPerson'] as String?),
      phone: Value(data['phone'] as String?),
      email: Value(data['email'] as String?),
      address: Value(data['address'] as String?),
      city: Value(data['city'] as String?),
      state: Value(data['state'] as String?),
      pincode: Value(data['pincode'] as String?),
      gstin: Value(data['gstin'] as String?),
      pan: Value(data['pan'] as String?),
      outstandingBalance: Value(data['outstandingBalance'] as int? ?? 0),
      creditDays: Value(data['creditDays'] as int? ?? 30),
      isActive: const Value(true),
      createdAt: now,
      updatedAt: now,
      version: const Value(1),
      syncStatus: const Value('pending'),
    ));
    return (await getById(id))!;
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    final existing = await getById(id);
    if (existing == null) throw Exception('Supplier not found');
    await (database.update(database.suppliers)..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        name: data['name'] != null ? Value(data['name'] as String) : const Value.absent(),
        contactPerson: data['contactPerson'] != null ? Value(data['contactPerson'] as String?) : const Value.absent(),
        phone: data['phone'] != null ? Value(data['phone'] as String?) : const Value.absent(),
        email: data['email'] != null ? Value(data['email'] as String?) : const Value.absent(),
        address: data['address'] != null ? Value(data['address'] as String?) : const Value.absent(),
        city: data['city'] != null ? Value(data['city'] as String?) : const Value.absent(),
        state: data['state'] != null ? Value(data['state'] as String?) : const Value.absent(),
        pincode: data['pincode'] != null ? Value(data['pincode'] as String?) : const Value.absent(),
        gstin: data['gstin'] != null ? Value(data['gstin'] as String?) : const Value.absent(),
        pan: data['pan'] != null ? Value(data['pan'] as String?) : const Value.absent(),
        creditDays: data['creditDays'] != null ? Value(data['creditDays'] as int) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        version: Value(existing.version + 1),
        syncStatus: const Value('pending'),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    await (database.update(database.suppliers)..where((t) => t.id.equals(id))).write(
      const SuppliersCompanion(isActive: Value(false), syncStatus: Value('pending')),
    );
  }

  @override
  Future<List<Supplier>> search(String query) async {
    return await (database.select(database.suppliers)
      ..where((t) => t.name.like('%$query%') | t.contactPerson.like('%$query%') | t.phone.like('%$query%'))
      ..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }
}
