---
title: 'Understanding BOLT12'
description: 'What is BOLT12 and why it matters for Lightning payments.'
layout: 'docs'
weight: 2
css: ['docs.css']
---

# Understanding BOLT12

BOLT12 is a new Lightning Network payment standard that introduces **Offers** - reusable payment endpoints that never expire.

## BOLT11 vs BOLT12

| Feature | BOLT11 Invoice | BOLT12 Offer |
|---------|---------------|--------------|
| Expiration | Expires (usually 1 hour) | Never expires |
| Reusable | Single use only | Unlimited payments |
| Amount | Fixed or variable | Variable |
| Privacy | Reveals node pubkey | Enhanced privacy |

## Why BOLT12 Matters

### For Miners
- Set your payout address once, receive payments forever
- No need to update invoices when they expire
- Perfect for recurring mining payouts from Ocean

### For Merchants
- Share one offer for all customers
- No invoice management needed
- Customers can pay any amount

### For Everyone
- Simpler payment experience
- Better privacy
- Future-proof technology

## How Bolt21 Uses BOLT12

1. **Generate an Offer** - Tap Receive → BOLT12 Offer
2. **Share It** - Copy or show the QR code
3. **Receive Payments** - Anyone can pay to your offer, anytime

Your BOLT12 offer stays the same forever. Share it on your website, business card, or mining pool dashboard.
