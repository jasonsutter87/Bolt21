import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/utils/retry_helper.dart';

void main() {
  group('RetryHelper', () {
    group('withRetry', () {
      test('succeeds on first attempt', () async {
        int attempts = 0;
        final result = await withRetry(
          operation: () async {
            attempts++;
            return 'success';
          },
          operationName: 'test',
        );

        expect(result, equals('success'));
        expect(attempts, equals(1));
      });

      test('retries on failure and succeeds', () async {
        int attempts = 0;
        final result = await withRetry(
          operation: () async {
            attempts++;
            if (attempts < 3) {
              throw SocketException('Network error');
            }
            return 'success';
          },
          config: const RetryConfig(
            maxAttempts: 5,
            initialDelay: Duration(milliseconds: 10),
          ),
          operationName: 'test',
        );

        expect(result, equals('success'));
        expect(attempts, equals(3));
      });

      test('throws after max attempts', () async {
        int attempts = 0;

        await expectLater(
          withRetry(
            operation: () async {
              attempts++;
              throw SocketException('Network error');
            },
            config: const RetryConfig(
              maxAttempts: 3,
              initialDelay: Duration(milliseconds: 10),
            ),
            operationName: 'test',
          ),
          throwsA(isA<SocketException>()),
        );

        expect(attempts, equals(3));
      });

      test('does not retry non-retryable exceptions', () async {
        int attempts = 0;

        await expectLater(
          withRetry(
            operation: () async {
              attempts++;
              throw ArgumentError('Invalid input');
            },
            config: const RetryConfig(
              maxAttempts: 3,
              initialDelay: Duration(milliseconds: 10),
            ),
            operationName: 'test',
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(attempts, equals(1));
      });

      test('respects custom shouldRetry function', () async {
        int attempts = 0;

        await expectLater(
          withRetry(
            operation: () async {
              attempts++;
              throw Exception('Custom error');
            },
            config: RetryConfig(
              maxAttempts: 5,
              initialDelay: const Duration(milliseconds: 10),
              shouldRetry: (e) => e.toString().contains('Custom error'),
            ),
            operationName: 'test',
          ),
          throwsA(isA<Exception>()),
        );

        expect(attempts, equals(5));
      });

      test('retries TimeoutException', () async {
        int attempts = 0;

        await expectLater(
          withRetry(
            operation: () async {
              attempts++;
              throw TimeoutException('Timed out');
            },
            config: const RetryConfig(
              maxAttempts: 2,
              initialDelay: Duration(milliseconds: 10),
            ),
            operationName: 'test',
          ),
          throwsA(isA<TimeoutException>()),
        );

        expect(attempts, equals(2));
      });

      test('retries RetryableException', () async {
        int attempts = 0;

        await expectLater(
          withRetry(
            operation: () async {
              attempts++;
              throw RetryableException('Retry me');
            },
            config: const RetryConfig(
              maxAttempts: 2,
              initialDelay: Duration(milliseconds: 10),
            ),
            operationName: 'test',
          ),
          throwsA(isA<RetryableException>()),
        );

        expect(attempts, equals(2));
      });

      test('applies exponential backoff', () async {
        final delays = <Duration>[];
        var lastTime = DateTime.now();

        try {
          await withRetry(
            operation: () async {
              final now = DateTime.now();
              delays.add(now.difference(lastTime));
              lastTime = now;
              throw SocketException('Network error');
            },
            config: const RetryConfig(
              maxAttempts: 3,
              initialDelay: Duration(milliseconds: 100),
              backoffMultiplier: 2.0,
            ),
            operationName: 'test',
          );
        } catch (_) {}

        // First call has no delay
        // Second delay should be ~100ms
        // Third delay should be ~200ms
        expect(delays.length, equals(3));
        // Second delay should be around initialDelay (100ms), allow tolerance
        expect(delays[1].inMilliseconds, greaterThan(80));
        expect(delays[1].inMilliseconds, lessThan(200));
        // Third delay should be around 200ms (2x initial)
        expect(delays[2].inMilliseconds, greaterThan(150));
      });
    });

    group('withRetryResult', () {
      test('returns success result on success', () async {
        final result = await withRetryResult(
          operation: () async => 42,
          operationName: 'test',
        );

        expect(result.succeeded, isTrue);
        expect(result.value, equals(42));
        expect(result.attemptsMade, equals(1));
        expect(result.error, isNull);
      });

      test('returns failure result on max attempts', () async {
        final result = await withRetryResult(
          operation: () async => throw SocketException('Error'),
          config: const RetryConfig(
            maxAttempts: 2,
            initialDelay: Duration(milliseconds: 10),
          ),
          operationName: 'test',
        );

        expect(result.succeeded, isFalse);
        expect(result.value, isNull);
        expect(result.attemptsMade, equals(2));
        expect(result.error, isA<SocketException>());
      });

      test('tracks attempt count through retries', () async {
        int attempts = 0;
        final result = await withRetryResult(
          operation: () async {
            attempts++;
            if (attempts < 3) {
              throw SocketException('Error');
            }
            return 'success';
          },
          config: const RetryConfig(
            maxAttempts: 5,
            initialDelay: Duration(milliseconds: 10),
          ),
          operationName: 'test',
        );

        expect(result.succeeded, isTrue);
        expect(result.attemptsMade, equals(3));
      });
    });

    group('RetryConfig', () {
      test('defaultConfig has sensible defaults', () {
        const config = RetryConfig.defaultConfig;
        expect(config.maxAttempts, equals(3));
        expect(config.initialDelay, equals(const Duration(seconds: 1)));
        expect(config.backoffMultiplier, equals(2.0));
      });

      test('aggressive config has more attempts', () {
        const config = RetryConfig.aggressive;
        expect(config.maxAttempts, equals(5));
        expect(config.initialDelay, equals(const Duration(milliseconds: 500)));
      });

      test('conservative config has fewer attempts', () {
        const config = RetryConfig.conservative;
        expect(config.maxAttempts, equals(2));
        expect(config.initialDelay, equals(const Duration(seconds: 2)));
      });
    });

    group('RetryableException', () {
      test('stores message and cause', () {
        final cause = Exception('Original error');
        final exception = RetryableException('Wrapped error', cause);

        expect(exception.message, equals('Wrapped error'));
        expect(exception.cause, equals(cause));
        expect(exception.toString(), contains('Wrapped error'));
      });
    });

    group('helper functions', () {
      test('withNetworkRetry uses default config', () async {
        int attempts = 0;
        final result = await withNetworkRetry(
          operation: () async {
            attempts++;
            return 'success';
          },
          operationName: 'test',
        );

        expect(result, equals('success'));
        expect(attempts, equals(1));
      });

      test('withRefreshRetry uses aggressive config', () async {
        int attempts = 0;

        try {
          await withRefreshRetry(
            operation: () async {
              attempts++;
              throw SocketException('Error');
            },
            operationName: 'test',
          );
        } catch (_) {}

        // Aggressive config has 5 max attempts
        expect(attempts, equals(5));
      });
    });
  });
}
