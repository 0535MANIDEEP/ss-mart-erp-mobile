import 'package:flutter/material.dart';

/// A reusable app bar widget with optional action buttons.
///
/// Wraps [AppBar] with consistent styling and optional back button control.
///
/// Usage:
/// ```dart
/// AppBarWidget(
///   title: 'Products',
///   actions: [
///     IconButton(
///       icon: Icon(Icons.filter_list),
///       onPressed: () => showFilter(),
///     ),
///   ],
/// )
/// ```
class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  /// The title text displayed in the center.
  final String title;

  /// Optional action widgets displayed on the right side.
  final List<Widget>? actions;

  /// Whether to automatically show a back button when there's a route above.
  final bool showBackButton;

  const AppBarWidget({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
      automaticallyImplyLeading: showBackButton,
      actions: actions,
    );
  }
}
