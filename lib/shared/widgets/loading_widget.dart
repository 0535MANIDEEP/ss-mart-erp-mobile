import 'package:flutter/material.dart';

/// A reusable loading indicator widget for the SS MART ERP application.
///
/// Displays a centered circular progress indicator with an optional
/// message below it. Used throughout the app for loading states.
///
/// Usage:
/// ```dart
/// LoadingWidget(message: 'Syncing products...')
/// ```
class LoadingWidget extends StatelessWidget {
  /// Optional message displayed below the spinner.
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
