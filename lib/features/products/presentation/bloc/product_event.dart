part of 'product_bloc.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object> get props => [];
}

class LoadProducts extends ProductEvent {
  const LoadProducts();
}

class SearchProducts extends ProductEvent {
  final String query;

  const SearchProducts({required this.query});

  @override
  List<Object> get props => [query];
}

/// Event to load a single product by its unique identifier.
class LoadProductById extends ProductEvent {
  final String productId;

  const LoadProductById({required this.productId});

  @override
  List<Object> get props => [productId];
}

/// Event to create a new product in the system.
class CreateProduct extends ProductEvent {
  final Product product;

  const CreateProduct({required this.product});

  @override
  List<Object> get props => [product];
}

/// Event to update an existing product record.
class UpdateProduct extends ProductEvent {
  final Product product;

  const UpdateProduct({required this.product});

  @override
  List<Object> get props => [product];
}

/// Event to soft-delete a product by its identifier.
class DeleteProduct extends ProductEvent {
  final String productId;

  const DeleteProduct({required this.productId});

  @override
  List<Object> get props => [productId];
}
