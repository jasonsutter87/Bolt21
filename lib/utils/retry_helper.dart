import 'dart:async';
import 'dart:io';
import 'secure_logger.dart';

/// Exception indicating a retryable network error
class RetryableException implements Exception {
  final String message;
  final Exception? cause;

  RetryableException(this.message, [this.cause]);

  @override
  String toString() => 'RetryableException: $message';
}

/// Configuration for retry behavior
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool Function(Exception)? shouldRetry;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.shouldRetry,
  });

  static const RetryConfig defaultConfig = RetryConfig();

  static const RetryConfig aggressive = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 500),
    backoffMultiplier: 1.5,
  );

  static const RetryConfig conservative = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 2),
    backoffMultiplier: 2.0,
  );
}

/// Result of a retry operation
class RetryResult<T> {
  final T? value;
  final Exception? error;
  final int attemptsMade;
  final bool succeeded;

  RetryResult._({
    this.value,
    this.error,
    required this.attemptsMade,
    required this.succeeded,
  });

  factory RetryResult.success(T value, int attempts) => RetryResult._(
        value: value,
        attemptsMade: attempts,
        succeeded: true,
      );

  factory RetryResult.failure(Exception error, int attempts) => RetryResult._(
        error: error,
        attemptsMade: attempts,
        succeeded: false,
      );
}

/// Execute an async operation with exponential backoff retry
Future<T> withRetry<T>({
  required Future<T> Function() operation,
  RetryConfig config = RetryConfig.defaultConfig,
  String? operationName,
}) async {
  int attempt = 0;
  Duration currentDelay = config.initialDelay;

  while (true) {
    attempt++;
    try {
      return await operation();
    } catch (e) {
      final exception = e is Exception ? e : Exception(e.toString());

      // Check if we should retry
      final shouldRetry = _shouldRetry(exception, config.shouldRetry);

      if (!shouldRetry || attempt >= config.maxAttempts) {
        SecureLogger.error(
            '${operationName ?? 'Operation'} failed after $attempt attempt(s)',
            tag: 'Retry');
        rethrow;
      }

      SecureLogger.warn(
          '${operationName ?? 'Operation'} attempt $attempt failed, retrying in ${currentDelay.inMilliseconds}ms',
          tag: 'Retry');

      await Future.delayed(currentDelay);

      // Calculate next delay with backoff
      currentDelay = Duration(
        milliseconds:
            (currentDelay.inMilliseconds * config.backoffMultiplier).toInt(),
      );

      // Cap at max delay
      if (currentDelay > config.maxDelay) {
        currentDelay = config.maxDelay;
      }
    }
  }
}

/// Execute with retry and return detailed result
Future<RetryResult<T>> withRetryResult<T>({
  required Future<T> Function() operation,
  RetryConfig config = RetryConfig.defaultConfig,
  String? operationName,
}) async {
  int attempt = 0;
  Duration currentDelay = config.initialDelay;
  Exception? lastError;

  while (attempt < config.maxAttempts) {
    attempt++;
    try {
      final result = await operation();
      return RetryResult.success(result, attempt);
    } catch (e) {
      lastError = e is Exception ? e : Exception(e.toString());

      final shouldRetry = _shouldRetry(lastError, config.shouldRetry);

      if (!shouldRetry || attempt >= config.maxAttempts) {
        SecureLogger.error(
            '${operationName ?? 'Operation'} failed after $attempt attempt(s)',
            tag: 'Retry');
        return RetryResult.failure(lastError, attempt);
      }

      SecureLogger.warn(
          '${operationName ?? 'Operation'} attempt $attempt failed, retrying in ${currentDelay.inMilliseconds}ms',
          tag: 'Retry');

      await Future.delayed(currentDelay);

      currentDelay = Duration(
        milliseconds:
            (currentDelay.inMilliseconds * config.backoffMultiplier).toInt(),
      );

      if (currentDelay > config.maxDelay) {
        currentDelay = config.maxDelay;
      }
    }
  }

  return RetryResult.failure(lastError ?? Exception('Unknown error'), attempt);
}

/// Check if an exception is retryable
bool _shouldRetry(Exception e, bool Function(Exception)? customCheck) {
  // Use custom check if provided
  if (customCheck != null) {
    return customCheck(e);
  }

  // Default retryable exceptions
  if (e is SocketException) return true;
  if (e is TimeoutException) return true;
  if (e is HttpException) return true;
  if (e is RetryableException) return true;

  // Check error message for common network issues
  final message = e.toString().toLowerCase();
  if (message.contains('timeout')) return true;
  if (message.contains('connection')) return true;
  if (message.contains('network')) return true;
  if (message.contains('socket')) return true;
  if (message.contains('unreachable')) return true;

  return false;
}

/// Helper to wrap network operations with standard retry
Future<T> withNetworkRetry<T>({
  required Future<T> Function() operation,
  String? operationName,
}) {
  return withRetry(
    operation: operation,
    config: RetryConfig.defaultConfig,
    operationName: operationName,
  );
}

/// Helper for balance/info refresh with more aggressive retry
Future<T> withRefreshRetry<T>({
  required Future<T> Function() operation,
  String? operationName,
}) {
  return withRetry(
    operation: operation,
    config: RetryConfig.aggressive,
    operationName: operationName,
  );
}
