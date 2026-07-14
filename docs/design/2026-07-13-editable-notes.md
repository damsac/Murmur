# Editable notes — correcting the walk at review

**Owner:** sac (UI) · **Needs dam:** the core item-mutation seam (§3) — this is the whole gate · **Status:** spec for dam, nothing app-side until the seam lands (sac's call, per Isaac).

Let the operator fix the AI's output at the point of review — a mis-heard word ("Power" → "Mower"), a wrong quantity, a line that should be added or removed — and have the fix **propagate to the document they send**, not just change pixels on one screen.

---

## 1. Thinking

This is trust-critical. The walk's output is *someone's estimate* — if the crew can't correct "power edger" back to "mower" before it goes to a client, the whole "voice → paperwork" promise breaks the first time whisper mishears. Isaac's framing: **everything you see should be editable if you tap it.**

The catch, and why this is a spec and not a PR: **the notes come from the core.** Today the only editable surface is the document's **amounts**, and that's `beginEdit`/`commitEdit` mutating the built `DocumentModel` **app-side** — the core never hears it. If we let the operator edit a *notes item* app-side the same way, the correction dies on that screen: `buildDocument(kind:)` rebuilds from the core's stored items, so the estimate still says "Power." A correction that doesn't reach the document is worse than none — it looks fixed and isn't.

So the fix has to live where the item lives: **the core.** That's your seam.

## 2. What I found (grounding)

- **`CapturedItem`** (domain.rs): `id, session_id, kind, text, source, done, created_at, updated_at, device_id`. **No price** — pricing is a `buildDocument` concern, not an item field.
- **`BoardItem`** (FFI): `id, kind, text, right, photo_count` — `right` is the quantity/unit string ("3 CU YD", "× 4").
- **Store already has** `add_item` / `add_item_with_source` (manual insert — `ItemSource` distinguishes it) and `set_item_done`. **It does not have** a way to edit an item's `text` / `kind` / `right`. `set_item_done` is the exact pattern the new mutation should mirror.

So two of the three things Isaac wants are close: *add a line* (store supports it, needs FFI + UI), *fix the text* (needs a new mutation + FFI). The third — *set a price* — is document-side and already app-editable (see §5).

## 3. The seam I need from you, dam

Mirror `set_item_done`. Roughly:

```
// core: store/items.rs — updated_at bumps, tombstone/sync story unchanged
pub fn update_item(&self, id: &str, text: Option<&str>, kind: Option<&str>, right: Option<&str>) -> Result<CapturedItem, CoreError>

// ffi: WalkSession / engine-keyed (works on a Processed session, like build_document)
update_item(session_id, item_id, text?, kind?, right?) -> BoardItem
add_item(session_id, kind, text, right) -> BoardItem      // expose the existing manual add
remove_item(session_id, item_id)                          // soft/tombstone — your call (§4.4)
```

With that, the app calls `update_item` on an edit; the store is the source of truth; every later `buildDocument` reflects it for free. Same shape as your vocabulary / photo CRUD.

## 4. Design questions (your lane)

1. **Mutable fields.** `text` + `right` (quantity) cover Isaac's examples. Include `kind` (retag red/green/scope) too? I'd say yes — it's the same call and it lets the operator re-file a mis-categorized line.
2. **Pricing.** Items carry no price; the estimate assigns amounts at build (and the "LAST 3: $110·$120·$125" hint means *some* price memory already exists somewhere). Question: does price stay a **document-only** edit (app-side, as today), or does a per-item **price-book** belong in the core so remembered prices survive across walks? Recommend: **document-only for v1**; price-book is its own effort.
3. **Corrections → learning.** An edit is an R7 correction — `record_correction()` exists. A fixed mis-hear is a *strong* signal for STT/vocab biasing (the operator just told us the right word). Should `update_item` feed reflection + auto-suggest the corrected term into vocabulary? Big lever for the whisper→vocab loop, but your reflection design owns it.
4. **Delete semantics.** Soft (tombstone / a `removed` flag, sync-safe) vs hard? `done` already exists — is "remove a line from the estimate" the same as done, or a distinct state?
5. **Narrative buckets.** The notes *buckets* (Scope of Work / Constraints / Conditions) are `write_notes`-derived (Plan 14), not stored items — editing those is a different seam. In scope, or items-only for v1? Recommend **items-only first**; the buckets are the harder, later piece.
6. **Concurrency / re-extraction.** After `finish()` the session is Processed and ids are stable (the "re-extraction mints new ids" hazard is live-walk only) — so an edit keyed by `item_id` is safe post-finish. Confirm that holds.

## 5. The app-side plan (mine, once the seam lands)

- **Notes screen:** tap an item → inline edit its text / quantity (same interaction as the document's amount edit today); commit calls `update_item`. An "＋ add line" affordance calls `add_item`. Swipe/✕ to remove calls `remove_item`.
- **Document/estimate:** amounts stay tap-editable app-side (they're a build-time concern, no core round-trip needed). Optionally also let text be fixed here — but with the seam, fixing on notes already propagates, so this may be redundant.
- **Result:** one mental model — tap anything to fix it — with corrections that actually reach the PDF.

## 6. Phasing

v1: your `update_item`/`add_item`/`remove_item` seam → my tap-to-edit on notes items (text/qty/add/remove). v2: corrections → vocab/reflection (§4.3), and editable narrative buckets (§4.5). Pricing/price-book (§4.2) is a separate track.

## 7. Boundary

Core owns the item mutation + the sync/reflection consequences (dam). The tap-to-edit UI + interaction is mine. Reactions in-line — I'll turn the answers into a build plan the moment the seam has a shape.
