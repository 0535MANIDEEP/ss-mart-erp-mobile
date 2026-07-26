import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';

/// Local data source for Category entity operations using Drift database.
abstract class CategoryLocalDataSource {
  Future<List<Category>> getAll();
  Future<List<Category>> getActive();
  Future<Category?> getById(String id);
  Future<Category> create(Map<String, dynamic> data);
  Future<void> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
  Future<List<Category>> search(String query);
}

class CategoryLocalDataSourceImpl implements CategoryLocalDataSource {
  final AppDatabase database;
  static const _uuid = Uuid();

  CategoryLocalDataSourceImpl({required this.database});

  @override
  Future<List<Category>> getAll() async => (database.select(database.categories)
    ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  @override
  Future<List<Category>> getActive() async => (database.select(database.categories)
    ..where((t) => t.isActive.equals(true))
    ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  @override
  Future<Category?> getById(String id) async => (database.select(database.categories)
    ..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Future<Category> create(Map<String, dynamic> data) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await database.into(database.categories).insert(CategoriesCompanion.insert(
      id: id,
      name: data['name'] as String,
      description: Value(data['description'] as String?),
      colorCode: Value(data['colorCode'] as String? ?? '#4CAF50'),
      iconName: Value(data['iconName'] as String? ?? 'category'),
      sortOrder: Value(data['sortOrder'] as int? ?? 0),
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
    if (existing == null) throw Exception('Category not found');
    await (database.update(database.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        name: data['name'] != null ? Value(data['name'] as String) : const Value.absent(),
        description: data['description'] != null ? Value(data['description'] as String?) : const Value.absent(),
        colorCode: data['colorCode'] != null ? Value(data['colorCode'] as String) : const Value.absent(),
        sortOrder: data['sortOrder'] != null ? Value(data['sortOrder'] as int) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        version: Value(existing.version + 1),
        syncStatus: const Value('pending'),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    await (database.update(database.categories)..where((t) => t.id.equals(id))).write(
      const CategoriesCompanion(isActive: Value(false), syncStatus: Value('pending')),
    );
  }

  @override
  Future<List<Category>> search(String query) async =>
    (database.select(database.categories)..where((t) => t.name.like('%$query%'))).get();
}
