import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/label_template.dart';
import '../../domain/entities/label_print_job.dart';

/// Abstract contract for label data operations.
///
/// The labels feature reads product data from the existing database and
/// transforms it into print-ready [LabelPrintJob] instances. No dedicated
/// database table is required — label generation is a read-and-transform
/// operation over the product catalog.
abstract class LabelRepository {
  /// Returns all active products, optionally filtered by a search [query].
  ///
  /// Products are converted to lightweight summary objects suitable for
  /// display in the label selection list.
  Future<Either<Failure, List<ProductLabelItem>>> getProductsForLabeling({
    String? query,
  });

  /// Generates [LabelPrintJob] instances for the given product IDs.
  ///
  /// Each product is converted into a print job with the specified [templateType]
  /// and default [quantity] of 1 per label.
  Future<Either<Failure, List<LabelPrintJob>>> generatePrintJobs({
    required List<String> productIds,
    required String templateType,
    int quantity = 1,
  });

  /// Returns the built-in set of label templates.
  Future<Either<Failure, List<LabelTemplate>>> getTemplates();
}

/// Lightweight product representation for the label selection UI.
///
/// Contains only the fields needed for label rendering and product
/// identification — avoids pulling full product entities into the BLoC.
class ProductLabelItem {
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final int mrp;
  final int sellingPrice;
  final double taxRate;

  const ProductLabelItem({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    required this.mrp,
    required this.sellingPrice,
    required this.taxRate,
  });
}

/// Local repository that reads product data from the Drift database and
/// generates print jobs without requiring its own database table.
///
/// ## Architecture
/// This repository sits between the BLoC layer and the [AppDatabase]. It:
/// 1. Reads active products via raw database queries.
/// 2. Maps database rows to [ProductLabelItem] for the selection UI.
/// 3. Converts selected products into [LabelPrintJob] instances for printing.
///
/// Label templates are defined as built-in constants since the template
/// set is fixed per deployment and does not require persistence.
class LabelRepositoryImpl implements LabelRepository {
  final AppDatabase _database;

  LabelRepositoryImpl({required AppDatabase database}) : _database = database;

  @override
  Future<Either<Failure, List<ProductLabelItem>>> getProductsForLabeling({
    String? query,
  }) async {
    try {
      final dao = DatabaseDao(_database);
      List<Product> rows;

      if (query != null && query.isNotEmpty) {
        rows = await dao.searchProducts(query, limit: 100);
      } else {
        rows = await dao.getActiveProducts();
      }

      final items = rows
          .map((row) => ProductLabelItem(
                id: row.id,
                name: row.name,
                sku: row.sku,
                barcode: row.barcode,
                mrp: row.mrp,
                sellingPrice: row.sellingPrice,
                taxRate: row.taxRate,
              ))
          .toList();

      return Right(items);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to load products: $e'));
    }
  }

  @override
  Future<Either<Failure, List<LabelPrintJob>>> generatePrintJobs({
    required List<String> productIds,
    required String templateType,
    int quantity = 1,
  }) async {
    try {
      final dao = DatabaseDao(_database);
      final jobs = <LabelPrintJob>[];

      for (final productId in productIds) {
        final product = await dao.getProductById(productId);
        if (product == null) continue;

        jobs.add(LabelPrintJob(
          id: '${productId}_$templateType}_${DateTime.now().millisecondsSinceEpoch}',
          productId: product.id,
          productName: product.name,
          sku: product.sku,
          barcode: product.barcode,
          mrp: product.mrp.toDouble(),
          sellingPrice: product.sellingPrice.toDouble(),
          taxRate: product.taxRate,
          templateType: templateType,
          quantity: quantity,
        ));
      }

      return Right(jobs);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to generate print jobs: $e'));
    }
  }

  @override
  Future<Either<Failure, List<LabelTemplate>>> getTemplates() async {
    try {
      return const Right(_builtinTemplates);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to load templates: $e'));
    }
  }

  /// Built-in label templates for standard retail printing scenarios.
  ///
  /// These templates cover the most common label sizes used in Indian retail:
  /// - 58mm thermal printer labels (barcode + price)
  /// - A4 sheet labels (multiple per page)
  static const List<LabelTemplate> _builtinTemplates = [
    LabelTemplate(
      id: 'barcode_58mm',
      name: '58mm Barcode',
      type: 'barcode',
      width: 58,
      height: 30,
      isDefault: true,
      layout: {'fontSize': 8, 'showBarcode': true, 'showPrice': false},
    ),
    LabelTemplate(
      id: 'barcode_a4',
      name: 'A4 Barcode Sheet',
      type: 'barcode',
      width: 48,
      height: 25,
      layout: {'fontSize': 7, 'showBarcode': true, 'showPrice': false},
    ),
    LabelTemplate(
      id: 'price_58mm',
      name: '58mm Price Tag',
      type: 'price',
      width: 58,
      height: 40,
      isDefault: true,
      layout: {'fontSize': 10, 'showPrice': true, 'showMrp': true, 'showSavings': true},
    ),
    LabelTemplate(
      id: 'price_a4',
      name: 'A4 Price Tag Sheet',
      type: 'price',
      width: 63,
      height: 38,
      layout: {'fontSize': 9, 'showPrice': true, 'showMrp': true, 'showSavings': true},
    ),
    LabelTemplate(
      id: 'shelf_58mm',
      name: '58mm Shelf Label',
      type: 'shelf',
      width: 58,
      height: 50,
      isDefault: true,
      layout: {'fontSize': 9, 'showBarcode': true, 'showPrice': true, 'showMrp': true, 'showSku': true},
    ),
    LabelTemplate(
      id: 'shelf_a4',
      name: 'A4 Shelf Label',
      type: 'shelf',
      width: 100,
      height: 60,
      layout: {'fontSize': 10, 'showBarcode': true, 'showPrice': true, 'showMrp': true, 'showSku': true},
    ),
  ];
}
