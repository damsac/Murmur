# LLM Provider & Pricing Strategy

**Date:** 2026-03-04
**Author:** dam + Claude
**Status:** Research / Decision pending

---

## 1. Current State

### What's wired today

**Provider:** PPQ.ai (PayPerQ) — an OpenAI-compatible API proxy that provides access to multiple LLM providers under a single endpoint. Pay-per-use, no subscription required. Accepts crypto and credit card.

**Model:** `anthropic/claude-sonnet-4.6` — specified in `PPQLLMService.init()`. This is Claude Sonnet 4.6, Anthropic's balanced model.

**Endpoint:** `https://api.ppq.ai/chat/completions` (OpenAI-compatible chat completions format)

**API Key:** Baked into Info.plist at build time. Chain: `project.local.yml` (`PPQ_API_KEY`) -> `project.yml` (`$(PPQ_API_KEY)`) -> Info.plist (`PPQAPIKey`) -> `APIKeyProvider.swift` (`Bundle.main.object(forInfoDictionaryKey:)`). The key is in plain text in the app bundle. Anyone with the IPA can extract it.

**Credit System:**
- `LocalCreditGate` — on-device credit tracking in UserDefaults
- Starter balance: 1,000 credits on first launch
- Pricing: 1 credit = $0.001 (1000 USD micros)
- Current `ServicePricing` config: input $1.00/MTok, output $5.00/MTok, minimum charge 1 credit
- StoreKit consumable IAPs: 1,000 credits/$0.99, 5,000 credits/$3.99, 10,000 credits/$6.99

**Key problem:** The ServicePricing hardcoded in AppState does NOT match Claude Sonnet 4.6's actual pricing. It uses `inputUSDPer1MMicros: 1_000_000` and `outputUSDPer1MMicros: 5_000_000`, which translates to $1/MTok input and $5/MTok output. Claude Sonnet 4.6 actually costs $3/MTok input and $15/MTok output. The app is undercharging credits by 3x, meaning you burn through real API dollars faster than credits reflect.

### Token budget per interaction

Typical voice note flow:

| Component | Estimated tokens |
|-----------|-----------------|
| System prompt (entryManager) | ~800 tokens |
| Temporal context + memory | ~100 tokens |
| Existing entries (10-20 entries) | ~300-600 tokens |
| User transcript (100-500 words) | ~150-600 tokens |
| Tool definitions (6 tools) | ~1,200 tokens |
| **Total input** | **~2,500-3,300 tokens** |
| Tool calls output (1-5 actions) | ~200-500 tokens |
| Status message | ~20-50 tokens |
| **Total output** | **~220-550 tokens** |

Daily focus flow: lighter — ~1,000 input, ~100 output (one-shot, simpler prompt, one tool).

---

## 2. Provider Comparison

### Pricing per million tokens (March 2026)

| Provider / Model | Input $/MTok | Output $/MTok | Tool calling | Streaming | Notes |
|-----------------|-------------|--------------|-------------|-----------|-------|
| **Anthropic Claude Sonnet 4.6** | $3.00 | $15.00 | Yes | Yes | Best quality for this task. Current model via PPQ. |
| **Anthropic Claude Haiku 4.5** | $1.00 | $5.00 | Yes | Yes | 3x cheaper. Likely sufficient for structured extraction. |
| **OpenAI GPT-4o** | $2.50 | $10.00 | Yes | Yes | Comparable quality to Sonnet. |
| **OpenAI GPT-4o-mini** | $0.15 | $0.60 | Yes | Yes | 20x cheaper than Sonnet. Good enough for extraction? |
| **Google Gemini 2.0 Flash** | $0.10 | $0.40 | Yes | Yes | Cheapest option. 1M context window. |
| **OpenRouter (Sonnet 4.6)** | $3.17 | $15.83 | Yes | Yes | 5.5% platform fee on top of base. |
| **PPQ.ai (Sonnet 4.6)** | ~$3.00+ | ~$15.00+ | Yes | Yes | Markup unknown. Advertises ~$0.015/query average. |

### Cost per voice note (estimated)

Using the typical interaction budget of 3,000 input + 400 output tokens:

| Model | Cost per note | Notes per $1 | Notes per 1,000 credits ($1) |
|-------|--------------|-------------|------------------------------|
| Claude Sonnet 4.6 | $0.015 | 67 | 67 |
| Claude Haiku 4.5 | $0.005 | 200 | 200 |
| GPT-4o | $0.0115 | 87 | 87 |
| GPT-4o-mini | $0.00069 | 1,449 | 1,449 |
| Gemini 2.0 Flash | $0.00046 | 2,174 | 2,174 |

### What this means for the current setup

With Claude Sonnet 4.6 at ~$0.015/note and 1,000 starter credits ($1):
- A user gets roughly **67 voice notes** before needing to top up
- At 5 notes/day, that is **~13 days** of free usage
- The $0.99 IAP (1,000 credits) buys another 67 notes

With Claude Haiku 4.5 at ~$0.005/note:
- 1,000 starter credits = **200 voice notes** (~40 days at 5/day)
- Much more generous free tier feel

**Critical mismatch:** The current ServicePricing ($1/$5 per MTok) matches Haiku pricing, not Sonnet. If PPQ is actually routing to Sonnet at $3/$15, each voice note costs the developer ~$0.015 but only deducts ~$0.005 in credits. You lose ~$0.01 per note. At scale this bleeds money.

---

## 3. Security Architecture

### Current state: API key in Info.plist (BLOCKING)

The TestFlight audit correctly flags this. Anyone with the IPA (any TestFlight user) can extract the PPQ API key from Info.plist in about 30 seconds with a tool like `ipatool` or just unzipping the IPA. They could then:
- Use the key directly, burning through your PPQ balance
- Hit PPQ's API from scripts at high volume
- Share the key publicly

### Option A: Server-side proxy (RECOMMENDED)

**What:** A thin proxy that holds the real API key server-side. The iOS app authenticates to the proxy, which forwards requests to PPQ/Anthropic/OpenAI.

**Cloudflare Worker implementation:**
- Free tier: 100,000 requests/day (more than enough for indie scale)
- Paid tier: $5/month for 10M requests/month
- Worker code: ~100 lines. Receives request from app, validates app identity, adds API key header, forwards to LLM provider, streams response back.
- Secrets stored in Cloudflare environment variables (never in client code)

**Vercel Edge Function alternative:**
- Free tier: 500,000 invocations/month
- Slightly more setup but similar concept

**Minimal proxy (weekend build):**
```
iOS app -> HTTPS -> Cloudflare Worker -> PPQ.ai / Anthropic API
              |
              +-- validates: app bundle ID, optional device token
              +-- adds: Bearer API key
              +-- rate limits: per-device, per-hour
```

**Complexity:** Low. The proxy is stateless — it just validates and forwards. No database needed for the MVP version.

### Option B: On-device key obfuscation

**What:** Encode/encrypt the API key in the binary so it is not plain text in Info.plist.

**Techniques:**
- XOR with a compile-time constant
- Split key across multiple files/variables
- Use Swift code generation to assemble the key at runtime

**Verdict:** Security theater. Determined attackers can still extract it via runtime debugging, memory inspection, or LLDB. Buys time against casual extraction but does not solve the problem. Not recommended as a standalone solution, but fine as a layer on top of a proxy.

### Option C: Apple App Attest + server proxy

**What:** App Attest generates a device-bound cryptographic attestation that proves requests come from a legitimate install of your app on a real Apple device. Your server validates this attestation before processing requests.

**How it works:**
1. App generates a key pair on-device via `DCAppAttestService`
2. Apple signs an attestation of the key + app identity
3. Server validates the attestation against Apple's servers
4. Subsequent requests include assertions (signed by the device key)
5. Server verifies assertions before forwarding to LLM API

**Complexity:** Medium-high. Requires:
- Server-side CBOR parsing and X.509 certificate chain validation
- Apple's attestation verification protocol (non-trivial crypto)
- Graceful fallback for simulator/debug builds (App Attest is device-only)

**Verdict:** Production-grade solution. Overkill for TestFlight but the right target for App Store launch. Prevents replay attacks, key extraction, and scripted abuse.

### Option D: Anonymous device tokens (middle ground)

**What:** On first launch, app registers with your proxy using a random UUID. Proxy issues a token. All subsequent requests include this token. Proxy rate-limits per token.

**Protections:**
- No API key on device at all
- Rate limiting prevents abuse (e.g., max 50 requests/hour per device)
- Token revocation if abuse detected

**Does NOT prevent:** Someone scripting token generation. But combined with basic checks (User-Agent, request patterns), it is good enough for TestFlight/early launch.

### Recommendation progression

| Phase | Approach | Effort |
|-------|----------|--------|
| **This week (TestFlight)** | Cloudflare Worker proxy + device UUID token + rate limiting | 4-8 hours |
| **App Store launch** | Add App Attest validation to the proxy | 1-2 days |
| **Scale** | Per-user auth (Sign in with Apple), usage tracking server-side | 1 week |

---

## 4. Pricing Model Options

### Option A: Credits (current)

**How it works:** User has a credit balance. Each LLM call deducts credits based on token usage. Users buy credit packs via IAP.

**Pros:**
- Simple mental model: "you have N credits"
- No recurring commitment for users
- Already built — StoreKit integration done
- Pay-as-you-go maps cleanly to actual API costs

**Cons:**
- "Credits" is opaque — users don't know what 1 credit buys
- Anxiety-inducing: every tap costs something, users hesitate
- No recurring revenue — spiky income from top-ups
- Apple takes 30% of IAP, so $0.99 pack yields $0.693

**Current credit packs vs actual cost:**

| Pack | Price | After Apple 30% | Credits | Cost to serve (Sonnet) | Margin |
|------|-------|-----------------|---------|----------------------|--------|
| 1,000 | $0.99 | $0.693 | 1,000 ($1.00) | ~$1.00 (67 notes) | **-$0.307 LOSS** |
| 5,000 | $3.99 | $2.793 | 5,000 ($5.00) | ~$5.00 (333 notes) | **-$2.207 LOSS** |
| 10,000 | $6.99 | $4.893 | 10,000 ($10.00) | ~$10.00 (667 notes) | **-$5.107 LOSS** |

**Every credit pack currently loses money** because 1 credit = $0.001 and the actual model cost per credit is higher than what the user pays after Apple's cut. This needs to be fixed regardless of model choice.

### Option B: Subscription

**How it works:** Monthly/yearly subscription. Unlimited (or high-cap) usage during active subscription.

**Pros:**
- Predictable recurring revenue
- Users don't think about per-use cost (reduces friction)
- Apple offers reduced 15% commission after year 1
- Can tier: Free (limited) / Pro (unlimited)

**Cons:**
- Must eat the variance in per-user API costs
- Heavy users subsidized by light users (fine at scale, dangerous at indie scale)
- Subscription fatigue — hard to get users to commit to yet another $X/month
- Need enough value to justify recurring cost

**Example tiers:**

| Tier | Price | Notes/month budget | API cost at Sonnet | API cost at Haiku |
|------|-------|-------------------|-------------------|-------------------|
| Free | $0 | 30 notes | $0.45 | $0.15 |
| Pro | $4.99/mo | 300 notes | $4.50 | $1.50 |
| Unlimited | $9.99/mo | Uncapped | Variable | Variable |

After Apple's 30% cut, Pro yields $3.49. At Sonnet prices, 300 notes costs $4.50 — still a loss. At Haiku prices, 300 notes costs $1.50 — profitable at $1.99 margin.

### Option C: Hybrid (credits + optional subscription)

**How it works:** Free starter credits. Credits for casual users who want to pay-as-they-go. Subscription for power users who want predictable monthly access.

**Pros:**
- Lets users self-select into the right model
- Credits for try-before-you-commit
- Subscription for retention

**Cons:**
- More complexity to build and maintain
- Two billing paths through StoreKit

### Comparable app pricing

| App | Model | Price | What you get |
|-----|-------|-------|-------------|
| Otter.ai | Subscription | $8.33-16.99/mo | 1,200 min transcription, AI features |
| Notion AI | Bundled | $10-20/user/mo | Included with Notion Business+ |
| Bear | Subscription | $2.99/mo | Note sync, themes (no AI) |
| Day One | Subscription | $2.99/mo | Journal sync, export (no AI) |

Murmur sits in a different niche — it is not competing with Notion or Otter on features. The closest comp is a personal voice journal/task app with AI extraction. Pricing should be lower than Otter, closer to Bear/Day One territory.

---

## 5. MVP Recommendation (This Week)

### The three-move fix for TestFlight

**Move 1: Switch to Claude Haiku 4.5** (30 minutes)

Change the default model in `PPQLLMService.init()`:
```swift
model: String = "anthropic/claude-haiku-4.5"  // was claude-sonnet-4.6
```

Why:
- 3x cheaper ($1/$5 vs $3/$15 per MTok)
- For structured extraction + tool calling on ~500 word inputs, Haiku is likely sufficient. The task is not creative writing — it is parsing intent and filling JSON schemas.
- More notes per dollar = happier TestFlight users
- Can always upgrade specific flows (e.g., daily focus keeps Sonnet) if Haiku quality is insufficient

Risk: Tool calling quality could degrade. Mitigate by running the existing scenario tests (`make core-scenarios`) against Haiku before shipping.

**Move 2: Fix ServicePricing to match model** (15 minutes)

In `AppState.configurePipeline()`, the pricing should match the actual model:
```swift
// For Haiku 4.5:
let pricing = ServicePricing(
    inputUSDPer1MMicros: 1_000_000,   // $1.00/MTok - already correct for Haiku
    outputUSDPer1MMicros: 5_000_000,  // $5.00/MTok - already correct for Haiku
    minimumChargeCredits: 1
)
```

The current pricing accidentally matches Haiku already. If you stay on Sonnet, these need to be `3_000_000` and `15_000_000`.

**Move 3: Fix credit pack pricing to not lose money** (30 minutes)

After Apple's 30% cut:
- $0.99 -> $0.693 revenue
- Need the credits to cost less than $0.693 to serve

At Haiku pricing (~$0.005/note, ~5 credits/note), 1,000 credits = 200 notes = $1.00 cost.

**Option A — Reduce credits per pack:**

| Pack | Price | After Apple | Credits | Notes (Haiku) | Cost | Margin |
|------|-------|-------------|---------|---------------|------|--------|
| 500 | $0.99 | $0.693 | 500 | 100 | $0.50 | +$0.193 |
| 3,000 | $3.99 | $2.793 | 3,000 | 600 | $3.00 | -$0.207 |
| 7,000 | $6.99 | $4.893 | 7,000 | 1,400 | $7.00 | -$2.107 |

Still tight. The fundamental issue: Apple takes 30% but API costs are pass-through.

**Option B — Redefine credit value:**

Make 1 credit = $0.0005 instead of $0.001. Then 1,000 credits = $0.50 in API cost.

| Pack | Price | After Apple | Credits | API value | Margin |
|------|-------|-------------|---------|-----------|--------|
| 1,000 | $0.99 | $0.693 | 1,000 | $0.50 | +$0.193 |
| 5,000 | $3.99 | $2.793 | 5,000 | $2.50 | +$0.293 |
| 10,000 | $6.99 | $4.893 | 10,000 | $5.00 | -$0.107 |

Better. The 10K pack is still slightly lossy (a "best value" loss leader is fine). This means each note costs ~10 credits instead of ~5 — users still get 100 notes from the starter 1,000 credits (20 days at 5/day).

**Option C — Raise pack prices:**

| Pack | Price | After Apple | Credits | API value | Margin |
|------|-------|-------------|---------|-----------|--------|
| 1,000 | $1.99 | $1.393 | 1,000 | $1.00 | +$0.393 |
| 5,000 | $7.99 | $5.593 | 5,000 | $5.00 | +$0.593 |
| 10,000 | $12.99 | $9.093 | 10,000 | $10.00 | -$0.907 |

Healthier margins but higher sticker shock.

**Recommendation for TestFlight:** Option B (redefine credit value to $0.0005/credit) + Move 1 (switch to Haiku). This gives:
- 1,000 free credits = ~100 voice notes = ~20 days of normal use
- Positive margin on the $0.99 and $3.99 packs
- Near break-even on the $6.99 pack

### API key: minimum viable security for TestFlight

For TestFlight specifically (limited, trusted testers), the key-in-Info.plist approach is acceptable IF:
1. The PPQ account has spend limits / alerts set
2. You monitor usage during the test period
3. You accept the risk that a tester could extract and misuse the key

If this is unacceptable, the Cloudflare Worker proxy is a weekend build (see Section 3).

---

## 6. Ideal Architecture (Build Toward)

### Phase 1: TestFlight (this week)
- Switch to Haiku 4.5
- Fix credit math (redefine credit value or adjust packs)
- Keep PPQ.ai as provider
- Keep key in Info.plist (accept risk for testing period)
- Run scenario tests to validate Haiku quality

### Phase 2: Pre-App Store (1-2 weekends)
- Deploy Cloudflare Worker proxy
  - Holds PPQ/Anthropic API key server-side
  - Rate limiting per device (UUID-based)
  - Usage logging (see actual costs)
  - Kill switch (can disable the proxy if costs spiral)
- Remove API key from app bundle entirely
- App hits `https://api.murmur.yourdomain.com/chat/completions` instead of `api.ppq.ai`
- Proxy forwards to PPQ (or direct Anthropic — now you can switch providers without an app update)

### Phase 3: App Store launch
- Add Apple App Attest validation to the proxy
- Consider Sign in with Apple for user identity (enables per-user rate limiting)
- Move credit ledger server-side (prevents local tampering)
- A/B test Haiku vs Sonnet quality with real users
- Evaluate subscription tier alongside credits

### Phase 4: Scale optimization
- Evaluate Gemini Flash 2.0 for the extraction path ($0.10/$0.40 per MTok — 10x cheaper than Haiku)
- Use Anthropic prompt caching for the system prompt (90% reduction on repeated system prompt tokens)
- Route different flows to different models:
  - Voice extraction: Haiku or Gemini Flash (cost-sensitive, structured output)
  - Daily focus: Haiku (simple selection task)
  - Multi-turn refinement: Sonnet (needs better reasoning)
- Server-side conversation state enables caching across requests

### Provider migration path

The proxy architecture makes provider switching trivial:

```
Current:  iOS app -> PPQ.ai (Sonnet 4.6)
Phase 2:  iOS app -> Proxy -> PPQ.ai (Haiku 4.5)
Phase 3:  iOS app -> Proxy -> Anthropic direct (Haiku 4.5)
Phase 4:  iOS app -> Proxy -> { Gemini Flash (extraction), Haiku (focus), Sonnet (refinement) }
```

No app updates needed to change providers or models — it is all server-side routing.

### The PPQ.ai question

PPQ.ai is convenient (single API key, many models, OpenAI-compatible) but has unknowns:
- Pricing markup is opaque — no published model-level pricing
- Reliability and uptime are unknown at scale
- No SLA for an indie project to lean on

Once you have a proxy, switching from PPQ to direct Anthropic API is a one-line change in the Worker. Keep PPQ for now (it works, it is wired), but the proxy gives you the escape hatch.

### Cost at scale projections

Assuming Haiku 4.5 at ~$0.005/note:

| Monthly active users | Notes/user/day | Monthly notes | Monthly API cost | Revenue needed |
|---------------------|---------------|--------------|-----------------|----------------|
| 100 | 5 | 15,000 | $75 | ~$107 (after Apple cut) |
| 1,000 | 5 | 150,000 | $750 | ~$1,071 |
| 10,000 | 5 | 1,500,000 | $7,500 | ~$10,714 |

At 1,000 MAU with a $4.99/mo subscription (yielding $3.49 after Apple), you need ~215 paying subscribers to cover API costs. That is a 21.5% conversion rate — aggressive but possible for a utility app with a good free tier.

With credits at $0.99/1,000: each paying user buying one pack/month yields $0.693. You need 1,082 pack purchases/month to cover $750 in API costs. Tighter math, which is why subscription tends to win at scale.

---

## Summary of decisions needed

| Decision | Options | Recommendation |
|----------|---------|---------------|
| Model for TestFlight | Sonnet 4.6 / Haiku 4.5 | **Haiku 4.5** (3x cheaper, test quality) |
| API key security | Info.plist / Proxy / App Attest | **Info.plist for TestFlight**, proxy before App Store |
| Credit value | $0.001 / $0.0005 per credit | **$0.0005** (makes packs profitable after Apple cut) |
| Pricing model | Credits / Subscription / Hybrid | **Credits for now**, evaluate subscription post-launch |
| Provider | PPQ.ai / Direct Anthropic / OpenRouter | **PPQ.ai for now**, proxy enables future switch |
