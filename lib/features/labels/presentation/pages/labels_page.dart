import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/labels_bloc.dart';
import '../../data/repositories/label_repository_impl.dart';
import '../../../../database/app_database.dart';
import '../../../../injection/injection_container.dart';
import '../../../../shared/widgets/search_bar_widget.dart';
import 'label_preview_page.dart';

/// Main page for the label printing feature.
///
/// Provides a product selection interface where users can:
/// - Search and filter products from the catalog
/// - Select individual products or all products via checkboxes
/// - Choose a label type (barcode, price tag, or shelf label)
/// - Configure the number of label copies per product
/// - Preview generated labels before printing
/// - Print labels via Bluetooth thermal printer or share as PDF
///
/// ## Architecture
/// Uses [BlocProvider] to inject a fresh [LabelsBloc] instance per navigation.
/// The BLoC fetches products from the local database through [LabelRepositoryImpl]
/// and manages selection state entirely on the presentation side.
class LabelsPage extends StatelessWidget {
  const LabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LabelsBloc(
        labelRepository: LabelRepositoryImpl(database: sl<AppDatabase>()),
      )
        ..add(const LoadTemplates())
        ..add(const LoadProducts()),
      child: const _LabelsPageView(),
    );
  }
}

class _LabelsPageView extends StatelessWidget {
  const _LabelsPageView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Labels'),
        actions: [
          BlocBuilder<LabelsBloc, LabelsState>(
            builder: (context, state) {
              if (state is! LabelsReady) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.hasSelection)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: Chip(
                          label: Text('${state.selectedCount} selected'),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      final bloc = context.read<LabelsBloc>();
                      switch (value) {
                        case 'select_all':
                          bloc.add(const SelectAll());
                          break;
                        case 'deselect_all':
                          bloc.add(const DeselectAll());
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'select_all',
                        child: Text('Select All'),
                      ),
                      const PopupMenuItem(
                        value: 'deselect_all',
                        child: Text('Deselect All'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<LabelsBloc, LabelsState>(
        listener: (context, state) {
          if (state is LabelsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state is LabelsPrintSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        buildWhen: (prev, curr) => curr is! LabelsError && curr is! LabelsPrintSuccess,
        builder: (context, state) {
          if (state is LabelsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is LabelsPrinting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Sending labels to printer...'),
                ],
              ),
            );
          }
          if (state is LabelsReady) {
            return _buildReadyView(context, state);
          }
          return const Center(child: Text('Loading...'));
        },
      ),
      bottomNavigationBar: _BottomActionBar(),
    );
  }

  Widget _buildReadyView(BuildContext context, LabelsReady state) {
    return Column(
      children: [
        SearchBarWidget(
          hintText: 'Search products for labels...',
          onChanged: (query) {
            context.read<LabelsBloc>().add(LoadProducts(query: query));
          },
        ),
        _LabelTypeSelector(currentType: state.labelType),
        _QuantitySelector(quantity: state.quantityPerLabel),
        if (state.hasSelection)
          _TemplateInfoBar(
            templateName: state.defaultTemplate?.name ?? 'N/A',
            dimensions: state.defaultTemplate?.dimensions ?? 'N/A',
            totalLabels: state.totalLabelsToPrint,
          ),
        Expanded(
          child: state.products.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.label_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No products found'),
                    ],
                  ),
                )
              : _ProductSelectionList(
                  products: state.products,
                  selectedIds: state.selectedProductIds,
                ),
        ),
      ],
    );
  }
}

/// Horizontal label type selector (barcode / price / shelf).
class _LabelTypeSelector extends StatelessWidget {
  final String currentType;

  const _LabelTypeSelector({required this.currentType});

  @override
  Widget build(BuildContext context) {
    final types = [
      ('barcode', Icons.barcode_reader, 'Barcode'),
      ('price', Icons.attach_money, 'Price Tag'),
      ('shelf', Icons.view_module, 'Shelf Label'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: types.map((t) {
          final isSelected = currentType == t.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.$2, size: 16),
                    const SizedBox(width: 4),
                    Text(t.$3, style: const TextStyle(fontSize: 12)),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) {
                  context.read<LabelsBloc>().add(SetLabelType(labelType: t.$1));
                },
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Quantity per label input with increment/decrement controls.
class _QuantitySelector extends StatelessWidget {
  final int quantity;

  const _QuantitySelector({required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.copy, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Labels per product:', style: TextStyle(fontSize: 14)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: quantity > 1
                ? () => context.read<LabelsBloc>().add(
                      SetQuantity(quantity: quantity - 1),
                    )
                : null,
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: quantity < 999
                ? () => context.read<LabelsBloc>().add(
                      SetQuantity(quantity: quantity + 1),
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

/// Template info bar showing current template details.
class _TemplateInfoBar extends StatelessWidget {
  final String templateName;
  final String dimensions;
  final int totalLabels;

  const _TemplateInfoBar({
    required this.templateName,
    required this.dimensions,
    required this.totalLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.label, size: 16),
          const SizedBox(width: 8),
          Text(templateName, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Text(dimensions, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$totalLabels labels',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable product list with checkbox selection.
class _ProductSelectionList extends StatelessWidget {
  final List<ProductLabelItem> products;
  final Set<String> selectedIds;

  const _ProductSelectionList({
    required this.products,
    required this.selectedIds,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isSelected = selectedIds.contains(product.id);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (_) {
              context.read<LabelsBloc>().add(
                    SelectProduct(productId: product.id),
                  );
            },
            title: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'SKU: ${product.sku ?? 'N/A'} | Barcode: ${product.barcode ?? 'N/A'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            secondary: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${product.sellingPrice}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (product.mrp > product.sellingPrice)
                  Text(
                    'MRP ₹${product.mrp}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bottom action bar with Preview and Print buttons.
class _BottomActionBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LabelsBloc, LabelsState>(
      builder: (context, state) {
        final isReady = state is LabelsReady && state.hasSelection;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isReady
                        ? () {
                            final readyState = state as LabelsReady;
                            context.read<LabelsBloc>().add(const PreviewLabels());
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<LabelsBloc>(),
                                  child: const LabelPreviewPage(),
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isReady
                        ? () => context.read<LabelsBloc>().add(const PrintLabels())
                        : null,
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
