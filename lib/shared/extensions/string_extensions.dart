/// Extension methods on [String] for common string operations in the app.
extension StringExtensions on String {
  /// Returns the string with the first letter capitalized.
  ///
  /// Example: `'hello'` → `'Hello'`
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Returns true if the string is a valid 10-digit Indian phone number.
  ///
  /// Strips spaces, dashes, and '+' characters before validation.
  bool get isValidPhone {
    final cleaned = replaceAll(RegExp(r'[\s\-\+]'), '');
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
  }

  /// Returns true if the string is a valid email address.
  bool get isValidEmail {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(this);
  }

  /// Returns true if the string is a valid Indian GSTIN.
  ///
  /// Format: 2 digits + 5 letters + 4 digits + 1 letter + 1 alphanumeric + Z + 1 alphanumeric.
  bool get isValidGstin {
    return RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$')
        .hasMatch(toUpperCase());
  }

  /// Returns true if the string is a valid Indian PAN.
  ///
  /// Format: 5 letters + 4 digits + 1 letter.
  bool get isValidPan {
    return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(toUpperCase());
  }

  /// Returns true if the string is a valid 6-digit Indian PIN code.
  bool get isValidPincode {
    return RegExp(r'^\d{6}$').hasMatch(this);
  }

  /// Removes all non-numeric characters from the string.
  ///
  /// Example: `'+91 98765 43210'` → `'919876543210'`
  String get digitsOnly => replaceAll(RegExp(r'[^\d]'), '');

  /// Removes all non-alphabetic characters from the string.
  ///
  /// Example: `'ABC-123'` → `'ABC'`
  String get lettersOnly => replaceAll(RegExp(r'[^a-zA-Z]'), '');

  /// Formats as an Indian phone number with a space: `'98765 43210'`
  ///
  /// Only applies formatting if the cleaned string is exactly 10 digits.
  String get formatPhone {
    final d = digitsOnly;
    if (d.length == 10) return '${d.substring(0, 5)} ${d.substring(5)}';
    return this;
  }

  /// Truncates the string with ellipsis if it exceeds [maxLength].
  ///
  /// The resulting string (including `...`) will be at most [maxLength]
  /// characters long.
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - 3)}...';
  }
}
