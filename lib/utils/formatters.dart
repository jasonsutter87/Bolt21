/// Format satoshis for display
String formatSats(int sats) {
  if (sats >= 100000000) {
    // Show in BTC for large amounts
    final btc = sats / 100000000;
    return '${btc.toStringAsFixed(8)} BTC';
  } else if (sats >= 1000000) {
    // Show with comma separators
    return '${_addCommas(sats)} sats';
  } else if (sats >= 1000) {
    return '${_addCommas(sats)} sats';
  }
  return '$sats sats';
}

/// Format satoshis compactly
String formatSatsCompact(int sats) {
  if (sats >= 100000000) {
    final btc = sats / 100000000;
    return '${btc.toStringAsFixed(2)} BTC';
  } else if (sats >= 1000000) {
    final m = sats / 1000000;
    return '${m.toStringAsFixed(1)}M sats';
  } else if (sats >= 1000) {
    final k = sats / 1000;
    return '${k.toStringAsFixed(1)}k sats';
  }
  return '$sats sats';
}

String _addCommas(int number) {
  final str = number.toString();
  final result = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      result.write(',');
    }
    result.write(str[i]);
  }
  return result.toString();
}

/// Truncate a string in the middle (for addresses, node IDs)
String truncateMiddle(String str, {int start = 8, int end = 8}) {
  if (str.length <= start + end + 3) return str;
  return '${str.substring(0, start)}...${str.substring(str.length - end)}';
}

/// Format a timestamp
String formatTimestamp(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inDays > 365) {
    return '${(diff.inDays / 365).floor()}y ago';
  } else if (diff.inDays > 30) {
    return '${(diff.inDays / 30).floor()}mo ago';
  } else if (diff.inDays > 0) {
    return '${diff.inDays}d ago';
  } else if (diff.inHours > 0) {
    return '${diff.inHours}h ago';
  } else if (diff.inMinutes > 0) {
    return '${diff.inMinutes}m ago';
  }
  return 'Just now';
}
