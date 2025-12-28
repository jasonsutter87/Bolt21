# Bolt21 - BOLT12 Lightning Wallet

A self-custodial Lightning wallet with native BOLT12 support. Users hold their own keys.

## Why Bolt21?

- Most wallets only support BOLT11 (single-use invoices)
- BOLT12 offers reusable payment addresses
- No more "send me a new invoice" - just one address forever
- Perfect for mining payouts (Ocean), recurring payments, donations

## Tech Stack

- **Framework:** Flutter (iOS, Android, Web)
- **Lightning:** LDK (Lightning Dev Kit) with BOLT12 support
- **Language:** Dart
- **Architecture:** Self-custodial (user holds keys on device)

---

## Roadmap

### Phase 1: Project Setup & LDK Integration ✅
- [x] Initialize Flutter project (iOS, Android, Web)
- [x] Add ldk-node-flutter package
- [x] Configure native bindings for iOS/Android
- [x] Basic LDK node initialization
- [x] Secure key generation and storage

### Phase 2: Core Wallet Functionality ✅
- [x] Generate and display on-chain Bitcoin address
- [x] Show wallet balance (on-chain + Lightning)
- [x] Transaction history
- [x] Send on-chain payments
- [x] Receive on-chain payments

### Phase 3: BOLT12 Offers (Main Feature) ✅
- [x] Generate BOLT12 offer (reusable address)
- [x] Display offer as QR code + copyable string
- [x] Receive payments via BOLT12 offer
- [ ] Payment notifications
- [ ] Offer management (multiple offers, labels)

### Phase 4: LSP Integration ✅
- [x] LSPS2 configuration support
- [x] Automated channel opening (via LSP)
- [ ] LSP configuration UI
- [ ] Zero-conf channels for instant receiving

### Phase 5: UI/UX Polish & Security 🚧
- [x] Clean, minimal wallet interface
- [x] Dark theme with Bitcoin orange
- [x] Onboarding flow (create/restore wallet)
- [x] Settings screen (backup, node info, channels)
- [ ] Biometric authentication
- [ ] Security audit

### Phase 6: App Store & Web Deployment
- [x] Android debug build working
- [ ] iOS build
- [ ] iOS App Store submission
- [ ] Google Play Store submission
- [ ] Web app deployment
- [ ] Landing page

---

## Current Status

**30 commits** - Core wallet functionality complete!

### What Works:
- Create new wallet with 12-word seed phrase
- Restore existing wallet
- View balances (on-chain + Lightning)
- Generate BOLT12 offers (reusable addresses)
- Generate on-chain addresses
- Send payments (BOLT12, BOLT11)
- QR code scanning
- Settings (backup seed, node info, channels)
- LSP configuration (code-level)

### What's Next:
- iOS build testing
- Real device testing
- LSP UI configuration
- Payment notifications
- App store submission

---

## Future Ideas
- NWC (Nostr Wallet Connect) support
- Contacts with stored BOLT12 offers
- Fiat conversion display
- Multi-language support
- Hardware wallet integration

---

## Resources
- [BOLT12 Spec](https://bolt12.org)
- [LDK Documentation](https://lightningdevkit.org)
- [ldk-node-flutter](https://github.com/LtbLightning/ldk-node-flutter)
- [Voltage Flow LSP](https://voltage.cloud/flow)
- [LSPS2 Spec](https://github.com/BitcoinAndLightningLayerSpecs/lsp/tree/main/LSPS2)
