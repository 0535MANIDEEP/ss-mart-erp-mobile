import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ss_mart/database/app_database.dart' as db;
import 'package:ss_mart/features/products/data/datasources/product_local_datasource.dart';
import 'package:ss_mart/features/products/domain/entities/product_entity.dart' as domain;

void main() {
  late db.AppDatabase database;
  late ProductLocalDataSourceImpl dataSource;

  setUp(() {
    database = db.AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
    dataSource = ProductLocalDataSourceImpl(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  domain.Product testProduct({
    String id = 'p1',
    String name = 'Test Product',
    String? barcode,
    String? categoryId,
    bool isActive = true,
  }) {
    return domain.Product(
      id: id,
      name: name,
      hsnCode: '1234',
      mrp: 100,
      sellingPrice: 90,
      barcode: barcode,
      categoryId: categoryId,
      isActive: isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> insertProduct(domain.Product product) async {
    await database.into(database.products).insert(
          db.ProductsCompanion(
            id: Value(product.id),
            name: Value(product.name),
            hsnCode: Value(product.hsnCode),
            mrp: Value(product.mrp),
            sellingPrice: Value(product.sellingPrice),
            barcode: Value(product.barcode),
            categoryId: Value(product.categoryId),
            isActive: Value(product.isActive),
            createdAt: Value(product.createdAt),
            updatedAt: Value(product.updatedAt),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  group('ProductLocalDataSourceImpl', () {
    test('save and get by id', () async {
      final product = testProduct();
      await dataSource.saveProduct(product);

      final result = await dataSource.getProductById('p1');
      expect(result, isNotNull);
      expect(result!.id, 'p1');
      expect(result.name, 'Test Product');
    });

    test('get by id returns null for nonexistent', () async {
      final result = await dataSource.getProductById('nope');
      expect(result, isNull);
    });

    test('get by barcode', () async {
      final product = testProduct(barcode: '123456789');
      await dataSource.saveProduct(product);

      final result = await dataSource.getProductByBarcode('123456789');
      expect(result, isNotNull);
      expect(result!.barcode, '123456789');
    });

    test('get products returns active only', () async {
      await insertProduct(testProduct(id: 'p1', isActive: true));
      await insertProduct(testProduct(id: 'p2', name: 'P2', isActive: true));
      await insertProduct(testProduct(id: 'p3', name: 'P3', isActive: false));

      final results = await dataSource.getProducts();
      expect(results.length, 2);
    });

    test('search products by name', () async {
      await insertProduct(testProduct(id: 'p1', name: 'Apple Juice'));
      await insertProduct(testProduct(id: 'p2', name: 'Banana Juice'));

      final results = await dataSource.getProducts(search: 'Apple');
      expect(results.length, 1);
      expect(results.first.name, 'Apple Juice');
    });

    test('delete product', () async {
      await insertProduct(testProduct());
      await dataSource.deleteProduct('p1');

      final result = await dataSource.getProductById('p1');
      expect(result, isNull);
    });
  });
}
