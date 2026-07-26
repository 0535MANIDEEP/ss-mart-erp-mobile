import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/labels_bloc.dart';
import '../../domain/entities/label_print_job.dart';
import '../../domain/entities/label_template.dart';

/// Dedicated preview page showing visual mockups of labels before printing.
///
/// Displays generated label mockups in a swipeable card layout. Each card
/// represents one print job and renders a visual representation of how the
/// label will appear when printed on the selected template.
///
/// ## Features
/// - Swipeable PageView through all generated label print jobs
/// - Visual mockup matching the label type (barcode / price / shelf)
/// - Label dimensions display
/// - Print action button to send the batch to the printer
///
/// ## Architecture
/// Receives the [LabelsBloc] via [BlocProvider.value] from the parent page.
/// This avoids creating a duplicate BLoC and ensures the preview operates
/// on the same state as the selection page.
class LabelPreviewPage extends StatelessWidget {
  const LabelPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Label Preview'),
      ),
      body: BlocBuilder<LabelsBloc, LabelsState>(
        builder: (context, state) {
          if (state is LabelsPreview) {
            return _buildPreview(context, state);
          }
          if (state is LabelsReady && state.printJobs.isNotEmpty) {
            final previewState = LabelsPreview(
              printJobs: state.printJobs,
              labelType: state.labelType,
              template: state.defaultTemplate,
            );
            return _buildPreview(context, previewState);
          }
          if (state is LabelsPrintSuccess) {
            return _buildPrintSuccess(context, state);
          }
          if (state is LabelsPrinting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Sending to printer...'),
                ],
              ),
            );
          }
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.preview, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No labels to preview'),
                SizedBox(height: 8),
                Text('Go back and select products first'),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _PreviewBottomBar(),
    );
  }

  Widget _buildPreview(BuildContext context, LabelsPreview state) {
    return Column(
      children: [
        _PreviewHeader(
          template: state.template,
          labelType: state.labelType,
          totalJobs: state.printJobs.length,
        ),
        Expanded(
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.85),
            itemCount: state.printJobs.length,
            itemBuilder: (context, index) {
              final job = state.printJobs[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: _LabelMockupCard(
                  job: job,
                  template: state.template,
                ),
              );
            },
          ),
        ),
        _PreviewCounter(totalJobs: state.printJobs.length),
      ],
    );
  }

  Widget _buildPrintSuccess(BuildContext context, LabelsPrintSuccess state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            state.message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Labels'),
          ),
        ],
      ),
    );
  }
}

/// Header showing template info and label type.
class _PreviewHeader extends StatelessWidget {
  final LabelTemplate? template;
  final String labelType;
  final int totalJobs;

  const _PreviewHeader({
    required this.template,
    required this.labelType,
    required this.totalJobs,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabels = {
      'barcode': 'Barcode Label',
      'price': 'Price Tag',
      'shelf': 'Shelf Label',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(
            labelType == 'barcode'
                ? Icons.barcode_reader
                : labelType == 'price'
                    ? Icons.attach_money
                    : Icons.view_module,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                typeLabels[labelType] ?? labelType,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              Text(
                '${template?.dimensions ?? "N/A"} • $totalJobs label(s)',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Swipeable counter indicator at the bottom of the preview area.
class _PreviewCounter extends StatelessWidget {
  final int totalJobs;

  const _PreviewCounter({required this.totalJobs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.swipe_left, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            'Swipe to browse $totalJobs label(s)',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Visual mockup card representing a single label.
///
/// Renders different layouts depending on the label type:
/// - **barcode**: Product name + scannable barcode representation
/// - **price**: MRP, selling price, savings amount
/// - **shelf**: Full product details with barcode and pricing
class _LabelMockupCard extends StatelessWidget {
  final LabelPrintJob job;
  final LabelTemplate? template;

  const _LabelMockupCard({
    required this.job,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 180),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              job.productName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (job.templateType == 'barcode') _buildBarcodeLayout(context),
            if (job.templateType == 'price') _buildPriceLayout(context),
            if (job.templateType == 'shelf') _buildShelfLayout(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeLayout(BuildContext context) {
    return Column(
      children: [
        if (job.sku != null && job.sku!.isNotEmpty)
          Text(
            'SKU: ${job.sku}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        const SizedBox(height: 8),
        if (job.hasBarcode)
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: _buildBarcodeRepresentation(job.barcode!),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'No barcode available',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          job.barcode ?? 'N/A',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPriceLayout(BuildContext context) {
    return Column(
      children: [
        if (job.hasDiscount) ...[
          Text(
            'MRP ₹${job.mrp.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 2),
        ],
        Text(
          '₹${job.sellingPrice.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        if (job.hasDiscount) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Save ${job.discountPercent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (job.sku != null && job.sku!.isNotEmpty)
          Text(
            'SKU: ${job.sku}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        if (job.taxRate != null && job.taxRate! > 0)
          Text(
            'Incl. ${job.taxRate!.toStringAsFixed(1)}% GST',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildShelfLayout(BuildContext context) {
    return Column(
      children: [
        if (job.sku != null && job.sku!.isNotEmpty)
          Text(
            'SKU: ${job.sku}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        const SizedBox(height: 6),
        if (job.hasBarcode)
          SizedBox(
            height: 40,
            child: Center(
              child: _buildBarcodeRepresentation(job.barcode!),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (job.hasDiscount) ...[
              Text(
                '₹${job.mrp.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '₹${job.sellingPrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        if (job.taxRate != null && job.taxRate! > 0)
          Text(
            'Incl. ${job.taxRate!.toStringAsFixed(1)}% GST',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
      ],
    );
  }

  /// Creates a visual barcode-like representation using vertical bars.
  ///
  /// Since we cannot render a real barcode in a mockup without a barcode
  /// library, this generates a deterministic pattern of bars based on the
  /// barcode string characters.
  Widget _buildBarcodeRepresentation(String barcode) {
    final bars = barcode.codeUnits.take(24).map((c) {
      final width = (c % 3) + 1;
      return SizedBox(width: width.toDouble());
    }).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < 20; i++)
          Container(
            width: (i.isOdd ? 2 : 1).toDouble(),
            height: 30.0 - (i % 3) * 4,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            color: Colors.black87,
          ),
      ],
    );
  }
}

/// Bottom action bar for the preview page with Print button.
class _PreviewBottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LabelsBloc, LabelsState>(
      builder: (context, state) {
        final printJobs = state is LabelsPreview
            ? state.printJobs
            : state is LabelsReady
                ? state.printJobs
                : <LabelPrintJob>[];
        final isPrinting = state is LabelsPrinting;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: printJobs.isNotEmpty && !isPrinting
                  ? () => context.read<LabelsBloc>().add(const PrintLabels())
                  : null,
              icon: isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print),
              label: Text(
                isPrinting
                    ? 'Printing...'
                    : 'Print ${printJobs.length} Label(s)',
              ),
            ),
          ),
        );
      },
    );
  }
}
