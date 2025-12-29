import 'package:flutter_test/flutter_test.dart';
import 'package:bolt21/utils/formatters.dart';

void main() {
  group('Formatters', () {
    // ==================== formatSats TESTS ====================
    group('formatSats', () {
      test('formats 0 sats', () {
        expect(formatSats(0), equals('0 sats'));
      });

      test('formats single digit sats', () {
        expect(formatSats(1), equals('1 sats'));
        expect(formatSats(5), equals('5 sats'));
        expect(formatSats(9), equals('9 sats'));
      });

      test('formats double digit sats', () {
        expect(formatSats(10), equals('10 sats'));
        expect(formatSats(50), equals('50 sats'));
        expect(formatSats(99), equals('99 sats'));
      });

      test('formats triple digit sats', () {
        expect(formatSats(100), equals('100 sats'));
        expect(formatSats(500), equals('500 sats'));
        expect(formatSats(999), equals('999 sats'));
      });

      test('formats 1000+ sats with commas', () {
        expect(formatSats(1000), equals('1,000 sats'));
        expect(formatSats(1234), equals('1,234 sats'));
        expect(formatSats(9999), equals('9,999 sats'));
      });

      test('formats 10000+ sats with commas', () {
        expect(formatSats(10000), equals('10,000 sats'));
        expect(formatSats(12345), equals('12,345 sats'));
        expect(formatSats(99999), equals('99,999 sats'));
      });

      test('formats 100000+ sats with commas', () {
        expect(formatSats(100000), equals('100,000 sats'));
        expect(formatSats(123456), equals('123,456 sats'));
        expect(formatSats(999999), equals('999,999 sats'));
      });

      test('formats 1M+ sats with commas', () {
        expect(formatSats(1000000), equals('1,000,000 sats'));
        expect(formatSats(1234567), equals('1,234,567 sats'));
        expect(formatSats(9999999), equals('9,999,999 sats'));
      });

      test('formats 10M+ sats with commas', () {
        expect(formatSats(10000000), equals('10,000,000 sats'));
        expect(formatSats(12345678), equals('12,345,678 sats'));
        expect(formatSats(99999999), equals('99,999,999 sats'));
      });

      test('formats 1 BTC (100M sats) in BTC', () {
        expect(formatSats(100000000), equals('1.00000000 BTC'));
      });

      test('formats >1 BTC in BTC', () {
        expect(formatSats(150000000), equals('1.50000000 BTC'));
        expect(formatSats(200000000), equals('2.00000000 BTC'));
        expect(formatSats(123456789), equals('1.23456789 BTC'));
      });

      test('formats 10+ BTC in BTC', () {
        expect(formatSats(1000000000), equals('10.00000000 BTC'));
        expect(formatSats(2100000000000000), equals('21000000.00000000 BTC'));
      });

      test('formats typical Ocean payout amounts', () {
        expect(formatSats(2000), equals('2,000 sats'));
        expect(formatSats(5000), equals('5,000 sats'));
        expect(formatSats(10000), equals('10,000 sats'));
      });
    });

    // ==================== formatSatsCompact TESTS ====================
    group('formatSatsCompact', () {
      test('formats 0 sats', () {
        expect(formatSatsCompact(0), equals('0 sats'));
      });

      test('formats small amounts without abbreviation', () {
        expect(formatSatsCompact(1), equals('1 sats'));
        expect(formatSatsCompact(100), equals('100 sats'));
        expect(formatSatsCompact(999), equals('999 sats'));
      });

      test('formats 1k+ as k sats', () {
        expect(formatSatsCompact(1000), equals('1.0k sats'));
        expect(formatSatsCompact(1500), equals('1.5k sats'));
        expect(formatSatsCompact(2000), equals('2.0k sats'));
      });

      test('formats 10k+ as k sats', () {
        expect(formatSatsCompact(10000), equals('10.0k sats'));
        expect(formatSatsCompact(15000), equals('15.0k sats'));
        expect(formatSatsCompact(99999), equals('100.0k sats'));
      });

      test('formats 100k+ as k sats', () {
        expect(formatSatsCompact(100000), equals('100.0k sats'));
        expect(formatSatsCompact(500000), equals('500.0k sats'));
        expect(formatSatsCompact(999999), equals('1000.0k sats'));
      });

      test('formats 1M+ as M sats', () {
        expect(formatSatsCompact(1000000), equals('1.0M sats'));
        expect(formatSatsCompact(1500000), equals('1.5M sats'));
        expect(formatSatsCompact(9999999), equals('10.0M sats'));
      });

      test('formats 10M+ as M sats', () {
        expect(formatSatsCompact(10000000), equals('10.0M sats'));
        expect(formatSatsCompact(50000000), equals('50.0M sats'));
        expect(formatSatsCompact(99999999), equals('100.0M sats'));
      });

      test('formats 1 BTC as BTC', () {
        expect(formatSatsCompact(100000000), equals('1.00 BTC'));
      });

      test('formats >1 BTC as BTC', () {
        expect(formatSatsCompact(150000000), equals('1.50 BTC'));
        expect(formatSatsCompact(210000000), equals('2.10 BTC'));
      });

      test('formats large BTC amounts', () {
        expect(formatSatsCompact(1000000000), equals('10.00 BTC'));
        expect(formatSatsCompact(2100000000000000), equals('21000000.00 BTC'));
      });
    });

    // ==================== truncateMiddle TESTS ====================
    group('truncateMiddle', () {
      test('returns short strings unchanged', () {
        expect(truncateMiddle('abc'), equals('abc'));
        expect(truncateMiddle('short'), equals('short'));
        expect(truncateMiddle('1234567890123456789'), equals('1234567890123456789'));
      });

      test('truncates long strings', () {
        final long = 'abcdefghijklmnopqrstuvwxyz';
        expect(truncateMiddle(long), equals('abcdefgh...stuvwxyz'));
      });

      test('truncates with custom start length', () {
        final long = 'abcdefghijklmnopqrstuvwxyz';
        expect(truncateMiddle(long, start: 4), equals('abcd...stuvwxyz'));
      });

      test('truncates with custom end length', () {
        final long = 'abcdefghijklmnopqrstuvwxyz';
        expect(truncateMiddle(long, end: 4), equals('abcdefgh...wxyz'));
      });

      test('truncates with custom start and end', () {
        final long = 'abcdefghijklmnopqrstuvwxyz';
        expect(truncateMiddle(long, start: 4, end: 4), equals('abcd...wxyz'));
      });

      test('handles exact boundary length', () {
        // start=8, end=8, ellipsis=3 → 19 chars boundary
        final exact = '1234567890123456789'; // 19 chars
        expect(truncateMiddle(exact), equals(exact)); // No truncation needed
      });

      test('truncates at boundary + 1', () {
        final overBoundary = '12345678901234567890'; // 20 chars
        expect(truncateMiddle(overBoundary), equals('12345678...34567890'));
      });

      test('handles Bitcoin addresses', () {
        final address = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
        expect(truncateMiddle(address), equals('bc1qar0s...zzwf5mdq'));
      });

      test('handles Lightning node pubkeys', () {
        final pubkey = '03864ef025fde8fb587d989186ce6a4a186895ee44a926bfc370e2c366597a3f8f';
        expect(truncateMiddle(pubkey), equals('03864ef0...597a3f8f'));
      });

      test('handles BOLT12 offers', () {
        final offer = 'lno1qgsqvgnwgcg35z6ee2h3yczraddm72xrfua9uve2rlrm9deu7xyfzrcgqyqs5pgrp7nrz3pvvq5yflhvvfggvkev3pglmv5e6mxsd9k6zfgvglmzyqlqlxrjpsnqlxmxvlxrnce5y8qhge5kx6';
        final truncated = truncateMiddle(offer);
        expect(truncated.length, lessThan(offer.length));
        expect(truncated, contains('...'));
      });

      test('handles empty string', () {
        expect(truncateMiddle(''), equals(''));
      });

      test('handles single character', () {
        expect(truncateMiddle('a'), equals('a'));
      });
    });

    // ==================== formatTimestamp TESTS ====================
    group('formatTimestamp', () {
      test('formats "Just now" for recent timestamps', () {
        final now = DateTime.now();
        expect(formatTimestamp(now), equals('Just now'));
      });

      test('formats "Just now" for 30 seconds ago', () {
        final recent = DateTime.now().subtract(const Duration(seconds: 30));
        expect(formatTimestamp(recent), equals('Just now'));
      });

      test('formats minutes ago', () {
        final oneMinAgo = DateTime.now().subtract(const Duration(minutes: 1));
        expect(formatTimestamp(oneMinAgo), equals('1m ago'));

        final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
        expect(formatTimestamp(fiveMinAgo), equals('5m ago'));

        final thirtyMinAgo = DateTime.now().subtract(const Duration(minutes: 30));
        expect(formatTimestamp(thirtyMinAgo), equals('30m ago'));

        final fiftyNineMinAgo = DateTime.now().subtract(const Duration(minutes: 59));
        expect(formatTimestamp(fiftyNineMinAgo), equals('59m ago'));
      });

      test('formats hours ago', () {
        final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
        expect(formatTimestamp(oneHourAgo), equals('1h ago'));

        final fiveHoursAgo = DateTime.now().subtract(const Duration(hours: 5));
        expect(formatTimestamp(fiveHoursAgo), equals('5h ago'));

        final twentyThreeHoursAgo = DateTime.now().subtract(const Duration(hours: 23));
        expect(formatTimestamp(twentyThreeHoursAgo), equals('23h ago'));
      });

      test('formats days ago', () {
        final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
        expect(formatTimestamp(oneDayAgo), equals('1d ago'));

        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        expect(formatTimestamp(sevenDaysAgo), equals('7d ago'));

        final twentyNineDaysAgo = DateTime.now().subtract(const Duration(days: 29));
        expect(formatTimestamp(twentyNineDaysAgo), equals('29d ago'));
      });

      test('formats months ago', () {
        final thirtyOneDaysAgo = DateTime.now().subtract(const Duration(days: 31));
        expect(formatTimestamp(thirtyOneDaysAgo), equals('1mo ago'));

        final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
        expect(formatTimestamp(sixtyDaysAgo), equals('2mo ago'));

        final elevenMonthsAgo = DateTime.now().subtract(const Duration(days: 330));
        expect(formatTimestamp(elevenMonthsAgo), equals('11mo ago'));
      });

      test('formats years ago', () {
        final oneYearAgo = DateTime.now().subtract(const Duration(days: 366));
        expect(formatTimestamp(oneYearAgo), equals('1y ago'));

        final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
        expect(formatTimestamp(twoYearsAgo), equals('2y ago'));

        final fiveYearsAgo = DateTime.now().subtract(const Duration(days: 1825));
        expect(formatTimestamp(fiveYearsAgo), equals('5y ago'));
      });

      test('handles boundary conditions', () {
        // Just under 1 minute
        final fiftyNineSeconds = DateTime.now().subtract(const Duration(seconds: 59));
        expect(formatTimestamp(fiftyNineSeconds), equals('Just now'));

        // Just under 1 hour
        final fiftyNineMinutes = DateTime.now().subtract(const Duration(minutes: 59, seconds: 59));
        expect(formatTimestamp(fiftyNineMinutes), equals('59m ago'));
      });
    });

    // ==================== EDGE CASES ====================
    group('edge cases', () {
      test('formatSats handles negative values', () {
        // This might indicate a bug in calling code, but shouldn't crash
        expect(formatSats(-100), equals('-100 sats'));
      });

      test('formatSatsCompact handles negative values', () {
        // Negative values stay under 1000 threshold, so no k suffix
        expect(formatSatsCompact(-1000), equals('-1000 sats'));
      });

      test('formatSats handles max int safely', () {
        // 21 million BTC = 2,100,000,000,000,000 sats
        expect(formatSats(2100000000000000), contains('BTC'));
      });

      test('truncateMiddle handles unicode', () {
        final unicode = '🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥';
        final truncated = truncateMiddle(unicode);
        expect(truncated.length, lessThan(unicode.length));
      });

      test('formatTimestamp handles future dates', () {
        final future = DateTime.now().add(const Duration(hours: 1));
        // Should handle gracefully (might show "Just now" or negative)
        expect(() => formatTimestamp(future), returnsNormally);
      });
    });

    // ==================== REAL-WORLD SCENARIOS ====================
    group('real-world scenarios', () {
      test('Ocean mining payout display', () {
        // Typical Ocean payouts
        expect(formatSats(2000), equals('2,000 sats'));
        expect(formatSatsCompact(2000), equals('2.0k sats'));
      });

      test('Lightning tip amounts', () {
        expect(formatSats(21), equals('21 sats'));
        expect(formatSats(100), equals('100 sats'));
        expect(formatSats(1000), equals('1,000 sats'));
      });

      test('Larger transaction amounts', () {
        expect(formatSats(50000), equals('50,000 sats'));
        expect(formatSatsCompact(50000), equals('50.0k sats'));
      });

      test('Full Bitcoin display', () {
        expect(formatSats(100000000), equals('1.00000000 BTC'));
        expect(formatSatsCompact(100000000), equals('1.00 BTC'));
      });

      test('Address truncation for display', () {
        final btcAddress = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
        final truncated = truncateMiddle(btcAddress);
        expect(truncated, equals('bc1qxy2k...fjhx0wlh'));
      });

      test('Transaction ID truncation', () {
        final txId = 'a1075db55d416d3ca199f55b6084e2115b9345e16c5cf302fc80e9d5fbf5d48d';
        final truncated = truncateMiddle(txId);
        expect(truncated.length, lessThan(txId.length));
        expect(truncated, startsWith('a1075db5'));
        expect(truncated, endsWith('f5d48d'));
      });
    });
  });
}
