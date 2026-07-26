import 'package:flutter_test/flutter_test.dart';
import 'package:ss_mart/database/app_database.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('In-memory AppDatabase', () {
    late AppDatabase db;

    setUp(() async {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('can insert and retrieve a product', () async {
      final dao = DatabaseDao(db);
      await dao.insertProduct(ProductsCompanion.insert(
        id: 'test-1',
        name: 'Smoke Test Product',
        hsnCode: '0000',
        mrp: 50,
        sellingPrice: 45,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final product = await dao.getProductById('test-1');
      expect(product, isNotNull);
      expect(product!.name, 'Smoke Test Product');
    });

    test('schema version is 1', () {
      expect(db.schemaVersion, 1);
    });
  });
}
