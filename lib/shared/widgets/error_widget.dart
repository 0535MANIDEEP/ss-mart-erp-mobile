import 'package:flutter/material.dart';

/// A reusable error state widget for the SS MART ERP application.
///
/// Displays an error icon, title, message, and a retry button.
/// Used in bloc error states throughout the app.
///
/// Usage:
/// ```dart
/// AppErrorWidget(
///   title: 'Failed to load products',
///   message: 'Check your internet connection',
///   onRetry: () => context.read<ProductBloc>().add(LoadProducts()),
/// )
/// ```
class AppErrorWidget extends StatelessWidget {
  /// The primary error title text.
  final String title;

  /// Optional detailed error message.
  final String? message;

  /// Callback when the retry button is pressed. Null hides the button.
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
