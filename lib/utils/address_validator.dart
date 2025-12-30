/// Payment address validation utilities
///
/// SECURITY: Validates addresses to prevent:
/// - Unicode lookalike/homograph attacks (Cyrillic chars that look like Latin)
/// - Unicode directional override attacks (RTL chars that reverse displayed text)
/// - Zero-width character injection (invisible chars that change address)
/// - Invalid character injection
/// - Malformed addresses

class AddressValidator {
  // SECURITY: Dangerous unicode control characters that can manipulate text display
  // These can make addresses appear different than they actually are
  static final RegExp _dangerousUnicode = RegExp(
    r'[\u200B-\u200F'  // Zero-width spaces and directional marks
    r'\u202A-\u202E'   // Embedding and override (LTR/RTL)
    r'\u2060-\u2064'   // Word joiner and invisible operators
    r'\u206A-\u206F'   // Deprecated formatting chars
    r'\uFEFF'          // BOM / zero-width no-break space
    r'\uFFF9-\uFFFB]'  // Interlinear annotation anchors
  );
  // Bech32 charset: only these characters are valid in bech32 addresses
  // Excludes 1, b, i, o to avoid confusion with similar characters
  static const String _bech32Charset = '023456789acdefghjklmnpqrstuvwxyz';

  // Base58 charset: used for legacy Bitcoin addresses (1... and 3...)
  // Excludes 0, O, I, l to avoid confusion
  static const String _base58Charset =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  // Lightning invoice charset (BOLT11): base32 with specific chars
  static const String _bolt11Charset =
      '023456789acdefghjklmnpqrstuvwxyz';

  // Valid ASCII for general input (no unicode)
  static final RegExp _asciiOnly = RegExp(r'^[\x20-\x7E]*$');

  // Lightning address format: user@domain
  static final RegExp _lightningAddressPattern =
      RegExp(r'^[a-zA-Z0-9._+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  /// Validate a payment destination
  /// Returns null if valid, error message if invalid
  static String? validateDestination(String input) {
    if (input.isEmpty) {
      return 'Payment destination cannot be empty';
    }

    // SECURITY: Check for dangerous unicode control characters first
    // These can reverse text display (RTL override) or inject invisible chars
    if (_dangerousUnicode.hasMatch(input)) {
      return 'Dangerous unicode characters detected. Possible address spoofing attempt.';
    }

    // SECURITY: Check for non-ASCII characters (unicode lookalikes)
    if (!_asciiOnly.hasMatch(input)) {
      return 'Invalid characters detected. Only ASCII characters are allowed.';
    }

    final lower = input.toLowerCase().trim();

    // Bech32 address (bc1...)
    if (lower.startsWith('bc1')) {
      return _validateBech32Address(lower);
    }

    // Legacy P2PKH (1...) or P2SH (3...)
    if (lower.startsWith('1') || lower.startsWith('3')) {
      return _validateBase58Address(input.trim());
    }

    // BOLT11 invoice (lnbc... or lntb...)
    if (lower.startsWith('lnbc') || lower.startsWith('lntb')) {
      return _validateBolt11Invoice(lower);
    }

    // BOLT12 offer (lno...)
    if (lower.startsWith('lno')) {
      return _validateBolt12Offer(lower);
    }

    // BIP21 URI (bitcoin:...)
    if (lower.startsWith('bitcoin:')) {
      return _validateBip21Uri(input.trim());
    }

    // Lightning address (user@domain)
    if (input.contains('@')) {
      return _validateLightningAddress(input.trim());
    }

    return 'Unrecognized payment format';
  }

  /// Validate Bech32 address (bc1q... for SegWit, bc1p... for Taproot)
  static String? _validateBech32Address(String address) {
    // bc1 prefix + at least 39 chars for P2WPKH, up to 62 for P2WSH
    if (address.length < 42 || address.length > 62) {
      return 'Invalid Bech32 address length';
    }

    // After bc1, all characters must be valid bech32
    final payload = address.substring(3);
    for (var i = 0; i < payload.length; i++) {
      if (!_bech32Charset.contains(payload[i])) {
        return 'Invalid character in Bech32 address: "${payload[i]}"';
      }
    }

    return null; // Valid
  }

  /// Validate Base58Check address (legacy 1... and 3...)
  static String? _validateBase58Address(String address) {
    // Legacy addresses are 25-34 characters
    if (address.length < 25 || address.length > 34) {
      return 'Invalid legacy address length';
    }

    for (var i = 0; i < address.length; i++) {
      if (!_base58Charset.contains(address[i])) {
        return 'Invalid character in address: "${address[i]}"';
      }
    }

    return null; // Valid
  }

  /// Validate BOLT11 invoice
  static String? _validateBolt11Invoice(String invoice) {
    // BOLT11 invoices are typically 200-1000 chars
    if (invoice.length < 50) {
      return 'BOLT11 invoice too short';
    }
    if (invoice.length > 2000) {
      return 'BOLT11 invoice too long';
    }

    // After lnbc/lntb prefix, validate charset
    final prefix = invoice.startsWith('lnbc') ? 4 : 4;
    final payload = invoice.substring(prefix);

    for (var i = 0; i < payload.length; i++) {
      final char = payload[i];
      // BOLT11 uses bech32 charset plus '1' as separator
      if (!_bolt11Charset.contains(char) && char != '1') {
        return 'Invalid character in BOLT11 invoice: "$char"';
      }
    }

    return null; // Valid
  }

  /// Validate BOLT12 offer
  static String? _validateBolt12Offer(String offer) {
    if (offer.length < 50) {
      return 'BOLT12 offer too short';
    }
    if (offer.length > 2000) {
      return 'BOLT12 offer too long';
    }

    // BOLT12 uses bech32m encoding
    final payload = offer.substring(3); // After 'lno'
    for (var i = 0; i < payload.length; i++) {
      final char = payload[i];
      if (!_bech32Charset.contains(char) && char != '1') {
        return 'Invalid character in BOLT12 offer: "$char"';
      }
    }

    return null; // Valid
  }

  /// Validate BIP21 URI
  static String? _validateBip21Uri(String uri) {
    // Extract address from bitcoin:address?params
    final withoutPrefix = uri.substring(8); // Remove 'bitcoin:'
    final addressEnd = withoutPrefix.indexOf('?');
    final address = addressEnd > 0
        ? withoutPrefix.substring(0, addressEnd)
        : withoutPrefix;

    final lowerAddress = address.toLowerCase();

    // Validate the embedded address
    if (lowerAddress.startsWith('bc1')) {
      return _validateBech32Address(lowerAddress);
    } else if (address.startsWith('1') || address.startsWith('3')) {
      return _validateBase58Address(address);
    }

    return 'Invalid address in BIP21 URI';
  }

  /// Validate Lightning address (LNURL)
  static String? _validateLightningAddress(String address) {
    if (!_lightningAddressPattern.hasMatch(address)) {
      return 'Invalid Lightning address format';
    }

    // Check for unicode lookalikes in the ASCII-looking address
    if (!_asciiOnly.hasMatch(address)) {
      return 'Invalid characters in Lightning address';
    }

    return null; // Valid
  }

  /// Check if input contains any non-ASCII unicode characters or dangerous control chars
  /// SECURITY: Detects homograph attacks using Cyrillic/Greek lookalikes
  /// SECURITY: Detects RTL override, zero-width chars, and other display manipulation
  static bool containsUnicodeLookalikes(String input) {
    // Check for dangerous unicode control characters
    if (_dangerousUnicode.hasMatch(input)) {
      return true;
    }
    // Check for non-ASCII characters
    return !_asciiOnly.hasMatch(input);
  }

  /// Get a sanitized version of the input (ASCII only, no dangerous unicode)
  /// SECURITY: Strips RTL overrides, zero-width chars, and all non-ASCII
  static String sanitizeToAscii(String input) {
    // First remove dangerous unicode control characters
    var sanitized = input.replaceAll(_dangerousUnicode, '');
    // Then remove all non-printable ASCII
    return sanitized.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }
}
