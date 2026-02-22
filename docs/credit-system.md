# Credit System

## Overview

Murmur uses a credit-based billing system for LLM usage. Every extraction or refinement request consumes credits proportional to token usage. Users start with 1,000 free credits and can purchase more via StoreKit In-App Purchase consumables.

## Architecture

```
MurmurCore (Swift Package)           Murmur (iOS App)
┌──────────────────────────┐        ┌───────────────────────────────┐
│ CreditGate (protocol)    │◄───────│ LocalCreditGate (actor)       │
│   authorize()            │        │   UserDefaults persistence    │
│   charge(_:usage:pricing)│        │   Idempotent by auth ID       │
│   topUp(credits:)        │        └───────────────────────────────┘
│   balance                │
├──────────────────────────┤        ┌───────────────────────────────┐
│ Pipeline                 │        │ StoreKitTopUpService          │
│   authorize before LLM   │        │   Product.purchase() (SK2)    │
│   charge after LLM       │        │   TopUpCatalog product IDs    │
│   receipt in result      │        └───────────────────────────────┘
├──────────────────────────┤
│ TokenUsage               │        ┌───────────────────────────────┐
│ ServicePricing           │        │ AppState                      │
│ CreditAuthorization      │        │   creditBalance (observable)  │
│ CreditReceipt            │        │   configurePipeline()         │
│ CreditError              │        │   applyTopUp(credits:)        │
└──────────────────────────┘        └───────────────────────────────┘
```

## Request Lifecycle

1. User taps record/submit text
2. `Pipeline.extractEntries()` calls `creditGate.authorize()` — fails if balance <= 0
3. LLM extraction runs, returns entries + `TokenUsage`
4. `Pipeline` calls `creditGate.charge(authorization, usage, pricing)` — deducts credits
5. `CreditReceipt` returned with entries in `RecordingResult`/`TextResult`
6. `AppState.refreshCreditBalance()` updates UI
7. If `authorize()` fails with `.insufficientBalance`, `RootView` auto-opens TopUp sheet

## Credit Math

All arithmetic uses integers to avoid floating-point drift.

- **1 credit = $0.001** (1,000 USD micros)
- **Pricing** stored as USD micros per 1M tokens (`Int64`)
- **Formula**: `credits = ceil((inputTokens * inputRate + outputTokens * outputRate) / 1_000_000 / 1_000)`
- **Minimum charge**: 1 credit for any non-zero usage, 0 for zero usage

Current pricing (hardcoded, will become model catalog):
- Input: $1.00/M tokens (`1_000_000` micros)
- Output: $5.00/M tokens (`5_000_000` micros)

## Idempotency

Each `authorize()` call returns a `CreditAuthorization` with a unique UUID. `LocalCreditGate.charge()` indexes receipts by this UUID. Calling `charge()` twice with the same authorization returns the cached receipt without deducting again. This is critical for retry safety and matches the pattern a server-side gate would need.

## StoreKit Integration

Three consumable products defined in `Murmur.storekit` and `TopUpCatalog`:

| Product ID | Credits | Price |
|---|---|---|
| `com.damsac.murmur.credits.1000` | 1,000 | $0.99 |
| `com.damsac.murmur.credits.5000` | 5,000 | $3.99 |
| `com.damsac.murmur.credits.10000` | 10,000 | $6.99 |

Purchase flow: `StoreKitTopUpService.purchase()` -> verify transaction -> `AppState.applyTopUp()` -> `LocalCreditGate.topUp()` -> balance increases.

## Persistence

`LocalCreditGate` persists to UserDefaults as JSON under key `credits.local.state.v1`. State includes:
- Current balance (`Int64`)
- Receipt map by authorization UUID (for idempotency)

Balance survives app restarts. New `LocalCreditGate` instances restore from the same key.

## Key Files

| File | Layer | Purpose |
|---|---|---|
| `Packages/MurmurCore/.../Credits.swift` | Core | Protocols + value types |
| `Packages/MurmurCore/.../Pipeline.swift` | Core | Authorize/charge orchestration |
| `Packages/MurmurCore/.../PPQLLMService.swift` | Core | Token usage parsing |
| `Murmur/Services/Credits/LocalCreditGate.swift` | App | UserDefaults-backed gate |
| `Murmur/Services/Purchases/StoreKitTopUpService.swift` | App | StoreKit 2 purchase flow |
| `Murmur/Services/Purchases/TopUpCatalog.swift` | App | Product ID definitions |
| `Murmur/Services/AppState.swift` | App | Observable balance + pipeline config |
| `Murmur/Views/Credits/TopUpView.swift` | App | Top-up UI |
| `Murmur/Views/Settings/SettingsMinimalView.swift` | App | Balance display in settings |
| `Murmur/Config/StoreKit/Murmur.storekit` | App | StoreKit testing config |

## Porting to Server-Side Billing

The system is designed for a straightforward migration:

1. **Create `ServerCreditGate`** conforming to `CreditGate`. Replace HTTP calls for authorize/charge/topUp/balance.
2. **Server-side receipt validation** — after `StoreKitTopUpService.purchase()`, send the `transactionID` to your server for App Store Server API verification before granting credits. Currently `applyTopUp` trusts the local StoreKit receipt.
3. **Swap in `AppState.configurePipeline()`** — replace `LocalCreditGate(...)` with `ServerCreditGate(...)`. Zero changes to `Pipeline`, `PPQLLMService`, or any UI code.
4. **Wire `syncTransactions()`** — already stubbed in `StoreKitTopUpService` for catching interrupted purchases. Call on app launch once server state exists.

The `CreditGate` protocol boundary, idempotent charge pattern, and integer-only math all transfer directly to a server implementation.
