# Agent Memory: Frontier Survey vs. Murmur Rebuild Design

**Date:** 2026-07-02 · **Researcher:** sonnet worker · **Commissioned by:** dam via keeper:murmur
**Purpose:** validate/critique Plan 02's memory design (sectioned 500-word capped fact memory, full-replace reflection, churn-based cadence, vocabulary→STT biasing) against the 2025–2026 frontier.

## Landscape (condensed)

- **ChatGPT Memory "Dreaming" v3** (OpenAI, 2026-06): background pass rewrites a structured profile from years of history; injected every prompt; user view/edit/delete. Criticized for limited audit trail on dropped memories. Recall 82.8%, preference adherence 71.3%.
- **Gemini personalization**: compressed `user_context` injection; weak temporal reasoning (29% on temporal sequencing).
- **Letta/MemGPT**: OS-style tiers (core in-context / recall / archival vector store); stores raw trajectories, agent-driven paging; avoids lossy extraction. DMR 93.4%.
- **Mem0 / Mem0g**: extract-then-ADD/UPDATE/DELETE against vector store (+optional knowledge graph). LoCoMo 92.5 at ~75% token reduction vs full-context. Temporal queries historically weakest.
- **Zep/Graphiti**: bitemporal knowledge graph (event time + ingestion time per edge) — contradictions timestamped, not overwritten. DMR 94.8%, 300ms P95. Heavy for on-device.
- **LangMem**: explicit semantic/episodic/procedural memory type taxonomy.
- **Verbatim chunks vs extracted artifacts** (arXiv 2601.00821): verbatim chunks beat LLM-extracted facts by 15.9–22 points on retrieval benchmarks — extraction is lossy distillation. (Doesn't bind at our scale: we inject the whole store, no retrieval.)
- **Generative Agents** (Stanford 2023): append-only stream + reflection; recency × importance × relevance scoring — importance matters, pure recency decay is wrong.
- **A-MEM** (NeurIPS 2025): Zettelkasten-linked note network; beats flat lists at retrieval scale.
- **SAGE** (arXiv 2605.30711): embedding-density novelty gate on writes (3.4× cost cut) — closest precedent to our churn signal, but write-side not cadence-side.
- **SSGM** (arXiv 2603.11768): proves unguarded rewrite memory drifts O(T·ε); bounded to O(N·ε) with pre-commit validation, temporal decay, and **dual-track storage (mutable facts + immutable episodic log)** for rollback.
- **Sleep-time compute** (arXiv 2606.03979): consolidation off the critical path (charger/idle) — 117× token reduction pattern; maps to our BGProcessingTask-as-bonus stance.

## Scorecard vs. our design

**At frontier:** tiny always-in-context memory (500 words is far below any retrieval crossover — correct architecture); flat sectioned facts (matches ChatGPT/Gemini production pattern; graphs are overkill on-device); user-visible memory (baseline expectation); update_memory tool extraction (standard); on-device/no-server (eliminates whole failure classes); **vocabulary→ASR contextual biasing (no published precedent — genuinely novel; iOS contextualStrings limit ≈100 phrases)**.

**Behind frontier (gaps):** (1) full-rewrite reflection with no rollback → catastrophic-forgetting risk (SSGM, Dreaming criticism); (2) pure LRU staleness ignores importance; (3) no provenance (which session, stated vs inferred); (4) no episodic tier for "what did we agree at Hillside in May" — *mitigated: Plan 03's session library (full sessions/reports in SQLite, searchable) is the episodic tier*.

**Deliberately simpler, justified:** no vector DB/graphs (scale); no memory-poisoning defenses (single-user on-device: the real threat is self-poisoning via bad reflection, addressed by snapshots+provenance+transparency); churn-based cadence is unvalidated-but-novel — instrument, don't trust.

## Recommendations → dispositions (decided by keeper:murmur with dam 2026-07-02)

| # | Recommendation | Disposition |
|---|---|---|
| 1 | Immutable episodic session log alongside facts | **Covered by product**: Plan 03 session records/reports are the episodic log; reflection activity input derives from them |
| 2 | Importance-aware eviction, not pure LRU | **Adopted now** (Plan 02 Rev 2): source-ranked eviction; corrected facts never auto-pruned |
| 3 | Pre-commit contradiction check | **Partial now**: reflection prompt guidance (drop stale fact, don't merge-mutate); full TMS machinery deferred |
| 4 | Per-fact provenance (session + stated/inferred/corrected) | **Adopted now** (Plan 02 Rev 2) |
| 5 | Vocabulary section curated, ≤100 phrases, phonetically-confusable domain terms only | **Adopted as spec rule**; enforcement lands with STT (Plan 05) |
| 6 | Instrument churn before trusting it; guard against paraphrase noise | **Adopted now**: verbatim-survivor prompt rule + churn logged; cadence algorithm swappable |
| 7 | Episodic retrieval tier at ~100-200 sessions | **Wait for evidence**; session library + text search buys time |
| 8 | Pre-reflection snapshots (keep 3) for rollback | **Adopted now** (Plan 02 Rev 2) |

Full source list: see the researcher's report links (OpenAI Dreaming, Mem0 2026 benchmarks, Zep arXiv 2501.13956, SSGM 2603.11768, SAGE 2605.30711, verbatim-chunks 2601.00821, A-MEM NeurIPS 2025, sleep-time 2606.03979, contextual biasing 2410.18363, episodic-memory position paper 2502.06975).
