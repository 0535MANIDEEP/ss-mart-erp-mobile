import 'package:flutter/material.dart';
import '../../core/config/theme.dart';

/// Extension methods on [BuildContext] for convenient access to theme,
/// navigation, and responsive sizing utilities.
extension BuildContextExtensions on BuildContext {
  /// The current [ThemeData] from the widget tree.
  ThemeData get theme => Theme.of(this);

  /// The current [ColorScheme] derived from the theme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// The current [TextTheme] derived from the theme.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// The current [MediaQueryData] for responsive layout decisions.
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// The current screen width in logical pixels.
  double get screenWidth => mediaQuery.size.width;

  /// The current screen height in logical pixels.
  double get screenHeight => mediaQuery.size.height;

  /// Returns true if the screen width is less than 600px (phone).
  bool get isMobile => screenWidth < 600;

  /// Returns true if the screen width is between 600px and 1200px (tablet).
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;

  /// Returns true if the screen width is 1200px or more (desktop).
  bool get isDesktop => screenWidth >= 1200;

  /// Shows a success (green) [SnackBar] with the given [message].
  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.successColor),
    );
  }

  /// Shows an error (red) [SnackBar] with the given [message].
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  /// Shows an info (green accent) [SnackBar] with the given [message].
  void showInfoSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.secondaryColor),
    );
  }
}
