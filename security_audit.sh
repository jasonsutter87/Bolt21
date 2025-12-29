#!/bin/bash
#
# Bolt21 Security Audit Script
# Run this before every release to catch security regressions
#
# Usage: ./security_audit.sh
# Exit code: 0 = all checks pass, 1 = one or more checks failed
#

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

echo "🔐 BOLT21 SECURITY AUDIT"
echo "========================"
echo "Project: $PROJECT_ROOT"
echo "Date: $(date)"
echo ""

FAILED=0
PASSED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function pass() {
    echo -e "${GREEN}   ✅ PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

function fail() {
    echo -e "${RED}   ❌ FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

function warn() {
    echo -e "${YELLOW}   ⚠️  WARN${NC}: $1"
}

# =============================================================================
# TEST 1: Check for raw debugPrint usage (should only be in SecureLogger)
# =============================================================================
echo "1. Checking for raw debugPrint() usage..."
if grep -r "debugPrint(" lib/ --include="*.dart" | grep -v "secure_logger.dart" | grep -v "//.*debugPrint" > /dev/null 2>&1; then
    fail "Raw debugPrint() found outside SecureLogger"
    grep -r "debugPrint(" lib/ --include="*.dart" | grep -v "secure_logger.dart" | grep -v "//.*debugPrint" | sed 's/^/       /'
else
    pass "No raw debugPrint() usage"
fi

# =============================================================================
# TEST 2: Check for biometricOnly: false (security regression)
# =============================================================================
echo ""
echo "2. Checking biometric configuration..."
if grep -r "biometricOnly:\s*false" lib/ --include="*.dart" > /dev/null 2>&1; then
    fail "biometricOnly: false found (allows device PIN bypass)"
    grep -r "biometricOnly:\s*false" lib/ --include="*.dart" | sed 's/^/       /'
else
    pass "Biometric-only auth enforced"
fi

# =============================================================================
# TEST 3: Check for hardcoded secrets
# =============================================================================
echo ""
echo "3. Checking for hardcoded secrets..."
if grep -rE "(api_key|secret|password|private_key)\s*=\s*['\"][^'\"]+['\"]" lib/ --include="*.dart" | \
   grep -v "secure_logger\|config_service\|_encryptionKeyStorageKey\|_biometricEnabledKey" > /dev/null 2>&1; then
    fail "Potential hardcoded secret found"
    grep -rE "(api_key|secret|password|private_key)\s*=\s*['\"][^'\"]+['\"]" lib/ --include="*.dart" | \
        grep -v "secure_logger\|config_service\|_encryptionKeyStorageKey\|_biometricEnabledKey" | sed 's/^/       /'
else
    pass "No hardcoded secrets detected"
fi

# =============================================================================
# TEST 4: Check Android certificate pinning
# =============================================================================
echo ""
echo "4. Checking Android certificate pinning..."
ANDROID_CERT_FILE="android/app/src/main/res/xml/network_security_config.xml"
if [ ! -f "$ANDROID_CERT_FILE" ]; then
    fail "network_security_config.xml missing"
else
    if grep -q '<pin digest="SHA-256">' "$ANDROID_CERT_FILE"; then
        # Verify not using empty hash
        if grep -q "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=" "$ANDROID_CERT_FILE"; then
            fail "Empty hash certificate pin detected"
        else
            # Count number of pins
            PIN_COUNT=$(grep -c '<pin digest="SHA-256">' "$ANDROID_CERT_FILE")
            if [ "$PIN_COUNT" -ge 2 ]; then
                pass "Android cert pinning configured ($PIN_COUNT pins)"
            else
                warn "Only 1 certificate pin (recommend at least 2 for backup)"
            fi
        fi
    else
        fail "No certificate pins found in network_security_config.xml"
    fi
fi

# =============================================================================
# TEST 5: Check iOS for raw print() statements (should use os_log)
# =============================================================================
echo ""
echo "5. Checking iOS logging security..."
if [ -d "ios/Runner" ]; then
    if grep -r "print(" ios/Runner/ --include="*.swift" | grep -v "os_log\|//.*print" > /dev/null 2>&1; then
        fail "Raw print() found in iOS code (leaks to system log)"
        grep -r "print(" ios/Runner/ --include="*.swift" | grep -v "os_log\|//.*print" | sed 's/^/       /'
    else
        pass "No insecure iOS logging"
    fi
else
    warn "ios/Runner directory not found"
fi

# =============================================================================
# TEST 6: Check iOS certificate pinning
# =============================================================================
echo ""
echo "6. Checking iOS certificate pinning..."
if [ -d "ios/Runner" ]; then
    if [ -f "ios/Runner/CertificatePinner.swift" ]; then
        pass "iOS certificate pinning implementation found"
    else
        fail "iOS certificate pinning NOT implemented (CRITICAL)"
        echo "       iOS users vulnerable to MITM attacks"
    fi
else
    warn "ios/Runner directory not found"
fi

# =============================================================================
# TEST 7: Check git dependencies are pinned to commit hash
# =============================================================================
echo ""
echo "7. Checking git dependency pinning..."
if grep -A2 "git:" pubspec.yaml | grep "ref:" | grep -E "ref:\s*(main|master|develop)" > /dev/null 2>&1; then
    fail "Git dependencies not pinned to commit hash (supply chain risk)"
    grep -A2 "git:" pubspec.yaml | sed 's/^/       /'
else
    if grep -q "git:" pubspec.yaml; then
        pass "Git dependencies pinned"
    else
        pass "No git dependencies"
    fi
fi

# =============================================================================
# TEST 8: Check for dev config in production assets
# =============================================================================
echo ""
echo "8. Checking for dev config in production assets..."
if grep -q "assets/config.json" pubspec.yaml; then
    fail "config.json in production assets (may leak API keys)"
    echo "       Remove 'assets/config.json' from pubspec.yaml"
else
    pass "No dev config in production assets"
fi

# =============================================================================
# TEST 9: Check Android FLAG_SECURE is set
# =============================================================================
echo ""
echo "9. Checking Android screenshot protection..."
MAIN_ACTIVITY="android/app/src/main/kotlin/com/bolt21/bolt21/MainActivity.kt"
if [ -f "$MAIN_ACTIVITY" ]; then
    if grep -q "FLAG_SECURE" "$MAIN_ACTIVITY"; then
        pass "Android FLAG_SECURE enabled"
    else
        fail "Android FLAG_SECURE not set (screenshots allowed)"
    fi
else
    warn "MainActivity.kt not found"
fi

# =============================================================================
# TEST 10: Check for TODO/FIXME/HACK comments
# =============================================================================
echo ""
echo "10. Checking for security-related TODOs..."
TODO_COUNT=$(grep -r "TODO\|FIXME\|HACK\|XXX" lib/ --include="*.dart" | grep -i "security\|crypto\|password\|key" | wc -l | tr -d ' ')
if [ "$TODO_COUNT" -gt 0 ]; then
    warn "$TODO_COUNT security-related TODO/FIXME found"
    grep -r "TODO\|FIXME\|HACK\|XXX" lib/ --include="*.dart" | grep -i "security\|crypto\|password\|key" | sed 's/^/       /'
else
    pass "No security-related TODOs"
fi

# =============================================================================
# TEST 11: Verify AES-256-GCM encryption
# =============================================================================
echo ""
echo "11. Checking encryption configuration..."
if grep -q "AesGcm.with256bits()" lib/services/operation_state_service.dart; then
    pass "AES-256-GCM encryption verified"
else
    fail "AES-256-GCM not found in operation_state_service.dart"
fi

# =============================================================================
# TEST 12: Check for balance validation
# =============================================================================
echo ""
echo "12. Checking payment balance validation..."
if grep -A10 "Future<String\?> sendPayment" lib/providers/wallet_provider.dart | grep -q "totalBalanceSats"; then
    pass "Balance validation implemented"
else
    fail "No balance validation before payment"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "========================"
echo "AUDIT SUMMARY"
echo "========================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ ALL SECURITY CHECKS PASSED${NC}"
    echo ""
    echo "The app is ready for release from a security perspective."
    echo "Note: This script checks for common issues but is not a replacement"
    echo "      for professional security audits and penetration testing."
    exit 0
else
    echo -e "${RED}❌ $FAILED SECURITY CHECK(S) FAILED${NC}"
    echo ""
    echo "CRITICAL: Do not release until all security checks pass."
    echo "Review the failures above and fix before deployment."
    echo ""
    echo "For detailed guidance, see:"
    echo "  - FINAL_SECURITY_AUDIT.md"
    echo "  - SECURITY_GRADE_SUMMARY.md"
    exit 1
fi
