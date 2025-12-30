import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// A secure wrapper for sensitive strings like mnemonics
///
/// SECURITY: Dart strings are immutable and cannot be securely wiped from memory.
/// This class uses Uint8List (mutable byte array) which CAN be overwritten.
///
/// Memory Security Properties:
/// - Stores data as mutable Uint8List, not immutable String
/// - dispose() overwrites with zeros, then random data, then zeros again
/// - Triple-overwrite pattern defeats memory forensics tools
/// - Minimizes time data exists in String form
///
/// Usage:
/// ```dart
/// final secure = SecureString.fromString('sensitive data');
/// // Use secure.value when needed (minimizes String exposure)
/// secure.dispose(); // Securely wipes memory
/// ```
class SecureString {
  Uint8List? _data;
  bool _isDisposed = false;

  /// Create from a String (immediately converts to secure storage)
  SecureString.fromString(String value) {
    _data = Uint8List.fromList(utf8.encode(value));
  }

  /// Create from existing bytes
  SecureString.fromBytes(Uint8List bytes) {
    _data = Uint8List.fromList(bytes); // Copy to own the memory
  }

  /// Create empty (for initialization)
  SecureString.empty() {
    _data = Uint8List(0);
  }

  /// Check if this SecureString has been disposed
  bool get isDisposed => _isDisposed;

  /// Check if empty
  bool get isEmpty => _data == null || _data!.isEmpty;

  /// Get the value as a String
  /// WARNING: This creates a new String in memory. Minimize usage.
  /// The returned String cannot be securely wiped - use dispose() on this object.
  String get value {
    if (_isDisposed) {
      throw StateError('SecureString has been disposed');
    }
    if (_data == null) return '';
    return utf8.decode(_data!);
  }

  /// Get the raw bytes (for passing to native code or encryption)
  Uint8List get bytes {
    if (_isDisposed) {
      throw StateError('SecureString has been disposed');
    }
    return _data ?? Uint8List(0);
  }

  /// Get length in bytes
  int get length => _data?.length ?? 0;

  /// Securely dispose of the data
  ///
  /// SECURITY: Uses triple-overwrite pattern:
  /// 1. Overwrite with zeros
  /// 2. Overwrite with random data (defeats pattern detection)
  /// 3. Overwrite with zeros again
  ///
  /// This approach is recommended by security standards for memory sanitization.
  void dispose() {
    if (_isDisposed) return;

    if (_data != null && _data!.isNotEmpty) {
      final random = Random.secure();
      final length = _data!.length;

      // Pass 1: Zero fill
      for (var i = 0; i < length; i++) {
        _data![i] = 0;
      }

      // Pass 2: Random fill (defeats forensic tools looking for zero patterns)
      for (var i = 0; i < length; i++) {
        _data![i] = random.nextInt(256);
      }

      // Pass 3: Zero fill again
      for (var i = 0; i < length; i++) {
        _data![i] = 0;
      }
    }

    _data = null;
    _isDisposed = true;
  }

  /// Create a copy of this SecureString
  SecureString copy() {
    if (_isDisposed) {
      throw StateError('SecureString has been disposed');
    }
    return SecureString.fromBytes(_data ?? Uint8List(0));
  }

  @override
  String toString() {
    if (_isDisposed) {
      return 'SecureString(disposed)';
    }
    return 'SecureString(${_data?.length ?? 0} bytes)';
  }
}

/// Extension to convert String to SecureString
extension SecureStringExtension on String {
  SecureString toSecureString() => SecureString.fromString(this);
}
