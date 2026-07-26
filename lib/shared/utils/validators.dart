/// Reusable form validation utilities for the SS MART ERP application.
///
/// All validators return null on success (valid input) or a human-readable
/// error message on failure (invalid input). This matches the Flutter
/// [TextFormField.validator] contract.
///
/// Usage:
/// ```dart
/// TextFormField(
///   validator: Validators.required('Name is required'),
/// )
/// ```
class Validators {
  Validators._();

  /// Validates that the field is not empty.
  ///
  /// [message] is the error message displayed on validation failure.
  /// Defaults to 'This field is required'.
  static String? Function(String?) required([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message ?? 'This field is required';
      }
      return null;
    };
  }

  /// Validates an Indian phone number (10 digits starting with 6-9).
  ///
  /// Accepts numbers with optional country code (+91), spaces, or dashes.
  /// Defaults to 'Enter a valid 10-digit Indian phone number'.
  static String? Function(String?) phone([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message ?? 'Phone number is required';
      }
      final cleaned = value.replaceAll(RegExp(r'[\s\-\+]'), '');
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
        return message ?? 'Enter a valid 10-digit Indian phone number';
      }
      return null;
    };
  }

  /// Validates an email address format.
  ///
  /// Returns null if the field is empty (email is optional unless combined
  /// with [required]). Defaults to 'Enter a valid email address'.
  static String? Function(String?) email([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(value.trim())) {
        return message ?? 'Enter a valid email address';
      }
      return null;
    };
  }

  /// Validates an Indian GSTIN (Goods and Services Tax Identification Number).
  ///
  /// Format: 2 digits + 5 letters + 4 digits + 1 letter + 1 alphanumeric + Z + 1 alphanumeric.
  /// Returns null if empty (optional field).
  static String? Function(String?) gstin([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      final cleaned = value.trim().toUpperCase();
      if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$').hasMatch(cleaned)) {
        return message ?? 'Enter a valid GSTIN (e.g., 27AAPFU0939F1ZV)';
      }
      return null;
    };
  }

  /// Validates an Indian PAN (Permanent Account Number).
  ///
  /// Format: 5 letters + 4 digits + 1 letter.
  /// Returns null if empty (optional field).
  static String? Function(String?) pan([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      final cleaned = value.trim().toUpperCase();
      if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(cleaned)) {
        return message ?? 'Enter a valid PAN (e.g., AAPFU0939F)';
      }
      return null;
    };
  }

  /// Validates an Indian PIN code (4-6 digits).
  ///
  /// Returns a required error if empty, format error if invalid.
  static String? Function(String?) pin([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message ?? 'PIN is required';
      }
      if (value.trim().length < 4 || value.trim().length > 6) {
        return message ?? 'PIN must be 4-6 digits';
      }
      if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
        return message ?? 'PIN must contain only digits';
      }
      return null;
    };
  }

  /// Validates minimum string length.
  ///
  /// Returns null if the field is empty (combine with [required] if needed).
  static String? Function(String?) minLength(int min, [String? message]) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      if (value.length < min) {
        return message ?? 'Minimum $min characters required';
      }
      return null;
    };
  }

  /// Validates maximum string length.
  ///
  /// Returns null if the field is empty (combine with [required] if needed).
  static String? Function(String?) maxLength(int max, [String? message]) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      if (value.length > max) {
        return message ?? 'Maximum $max characters allowed';
      }
      return null;
    };
  }

  /// Validates that the input is a positive number.
  ///
  /// Returns null if empty (optional field). Uses [num.tryParse] for
  /// locale-independent number parsing.
  static String? Function(String?) positiveNumber([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      final num? parsed = num.tryParse(value.trim());
      if (parsed == null || parsed <= 0) {
        return message ?? 'Enter a valid positive number';
      }
      return null;
    };
  }

  /// Validates a barcode value (minimum 8 characters).
  ///
  /// Returns null if empty (optional field).
  static String? Function(String?) barcode([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      if (value.trim().length < 8) {
        return message ?? 'Barcode must be at least 8 characters';
      }
      return null;
    };
  }

  /// Validates an Indian PIN code (6 digits).
  ///
  /// Returns null if empty (optional field).
  static String? Function(String?) pincode([String? message]) {
    return (value) {
      if (value == null || value.trim().isEmpty) return null;
      if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
        return message ?? 'Enter a valid 6-digit pincode';
      }
      return null;
    };
  }
}
