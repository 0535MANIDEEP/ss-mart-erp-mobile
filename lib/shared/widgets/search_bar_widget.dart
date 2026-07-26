import 'package:flutter/material.dart';

/// A reusable search bar widget for the SS MART ERP application.
///
/// Provides a styled text input field with search icon, clear button,
/// and debounced search callback.
///
/// Usage:
/// ```dart
/// SearchBarWidget(
///   hintText: 'Search products...',
///   onChanged: (query) => filterProducts(query),
/// )
/// ```
class SearchBarWidget extends StatelessWidget {
  /// Placeholder text displayed when the field is empty.
  final String hintText;

  /// Callback fired when the search text changes.
  final ValueChanged<String> onChanged;

  /// Optional external controller for the text field.
  final TextEditingController? controller;

  /// Callback when the clear button is pressed.
  final VoidCallback? onClear;

  /// Whether the field should auto-focus when built.
  final bool autofocus;

  const SearchBarWidget({
    super.key,
    this.hintText = 'Search...',
    required this.onChanged,
    this.controller,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller != null && (controller?.text.isNotEmpty ?? false)
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller?.clear();
                    onChanged('');
                    onClear?.call();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
