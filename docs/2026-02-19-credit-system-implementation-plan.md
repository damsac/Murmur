# Credit System Implementation Plan (UI + Usage + Top-Up)

Date: 2026-02-19
Owner: Murmur
Status: Ready for implementation

## 1) Goals

- Implement a production-oriented credit system that charges users for billable AI usage.
- Integrate credit awareness into active UI flows (recording, text submit, settings, top-up, errors).
- Keep architecture proxy-ready so server-side billing can replace local billing with minimal UI/core changes.
- Use integer credits only (no floating-point balance math).

## 2) Locked Decisions

- `Credit` is an integer unit (`Int64`).
- Exchange rate: `1 credit = $0.001` (0.1 cent).
- Billing model: usage-based, post-deduct with pre-check.
- Charge per request: `ceil(usd_cost / 0.001)`.
- MVP billing source of truth: local store (`LocalCreditGate`).
- Migration target: server-backed gate (`ServerCreditGate`) with idempotent charge API.
- Starter credits: `1000`.
- No low-credit warning threshold (warn-only state removed for MVP).
- Overdraft enabled for precision billing (temporary negative balances allowed).
- Minimum non-zero request charge floor: `1 credit`.

## 3) User Story Map

## 3.1 Onboarding and Balance Visibility

- `US-01` As a new user, I receive starter credits so I can try the app.
  - Acceptance:
    - First launch initializes balance once.
    - Starter amount appears in settings and relevant labels.
- `US-02` As a user, I can always see my current balance.
  - Acceptance:
    - Balance shown in Settings and Top Up.
    - Balance updates immediately after charge/top-up.

## 3.2 Consumption Flows

- `US-03` As a user with credits, I can submit voice input and be charged after successful extraction.
  - Acceptance:
    - Pre-check blocks only if balance is `<= 0`.
    - Successful extraction returns entries and a receipt.
    - Balance decreases by computed credits.
- `US-04` As a user with credits, I can submit text input and be charged identically.
  - Acceptance:
    - Same authorize/charge behavior as voice flow.
- `US-05` As a user refining entries, each refine request is billed by actual usage.
  - Acceptance:
    - Refine from recording/text both go through authorize/charge.

## 3.3 Low/No Credit UX

- `US-06` As a zero-or-negative-balance user, usage is blocked with a clear recovery path.
  - Acceptance:
    - Attempting billable action shows out-of-credits screen.
    - Screen has actionable top-up CTA.

## 3.4 Top-Up

- `US-08` As a user, I can buy a predefined credit pack and continue immediately.
  - Acceptance:
    - Top-up increases balance atomically.
    - Success UI confirms new balance.
- `US-09` As a user, failed top-up attempts show retryable errors.
  - Acceptance:
    - Non-destructive failure handling.
    - No partial credit application.

## 3.5 Transparency and Trust

- `US-10` As a user, I can understand what was charged.
  - Acceptance:
    - Receipt includes input tokens, output tokens, credits charged, resulting balance.
    - Recent charge can be surfaced in UI (MVP: latest receipt only).

## 4) Product Rules

- Non-billable actions:
  - On-device transcription itself (`AppleSpeechTranscriber`) is free.
- Billable actions:
  - Any LLM extraction/refinement request.
- Balance rule:
  - `authorize()` fails when balance `<= 0`.
  - A request that passes authorize may push balance below zero after charge.
  - Overdraft is allowed in MVP to preserve exact usage billing.
- Rounding:
  - Always round up credits with `ceil`.
- Minimum charge:
  - Any non-zero billable usage costs at least `1` credit.
- Idempotency:
  - Each request has `CreditAuthorization.id`.
  - Repeated `charge(auth)` must be safe (return same receipt / no double-deduct).

## 5) Architecture

## 5.1 MurmurCore Contracts

Add:

- `TokenUsage { inputTokens: Int, outputTokens: Int }`
- `ServicePricing { inputUSDPer1M: Int64Micros, outputUSDPer1M: Int64Micros }`
- `LLMResult { entries: [ExtractedEntry], usage: TokenUsage }`
- `CreditAuthorization`, `CreditReceipt`
- `CreditGate` protocol:
  - `authorize() async throws -> CreditAuthorization`
  - `charge(_:usage:pricing:) async throws -> CreditReceipt`
  - `topUp(credits:) async throws`
  - `balance async -> Int64`
- `CreditError` and `PipelineError.insufficientCredits`

Change:

- `LLMService.extractEntries(...)` return type from `[ExtractedEntry]` to `LLMResult`.
- `Pipeline` gains optional `creditGate` + required LLM pricing config.
- `RecordingResult` and `TextResult` include optional `CreditReceipt`.

## 5.2 App Layer

Add:

- `LocalCreditGate` actor backed by persistent storage.
- `CreditStore` persistence abstraction (UserDefaults first, SwiftData upgrade path).
- `CreditViewModel` (or AppState credit section) for observable UI state.

Change:

- `AppState.configurePipeline()` injects credit gate + pricing config.
- Root-level routing handles insufficient-credit errors to top-up/out-of-credit screens.

## 5.3 Proxy-Ready Boundary

- Keep `CreditGate` as seam.
- Local and server gates must share behavior contract (authorize/charge/topup/idempotency).
- Server migration should require only init/config swap.

## 6) UI Integration Plan

## 6.1 Activate Credit Screens in Build

Current `project.yml` excludes `Views/Credits/**` and `Views/Errors/**`.

- Remove excludes for:
  - `Murmur/Views/Credits/**`
  - `Murmur/Views/Errors/**`
- Keep only truly orphaned files excluded.

## 6.2 Screen Responsibilities

- `SettingsMinimalView`:
  - Show live balance.
  - `Top Up` navigates to `TopUpView`.
- `TopUpView`:
  - Replace `appState.creditBalance` usage with real credit source.
  - Purchase actions call `creditGate.topUp(credits:)`.
  - Show success/failure state.
- `LowTokensView` (rename to `LowCreditsView`):
  - Remove from MVP flow (no low-balance warning state).
- `OutOfCreditsView`:
  - Presented when authorize fails.
  - CTA leads to top-up and returns to prior flow.
- Recording/Text submit surfaces:
  - On success optionally show charge receipt toast (`-N credits`).

## 6.3 Navigation/Routing

- Centralize in `RootView`:
  - `showTopUp`
  - `showOutOfCredits`
  - `pendingActionAfterTopUp` (retry intent)
- After successful top-up:
  - Dismiss top-up.
  - Optionally retry pending action once.

## 7) Data Model and Math

- Storage units:
  - `credits: Int64`
  - USD rates as integer micros per 1M tokens (`Int64`).
- Charge computation:
  - `usdMicros = (inTokens * inRateMicrosPer1M + outTokens * outRateMicrosPer1M) / 1_000_000`
  - `credits = ceil_div(usdMicros, 1000)` because 1 credit = 1000 micros USD.
  - Enforce minimum charge floor if desired (`max(1, credits)` for non-zero usage).

## 8) Pricing Config

- Add `ModelPricingCatalog` in app config:
  - Keyed by model id (`claude-sonnet-4.5`, etc.).
  - Separate input/output rates.
- Source:
  - Hardcoded local catalog for MVP.
  - Remote config later.

## 8.1 Apple Payment Compliance (Critical)

- Credits are digital value used to unlock in-app digital functionality.
- For App Store distribution, this purchase type is governed by App Review payment rules and should be implemented as In-App Purchase (`Consumable`) for top-ups.
- Apple Pay is appropriate for physical goods/services consumed outside the app, not for in-app digital credit unlock flows.
- If external payment links are used in permitted storefronts, they become a separate compliance track and should not be MVP scope.

## 8.2 MVP Top-Up Rail

- Only top-up rail in MVP: StoreKit In-App Purchase consumables.
- Top-up methods removed from MVP scope:
  - `Cashu`
  - `Subscribe`
  - direct in-app Apple Pay checkout for credits
- Initial product IDs (App Store Connect):
  - `com.damsac.murmur.credits.1000`
  - `com.damsac.murmur.credits.5000`
  - `com.damsac.murmur.credits.10000`
- Credit grant should occur only after verified transaction success.

## 9) Implementation Phases

## Phase A: Core Billing Contracts

- Files:
  - `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift`
  - `Packages/MurmurCore/Sources/MurmurCore/Pipeline.swift`
  - new `Packages/MurmurCore/Sources/MurmurCore/Credits.swift`
- Deliverables:
  - New credit/value types and protocol.
  - Updated LLM and pipeline signatures.
  - Backward-safe error mapping.

## Phase B: Provider Usage Wiring

- File:
  - `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift`
- Deliverables:
  - Parse token usage from provider response.
  - Return `LLMResult`.
  - Preserve conversation behavior.

## Phase C: Local Gate + Persistence

- Files:
  - new `Murmur/Services/Credits/LocalCreditGate.swift`
  - new `Murmur/Services/Credits/CreditStore.swift`
  - `Murmur/Services/AppState.swift`
- Deliverables:
  - Starter credit init.
  - Idempotent charge tracking by authorization ID.
  - Top-up API.

## Phase D: UI Hookup

- Files:
  - `project.yml`
  - `Murmur/Views/RootView.swift`
  - `Murmur/Views/Settings/SettingsMinimalView.swift`
  - `Murmur/Views/Credits/TopUpView.swift`
  - `Murmur/Views/Errors/OutOfCreditsView.swift`
- Deliverables:
  - Active credit views in production build.
  - Top-up flow via StoreKit consumables + insufficient credit routing.
  - Live balance presentation.

## Phase E: Testing + Hardening

- Files:
  - `Packages/MurmurCore/Tests/MurmurCoreTests/PipelineTests.swift`
  - `Packages/MurmurCore/Tests/MurmurCoreTests/Mocks.swift`
  - `Packages/MurmurCore/Tests/MurmurCoreTests/PPQLLMServiceTests.swift`
  - add app-level tests for credit gate where feasible
- Deliverables:
  - Contract tests for authorize/charge order.
  - Idempotent double-charge tests.
  - Insufficient-credit path tests.
  - Usage parsing tests.

## 10) Test Matrix

- Core:
  - authorize success/fail
  - charge after success
  - no charge on extraction failure
  - charge idempotency with repeated calls
- UI:
  - low-credit warning path
  - out-of-credit block and top-up recovery
  - balance refresh after top-up
- Edge:
  - app restart between authorize and charge
  - malformed usage payload fallback
  - top-up failure/retry

## 11) Rollout Strategy

- Milestone 1: Hidden behind dev flag, local-only billing.
- Milestone 2: Enable for all internal testers with debug pricing label.
- Milestone 3: Freeze contracts and start server-gate implementation.

## 12) Open Decisions (must resolve before coding Phase C/D)

- App Store storefront scope for MVP (`US only` vs `global`) because payment/link rules differ by storefront.
- Whether any external purchase links are in scope for MVP, or strictly StoreKit-only.

## 13) Definition of Done

- Users can see balance, consume credits through voice/text/refine, hit graceful insufficient-credit UX, top up, and continue.
- All active flows use the same credit source of truth.
- Core and UI tests cover happy path + failure paths.
- No mock-only credit references remain in active code paths.
