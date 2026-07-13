//! Vocabulary CRUD across UniFFI (Plan 10). The write half of the vocabulary →
//! STT biasing loop: these mutate the `Memory` "vocabulary" section that
//! `begin_walk`'s `collect_bias_terms` reads. Lock-then-save discipline mirrors
//! `harness::UpdateMemoryTool` (mutate under the lock, clamp the global cap,
//! snapshot, release, persist). Panic-free across FFI (Plan 07 CANON).

use harness::{FactSource, VocabAdd, DEFAULT_WORD_CAP};

use crate::engine::{EngineError, MurmurEngine};

/// Max terms ONE `seed_vocabulary` pass may add (Plan 15 D2-15): a per-pass
/// batch bound on the seeding funnel, NOT a Memory invariant — the 100-term
/// `harness::MAX_VOCABULARY_TERMS` cap stays the single hard invariant
/// (deliberately in a different crate so the two can't be forked/confused).
/// Reserves ~40 slots of headroom for the reflection loop's own learning.
/// // keep in sync with VocabPackTests (60)
const SEED_MAX: usize = 60;

/// The exact outcome of one [`MurmurEngine::seed_vocabulary`] pass (Plan 15).
/// `terms` is the RESULTING vocabulary (insertion order) so the onboarding
/// card updates in one round-trip, mirroring the CRUD methods.
#[derive(uniffi::Record)]
pub struct SeedReport {
    pub added: u32,
    pub duplicates: u32,
    pub skipped_over_budget: u32,
    pub skipped_full: u32,
    pub already_seeded: bool,
    pub terms: Vec<String>,
}

impl MurmurEngine {
    fn memory_err(msg: impl Into<String>) -> EngineError {
        EngineError::Memory(msg.into())
    }
}

#[uniffi::export]
impl MurmurEngine {
    /// The user's vocabulary terms, insertion order. Read-only — no lock held
    /// across FFI beyond the clone.
    pub fn list_vocabulary(&self) -> Result<Vec<String>, EngineError> {
        let mem = self.memory.lock().map_err(|_| Self::memory_err("memory lock poisoned"))?;
        Ok(mem.vocabulary_terms().into_iter().map(str::to_string).collect())
    }

    /// Add one user vocabulary term (`FactSource::Stated`, D3). Idempotent
    /// (case-insensitive). Errors: `Full` at 100 terms, `Empty` for blank input,
    /// a poisoned lock, or a persistence failure. Returns the resulting list so
    /// the editor updates in one round-trip.
    pub fn add_vocabulary_term(&self, term: String) -> Result<Vec<String>, EngineError> {
        let snapshot = {
            let mut mem = self.memory.lock().map_err(|_| Self::memory_err("memory lock poisoned"))?;
            let now = now_secs();
            match mem.add_vocabulary_term(&term, now, FactSource::Stated) {
                VocabAdd::Added | VocabAdd::Duplicate => {}
                VocabAdd::Full => {
                    return Err(Self::memory_err(format!(
                        "vocabulary is full ({} terms); remove one first",
                        harness::MAX_VOCABULARY_TERMS
                    )))
                }
                VocabAdd::Empty => return Err(Self::memory_err("term is empty")),
                VocabAdd::TooLong => {
                    return Err(Self::memory_err(format!(
                        "term is too long (max {} words)",
                        harness::MAX_VOCABULARY_TERM_WORDS
                    )))
                }
            }
            mem.clamp_to_cap(DEFAULT_WORD_CAP); // global 500-word invariant, like UpdateMemoryTool
            mem.clone()
        };
        self.memory_store.save(&snapshot).map_err(|e| EngineError::Store(e.to_string()))?;
        Ok(snapshot.vocabulary_terms().into_iter().map(str::to_string).collect())
    }

    /// Seed the vocabulary from a user-confirmed trade pack (Plan 15). A thin
    /// batch orchestrator over the EXISTING `add_vocabulary_term(_, _, Stated)`
    /// funnel (D1-15 — no new write path: normalize/dedup/word-guard/100-cap
    /// all inherited). Idempotent per `"{trade}:{version}"` via the `_seeds`
    /// marker (D4-15): a repeat call short-circuits with `already_seeded` and
    /// does NOT save, so a user-deleted seed is never resurrected. Bounded by
    /// `SEED_MAX` per pass (D2-15); a `Full` funnel refusal is tallied, never
    /// thrown (R7). Trade change is a union — nothing is removed (D6-15).
    pub fn seed_vocabulary(
        &self,
        trade: String,
        version: u32,
        terms: Vec<String>,
    ) -> Result<SeedReport, EngineError> {
        let key = format!("{trade}:{version}");
        let (report, snapshot) = {
            let mut mem = self.memory.lock().map_err(|_| Self::memory_err("memory lock poisoned"))?;
            if mem.is_pack_seeded(&key) {
                // Marker-guarded no-op: no funnel calls, no save (WE-B).
                return Ok(SeedReport {
                    added: 0,
                    duplicates: 0,
                    skipped_over_budget: 0,
                    skipped_full: 0,
                    already_seeded: true,
                    terms: mem.vocabulary_terms().into_iter().map(str::to_string).collect(),
                });
            }
            let now = now_secs();
            let (mut added, mut duplicates, mut skipped_over_budget, mut skipped_full) =
                (0u32, 0u32, 0u32, 0u32);
            for term in &terms {
                if added as usize == SEED_MAX {
                    skipped_over_budget += 1;
                    continue; // budget spent: the funnel is not called (WE-D)
                }
                match mem.add_vocabulary_term(term, now, FactSource::Stated) {
                    VocabAdd::Added => added += 1,
                    VocabAdd::Duplicate => duplicates += 1,
                    VocabAdd::Full => skipped_full += 1, // tolerate, never throw (WE-E, R7)
                    VocabAdd::Empty | VocabAdd::TooLong => {
                        // Curated packs are pre-validated by VocabPackTests
                        // (Task 4), so this is unreachable in practice; drop
                        // silently — not a cap failure, so not skipped_full.
                    }
                }
            }
            // The pack is applied even when partial (D4-15, deliberate).
            mem.mark_pack_seeded(&key);
            mem.clamp_to_cap(DEFAULT_WORD_CAP); // same discipline as the CRUD adds
            let snapshot = mem.clone();
            let report = SeedReport {
                added,
                duplicates,
                skipped_over_budget,
                skipped_full,
                already_seeded: false,
                terms: snapshot.vocabulary_terms().into_iter().map(str::to_string).collect(),
            };
            (report, snapshot)
        }; // lock dropped here, before the save (CRUD discipline)
        self.memory_store.save(&snapshot).map_err(|e| EngineError::Store(e.to_string()))?;
        Ok(report)
    }

    /// Remove one vocabulary term (case-insensitive). Returns the resulting list.
    /// Removing a term that isn't present is not an error (idempotent).
    pub fn remove_vocabulary_term(&self, term: String) -> Result<Vec<String>, EngineError> {
        let snapshot = {
            let mut mem = self.memory.lock().map_err(|_| Self::memory_err("memory lock poisoned"))?;
            mem.remove_vocabulary_term(&term);
            mem.clone()
        };
        self.memory_store.save(&snapshot).map_err(|e| EngineError::Store(e.to_string()))?;
        Ok(snapshot.vocabulary_terms().into_iter().map(str::to_string).collect())
    }
}

fn now_secs() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::engine::{MurmurEngine, Providers};
    use harness::{HarnessError, Memory, MemoryStore, MockProvider};
    use std::sync::{Arc, Mutex as StdMutex};

    struct SpyStore {
        saved: StdMutex<Vec<Memory>>,
    }
    impl MemoryStore for SpyStore {
        fn load(&self) -> Result<Memory, HarnessError> {
            Ok(Memory::default())
        }
        fn save(&self, m: &Memory) -> Result<(), HarnessError> {
            self.saved.lock().unwrap().push(m.clone());
            Ok(())
        }
    }
    fn engine(store: Arc<SpyStore>) -> Arc<MurmurEngine> {
        let s = murmur_core::Store::open_in_memory("device-a").unwrap();
        MurmurEngine::with_providers(
            s,
            Memory::default(),
            store,
            Providers {
                live: Arc::new(MockProvider::new(vec![])),
                processing: Arc::new(MockProvider::new(vec![])),
                reflection: Arc::new(MockProvider::new(vec![])),
            },
        )
    }

    #[tokio::test]
    async fn add_list_remove_round_trip_and_persist() {
        let store = Arc::new(SpyStore { saved: StdMutex::new(Vec::new()) });
        let e = engine(store.clone());
        assert_eq!(e.add_vocabulary_term("french drain".into()).unwrap(), vec!["french drain"]);
        assert_eq!(e.list_vocabulary().unwrap(), vec!["french drain"]);
        // persisted: the last save carries the term
        assert!(store.saved.lock().unwrap().last().unwrap().vocabulary_terms().contains(&"french drain"));
        assert!(e.remove_vocabulary_term("French Drain".into()).unwrap().is_empty(), "case-insensitive remove");
    }

    #[tokio::test]
    async fn add_is_idempotent_and_full_is_an_error() {
        let store = Arc::new(SpyStore { saved: StdMutex::new(Vec::new()) });
        let e = engine(store);
        e.add_vocabulary_term("term".into()).unwrap();
        assert_eq!(e.add_vocabulary_term("TERM".into()).unwrap(), vec!["term"], "duplicate is Ok, not an error");
        // fill to the cap, then the next add throws
        for i in 0..harness::MAX_VOCABULARY_TERMS {
            let _ = e.add_vocabulary_term(format!("t{i}"));
        }
        assert!(matches!(e.add_vocabulary_term("overflow".into()), Err(EngineError::Memory(_))));
        assert!(matches!(e.add_vocabulary_term("   ".into()), Err(EngineError::Memory(_))), "empty is an error");
    }

    #[test]
    fn read_side_cap_matches_the_write_side_constant() {
        // D2: the mirrored consts must agree across the crate boundary.
        assert_eq!(harness::MAX_VOCABULARY_TERMS, stt::SttConfig::default().max_bias_terms);
    }

    // ---- Plan 15: seed_vocabulary (WE-A..WE-E, hand-recomputed in the plan) ----

    /// WE-A pre-state + seed: 3 user terms, then the 12-chip landscape pack.
    fn we_a_seeded(store: &Arc<SpyStore>) -> Arc<MurmurEngine> {
        let e = engine(store.clone());
        for t in ["Hollis", "Boxwood Lane", "french drain"] {
            e.add_vocabulary_term(t.into()).unwrap();
        }
        let chips: Vec<String> = [
            "bark mulch", "French Drain", "boxwood", "zone 2", "  drip  irrigation ", "sod",
            "retaining wall", "paver", "boxwood", "hardscape", "downspout", "swale",
        ]
        .iter()
        .map(|s| s.to_string())
        .collect();
        let r = e.seed_vocabulary("landscape".into(), 1, chips).unwrap();
        assert_eq!(r.added, 10);
        assert_eq!(r.duplicates, 2);
        assert_eq!(r.skipped_over_budget, 0);
        assert_eq!(r.skipped_full, 0);
        assert!(!r.already_seeded);
        e
    }

    fn we_a_expected() -> Vec<String> {
        [
            "Hollis", "Boxwood Lane", "french drain", "bark mulch", "boxwood", "zone 2",
            "drip irrigation", "sod", "retaining wall", "paver", "hardscape", "downspout",
            "swale",
        ]
        .iter()
        .map(|s| s.to_string())
        .collect()
    }

    #[tokio::test]
    async fn we_a_seed_with_collision_and_normalization() {
        let store = Arc::new(SpyStore { saved: StdMutex::new(Vec::new()) });
        let e = we_a_seeded(&store);
        // 13 terms, insertion order, first-seen casing kept (french drain
        // stays lowercase despite the pack's "French Drain").
        assert_eq!(e.list_vocabulary().unwrap(), we_a_expected());
        // persisted: the last save carries the 13 terms AND the marker
        let saved = store.saved.lock().unwrap();
        let last = saved.last().unwrap();
        assert_eq!(
            last.vocabulary_terms().into_iter().map(str::to_string).collect::<Vec<_>>(),
            we_a_expected()
        );
        assert!(last.is_pack_seeded("landscape:1"));
    }

    #[tokio::test]
    async fn we_b_reseed_is_idempotent_and_deletion_is_durable() {
        let store = Arc::new(SpyStore { saved: StdMutex::new(Vec::new()) });
        let e = we_a_seeded(&store);
        e.remove_vocabulary_term("boxwood".into()).unwrap(); // user deletes a seed
        let saves_before = store.saved.lock().unwrap().len();
        let r = e
            .seed_vocabulary(
                "landscape".into(),
                1,
                we_a_expected(), // re-offer the same terms
            )
            .unwrap();
        assert!(r.already_seeded, "marker-guarded: same trade:version is a no-op");
        assert_eq!(r.added, 0);
        assert_eq!(r.duplicates, 0);
        assert_eq!(r.skipped_over_budget, 0);
        assert_eq!(r.skipped_full, 0);
        assert_eq!(r.terms.len(), 12, "total stays 12");
        assert!(!r.terms.iter().any(|t| t == "boxwood"), "deleted seed is NOT resurrected");
        assert_eq!(store.saved.lock().unwrap().len(), saves_before, "no-op path does not save");
    }

    #[tokio::test]
    async fn we_c_trade_change_unions_and_preserves() {
        let store = Arc::new(SpyStore { saved: StdMutex::new(Vec::new()) });
        let e = we_a_seeded(&store);
        e.remove_vocabulary_term("boxwood".into()).unwrap(); // WE-B state: 12 terms
        let pack: Vec<String> = [
            "carpet", "blinds", "water heater", "GFCI", "baseboard", "drywall", "HVAC",
            "walkthrough",
        ]
        .iter()
        .map(|s| s.to_string())
        .collect();
        let r = e.seed_vocabulary("property".into(), 1, pack.clone()).unwrap();
        assert_eq!(r.added, 8);
        assert_eq!(r.duplicates, 0);
        assert!(!r.already_seeded);
        assert_eq!(r.terms.len(), 20, "union: 12 + 8");
        // landscape seeds + user terms preserved
        for kept in ["Hollis", "french drain", "bark mulch", "swale"] {
            assert!(r.terms.iter().any(|t| t == kept), "{kept} must survive the trade change");
        }
        let saved = store.saved.lock().unwrap();
        let last = saved.last().unwrap();
        assert!(last.is_pack_seeded("landscape:1"));
        assert!(last.is_pack_seeded("property:1"));
    }

    #[tokio::test]
    async fn we_d_seed_max_bounds_one_pass() {
        let store = Arc::new(SpyStore { saved: StdMutex::new(Vec::new()) });
        let e = engine(store);
        let pack: Vec<String> = (0..70).map(|i| format!("term{i}")).collect();
        let r = e.seed_vocabulary("inspection".into(), 1, pack).unwrap();
        assert_eq!(r.added, 60, "SEED_MAX bounds one pass");
        assert_eq!(r.duplicates, 0);
        assert_eq!(r.skipped_over_budget, 10);
        assert_eq!(r.skipped_full, 0);
        assert_eq!(r.terms.len(), 60, "60 < 100 — the hard cap is never touched");
        assert!(e.list_vocabulary().unwrap().len() == 60);
    }

    #[tokio::test]
    async fn we_e_cap_backstop_tolerates_full_without_error() {
        let store = Arc::new(SpyStore { saved: StdMutex::new(Vec::new()) });
        let e = engine(store.clone());
        for i in 0..98 {
            e.add_vocabulary_term(format!("existing{i}")).unwrap();
        }
        let pack: Vec<String> = (0..5).map(|i| format!("new{i}")).collect();
        let r = e.seed_vocabulary("landscape".into(), 1, pack).unwrap(); // no throw (R7)
        assert_eq!(r.added, 2, "count reaches 100 then the funnel rejects");
        assert_eq!(r.duplicates, 0);
        assert_eq!(r.skipped_over_budget, 0);
        assert_eq!(r.skipped_full, 3);
        assert_eq!(r.terms.len(), 100, "cap holds; nothing silently evicted");
        // the pack is considered applied even though it was partial (D4-15)
        assert!(store.saved.lock().unwrap().last().unwrap().is_pack_seeded("landscape:1"));
    }
}
