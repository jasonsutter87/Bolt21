import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/secure_logger.dart';

/// Secure configuration service for API keys and sensitive config
///
/// API keys should be provided via:
/// 1. Compile-time: --dart-define=BREEZ_API_KEY=xxx
/// 2. Runtime: assets/config.json (for development only)
///
/// NEVER commit API keys to source control
class ConfigService {
  static ConfigService? _instance;
  static ConfigService get instance => _instance ??= ConfigService._();

  ConfigService._();

  String? _breezApiKey;
  bool _isInitialized = false;

  /// Initialize the config service
  /// Must be called before accessing any config values
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Priority 1: Compile-time dart-define (most secure for production)
    const compileTimeKey = String.fromEnvironment('BREEZ_API_KEY');
    if (compileTimeKey.isNotEmpty) {
      _breezApiKey = compileTimeKey;
      _isInitialized = true;
      SecureLogger.info('Loaded API key from compile-time define', tag: 'Config');
      return;
    }

    // Priority 2: Development config file (NEVER include in production builds)
    if (kDebugMode) {
      try {
        final configString = await rootBundle.loadString('assets/config.json');
        // Simple JSON parsing without importing dart:convert in this example
        // In production, use proper JSON parsing
        final keyMatch = RegExp(r'"breez_api_key"\s*:\s*"([^"]+)"').firstMatch(configString);
        if (keyMatch != null) {
          _breezApiKey = keyMatch.group(1);
          _isInitialized = true;
          SecureLogger.info('Loaded API key from dev config', tag: 'Config');
          return;
        }
      } catch (e) {
        SecureLogger.warn('No development config file found', tag: 'Config');
      }
    }

    _isInitialized = true;

    if (_breezApiKey == null) {
      SecureLogger.warn('No Breez API key configured', tag: 'Config');
    }
  }

  /// Get the Breez API key
  /// Throws if not configured
  String get breezApiKey {
    if (!_isInitialized) {
      throw StateError('ConfigService not initialized. Call initialize() first.');
    }
    if (_breezApiKey == null || _breezApiKey!.isEmpty) {
      throw StateError(
        'Breez API key not configured. '
        'Build with --dart-define=BREEZ_API_KEY=YOUR_KEY or '
        'create assets/config.json for development.'
      );
    }
    return _breezApiKey!;
  }

  /// Check if API key is configured
  bool get hasBreezApiKey => _breezApiKey != null && _breezApiKey!.isNotEmpty;
}
