import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ss_mart/database/app_database.dart';

class MockDatabaseDao extends Mock implements DatabaseDao {}

AppDatabase createTestDatabase() =>
    AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));

Future<AppDatabase> setupTestDatabase() async {
  final db = createTestDatabase();
  await db.into(db.products).insert(
        ProductsCompanion.insert(
          id: 'p1',
          name: 'Test Product',
          hsnCode: '1234',
          mrp: 100,
          sellingPrice: 90,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
  return db;
}
