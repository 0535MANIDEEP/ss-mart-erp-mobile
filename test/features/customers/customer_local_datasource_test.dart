import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ss_mart/database/app_database.dart' as db;
import 'package:ss_mart/features/customers/data/datasources/customer_local_datasource.dart';
import 'package:ss_mart/features/customers/domain/entities/customer_entity.dart' as domain;

void main() {
  late db.AppDatabase database;
  late CustomerLocalDataSourceImpl dataSource;

  setUp(() {
    database = db.AppDatabase.test(DatabaseConnection(NativeDatabase.memory()));
    dataSource = CustomerLocalDataSourceImpl(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  domain.Customer testCustomer({
    String id = 'c1',
    String name = 'Test Customer',
    String? phone,
    String type = 'B2C',
    bool isActive = true,
  }) {
    return domain.Customer(
      id: id,
      name: name,
      phone: phone,
      type: type,
      isActive: isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> insertCustomer(domain.Customer customer) async {
    await database.into(database.customers).insert(
          db.CustomersCompanion(
            id: Value(customer.id),
            name: Value(customer.name),
            phone: Value(customer.phone),
            type: Value(customer.type),
            isActive: Value(customer.isActive),
            createdAt: Value(customer.createdAt),
            updatedAt: Value(customer.updatedAt),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  group('CustomerLocalDataSourceImpl', () {
    test('save and get by id', () async {
      final customer = testCustomer();
      await dataSource.saveCustomer(customer);

      final result = await dataSource.getCustomerById('c1');
      expect(result, isNotNull);
      expect(result!.id, 'c1');
      expect(result.name, 'Test Customer');
    });

    test('get by id returns null for nonexistent', () async {
      final result = await dataSource.getCustomerById('nope');
      expect(result, isNull);
    });

    test('get by phone', () async {
      final customer = testCustomer(phone: '9876543210');
      await dataSource.saveCustomer(customer);

      final result = await dataSource.getCustomerByPhone('9876543210');
      expect(result, isNotNull);
      expect(result!.phone, '9876543210');
    });

    test('get customers returns active only', () async {
      await insertCustomer(testCustomer(id: 'c1', isActive: true));
      await insertCustomer(testCustomer(id: 'c2', name: 'C2', isActive: true));
      await insertCustomer(testCustomer(id: 'c3', name: 'C3', isActive: false));

      final results = await dataSource.getCustomers();
      expect(results.length, 2);
    });

    test('search customers by name', () async {
      await insertCustomer(testCustomer(id: 'c1', name: 'John Doe'));
      await insertCustomer(testCustomer(id: 'c2', name: 'Jane Smith'));

      final results = await dataSource.getCustomers(search: 'John');
      expect(results.length, 1);
      expect(results.first.name, 'John Doe');
    });

    test('delete customer', () async {
      await insertCustomer(testCustomer());
      await dataSource.deleteCustomer('c1');

      final result = await dataSource.getCustomerById('c1');
      expect(result, isNull);
    });
  });
}
