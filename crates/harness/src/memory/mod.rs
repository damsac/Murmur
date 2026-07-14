pub mod store;
pub mod tool;

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

/// Default word cap for a whole memory (spec §7: reflection compresses, never accumulates).
pub const DEFAULT_WORD_CAP: usize = 500;

/// The one memory section read by the STT biasing layer (`collect_bias_terms`
/// → `build_bias_prompt` → whisper `initial_prompt`). Canonical name — every
/// crate references this constant rather than the bare string "vocabulary".
pub const VOCABULARY_SECTION: &str = "vocabulary";

/// Write-time cap on vocabulary terms. MUST equal `stt::SttConfig::max_bias_terms`
/// (the read-side cap); `harness` cannot depend on `stt`, so this mirrors it —
/// a Task 6 FFI test asserts they are numerically equal. iOS `contextualStrings`
/// / whisper `initial_prompt` budget (spec Rev 2 amendment F: ≤100 curated terms).
pub const MAX_VOCABULARY_TERMS: usize = 100;

/// The internal section holding applied seed-pack markers (`"{trade}:{version}"`,
/// Plan 15 D4-15). Internal (`_`-prefixed, see [`is_internal_section`]): never
/// rendered, never counted, never evicted, never pruned, carried forward
/// verbatim through reflection.
pub(crate) const SEED_MARKER_SECTION: &str = "_seeds";

/// A section whose name starts with `_` is internal bookkeeping (Plan 15
/// D5-15): excluded from `render`/`to_prompt`, `word_count`, `clamp_to_cap`
/// candidates, and `prune_stale`; carried forward through
/// `ReflectionEngine::reflect` (the fifth site); rejected by `UpdateMemoryTool`.
/// No pre-existing section is `_`-prefixed, so this is behavior-preserving.
pub(crate) fn is_internal_section(name: &str) -> bool {
    name.starts_with('_')
}

/// Max words in a single vocabulary term. Vocabulary is jargon/hotwords, not
/// sentences; this bounds the word budget (Plan 10 D3) and keeps the whisper
/// `initial_prompt` a clean glossary. A longer input is a paste error.
pub const MAX_VOCABULARY_TERM_WORDS: usize = 6;

/// Outcome of [`Memory::add_vocabulary_term`]. Total (no `Result` needed):
/// `Added`/`Duplicate` are success (idempotent); `Full`/`Empty`/`TooLong` are refusals.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VocabAdd {
    Added,
    Duplicate,
    Full,
    Empty,
    TooLong,
}

/// Where a fact came from — drives eviction priority and debuggability.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FactSource {
    /// The agent's own deduction. First to be evicted.
    Inferred,
    /// The user said it outright.
    Stated,
    /// The user corrected the agent. Never auto-pruned; last to be evicted.
    Corrected,
}

impl FactSource {
    pub fn rank(self) -> u8 {
        match self {
            FactSource::Inferred => 0,
            FactSource::Stated => 1,
            FactSource::Corrected => 2,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MemoryEntry {
    pub text: String,
    /// Unix seconds when this entry was last added, confirmed, or re-mentioned.
    pub last_touched: u64,
    pub source: FactSource,
    /// Session id this fact came from, if known.
    pub session: Option<String>,
}

/// Sectioned agent memory. Section names are consumer-defined strings
/// (e.g. "vocabulary", "people", "projects", "preferences").
/// The "vocabulary" section is read by the STT biasing layer in Plan 05
/// via [`Memory::section_texts`].
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Memory {
    pub sections: BTreeMap<String, Vec<MemoryEntry>>,
}

/// Normalize a vocabulary term for storage AND comparison: trim ends, collapse
/// internal whitespace runs to a single space. Case is preserved. Used on BOTH
/// the query and the stored text before comparing (D4, finding 1), because the
/// pre-existing writers (`UpdateMemoryTool`, reflection) store verbatim.
fn normalize_term(term: &str) -> String {
    term.split_whitespace().collect::<Vec<_>>().join(" ")
}

impl Memory {
    /// Adds `text` to `section`, or refreshes `last_touched` if the exact text exists.
    /// Defaults provenance to [`FactSource::Inferred`] with no session.
    pub fn remember(&mut self, section: &str, text: &str, now: u64) {
        self.remember_from(section, text, now, FactSource::Inferred, None);
    }

    /// Full-provenance remember. On an existing exact text: refreshes `last_touched`;
    /// upgrades `source`/`session` only if the new source ranks higher (never downgrades).
    pub fn remember_from(
        &mut self,
        section: &str,
        text: &str,
        now: u64,
        source: FactSource,
        session: Option<String>,
    ) {
        let entries = self.sections.entry(section.to_string()).or_default();
        match entries.iter_mut().find(|e| e.text == text) {
            Some(e) => {
                e.last_touched = now;
                if source.rank() > e.source.rank() {
                    e.source = source;
                    e.session = session;
                }
            }
            None => entries.push(MemoryEntry {
                text: text.to_string(),
                last_touched: now,
                source,
                session,
            }),
        }
    }

    /// Removes the exact `text` from `section`. Returns whether anything was removed.
    /// Sections left empty are dropped.
    pub fn forget(&mut self, section: &str, text: &str) -> bool {
        let Some(entries) = self.sections.get_mut(section) else {
            return false;
        };
        let before = entries.len();
        entries.retain(|e| e.text != text);
        let removed = entries.len() < before;
        if entries.is_empty() {
            self.sections.remove(section);
        }
        removed
    }

    /// Total whitespace-separated words across all entry texts. Internal
    /// (`_`-prefixed) sections are bookkeeping, not memory content — excluded
    /// (Plan 15 D5-15), so a marker never pressures the word cap.
    pub fn word_count(&self) -> usize {
        self.sections
            .iter()
            .filter(|(name, _)| !is_internal_section(name))
            .flat_map(|(_, entries)| entries)
            .map(|e| e.text.split_whitespace().count())
            .sum()
    }

    /// Entry texts of one section, in insertion order. Empty if the section is absent.
    pub fn section_texts(&self, section: &str) -> Vec<&str> {
        self.sections
            .get(section)
            .map(|es| es.iter().map(|e| e.text.as_str()).collect())
            .unwrap_or_default()
    }

    /// Markdown rendering for prompt injection: `## section` headers, `- ` entries,
    /// sections in BTreeMap (alphabetical) order. Empty memory renders as "".
    pub fn to_prompt(&self) -> String {
        self.render(false)
    }

    /// Shared rendering behind [`Memory::to_prompt`]. When `annotate_corrected`,
    /// entries with [`FactSource::Corrected`] get a trailing ` [corrected]` marker
    /// (used by the reflection engine so the model honors correction precedence).
    /// Threat model note: the marker is derived from provenance, but a fact whose
    /// text itself contains "[corrected]" could masquerade — accepted for a
    /// single-user, on-device deployment (self-poisoning only).
    pub(crate) fn render(&self, annotate_corrected: bool) -> String {
        let mut out = String::new();
        for (name, entries) in &self.sections {
            // Internal sections never reach a prompt (Plan 15 D5-15).
            if is_internal_section(name) || entries.is_empty() {
                continue;
            }
            if !out.is_empty() {
                out.push('\n');
            }
            out.push_str("## ");
            out.push_str(name);
            out.push('\n');
            for e in entries {
                out.push_str("- ");
                out.push_str(&e.text);
                if annotate_corrected && e.source == FactSource::Corrected {
                    out.push_str(" [corrected]");
                }
                out.push('\n');
            }
        }
        out
    }

    /// Removes entries whose `last_touched` is older than `max_age_secs` before `now`
    /// (spec Rev 3: forgetting is a feature). User corrections are never auto-pruned.
    /// Returns how many entries were removed.
    pub fn prune_stale(&mut self, now: u64, max_age_secs: u64) -> usize {
        let cutoff = now.saturating_sub(max_age_secs);
        let mut removed = 0;
        self.sections.retain(|name, entries| {
            // Internal sections are never aged out (Plan 15 D5-15).
            if is_internal_section(name) {
                return true;
            }
            let before = entries.len();
            entries.retain(|e| e.source == FactSource::Corrected || e.last_touched >= cutoff);
            removed += before - entries.len();
            !entries.is_empty()
        });
        removed
    }

    /// Drops entries until `word_count() <= cap`, evicting by ascending
    /// `(source rank, last_touched, section name)` — inferred-oldest first,
    /// corrected last. Ties within the same section and timestamp resolve by
    /// insertion order (deterministic, since `min_by` keeps the first minimum
    /// in iteration order). Returns how many entries were removed.
    pub fn clamp_to_cap(&mut self, cap: usize) -> usize {
        let mut removed = 0;
        while self.word_count() > cap {
            let next = self
                .sections
                .iter()
                // Internal sections are never eviction candidates (Plan 15 D5-15).
                .filter(|(name, _)| !is_internal_section(name))
                .flat_map(|(name, entries)| {
                    entries
                        .iter()
                        .map(move |e| ((e.source.rank(), e.last_touched, name.clone()), e.text.clone()))
                })
                .min_by(|a, b| a.0.cmp(&b.0));
            let Some(((_, _, section), text)) = next else { break };
            self.forget(&section, &text);
            removed += 1;
        }
        removed
    }

    /// The user's vocabulary terms in insertion order, stored text AS-IS
    /// (alias for `section_texts(VOCABULARY_SECTION)`). No normalization on read.
    pub fn vocabulary_terms(&self) -> Vec<&str> {
        self.section_texts(VOCABULARY_SECTION)
    }

    /// Stored casing of the term that matches `normalized` case-insensitively,
    /// normalizing the STORED side too (finding 1). `None` if absent.
    fn matching_vocabulary_term(&self, normalized: &str) -> Option<String> {
        self.section_texts(VOCABULARY_SECTION)
            .into_iter()
            .find(|t| normalize_term(t).eq_ignore_ascii_case(normalized))
            .map(str::to_string)
    }

    /// Add one vocabulary term. Normalizes (trim + collapse whitespace), rejects
    /// empty (`Empty`) and >`MAX_VOCABULARY_TERM_WORDS` (`TooLong`), dedups
    /// case-insensitively across BOTH sides (keeps first-seen stored casing),
    /// and enforces `MAX_VOCABULARY_TERMS` at write time (`Full` — reject, never
    /// silent-evict). `source` is `Stated` for user/onboarding terms; a future
    /// auto-harvester (D9) passes `Inferred`. Does NOT enforce the 500-word cap —
    /// callers clamp globally (the FFI layer / `UpdateMemoryTool` do).
    pub fn add_vocabulary_term(&mut self, term: &str, now: u64, source: FactSource) -> VocabAdd {
        let normalized = normalize_term(term);
        if normalized.is_empty() {
            return VocabAdd::Empty;
        }
        if normalized.split_whitespace().count() > MAX_VOCABULARY_TERM_WORDS {
            return VocabAdd::TooLong;
        }
        if let Some(stored) = self.matching_vocabulary_term(&normalized) {
            // Duplicate (even at cap): touch/upgrade provenance on the STORED
            // casing via remember_from; never add a second variant.
            self.remember_from(VOCABULARY_SECTION, &stored, now, source, None);
            return VocabAdd::Duplicate;
        }
        if self.vocabulary_terms().len() >= MAX_VOCABULARY_TERMS {
            return VocabAdd::Full;
        }
        self.remember_from(VOCABULARY_SECTION, &normalized, now, source, None);
        VocabAdd::Added
    }

    /// Record that seed pack `key` (`"{trade}:{version}"`) has been applied
    /// (Plan 15 D4-15). Idempotent — marking twice keeps one entry. `now = 0`
    /// is fine: markers ride an internal section and are never aged or evicted.
    pub fn mark_pack_seeded(&mut self, key: &str) {
        self.remember_from(SEED_MARKER_SECTION, key, 0, FactSource::Stated, None);
    }

    /// Whether seed pack `key` has already been applied (Plan 15 D4-15).
    pub fn is_pack_seeded(&self, key: &str) -> bool {
        self.section_texts(SEED_MARKER_SECTION).contains(&key)
    }

    /// Remove one vocabulary term (case-insensitive; normalizes BOTH sides so a
    /// verbatim-stored term written by another path is still removable — finding
    /// 1). Returns whether anything was removed.
    pub fn remove_vocabulary_term(&mut self, term: &str) -> bool {
        let normalized = normalize_term(term);
        let Some(stored) = self.matching_vocabulary_term(&normalized) else {
            return false;
        };
        self.forget(VOCABULARY_SECTION, &stored)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mem_with(section: &str, texts: &[(&str, u64)]) -> Memory {
        let mut m = Memory::default();
        for (t, at) in texts {
            m.remember(section, t, *at);
        }
        m
    }

    #[test]
    fn remember_adds_and_touches_existing() {
        let mut m = Memory::default();
        m.remember("people", "Dev \u{2014} framer", 100);
        m.remember("people", "Dev \u{2014} framer", 200); // same text: touch, don't duplicate
        assert_eq!(m.sections["people"].len(), 1);
        assert_eq!(m.sections["people"][0].last_touched, 200);
        assert_eq!(m.sections["people"][0].source, FactSource::Inferred);
    }

    #[test]
    fn source_upgrades_but_never_downgrades() {
        let mut m = Memory::default();
        m.remember_from("people", "Dev \u{2014} framer", 100, FactSource::Corrected, Some("s3".into()));
        m.remember("people", "Dev \u{2014} framer", 200); // inferred touch
        let e = &m.sections["people"][0];
        assert_eq!(e.last_touched, 200);
        assert_eq!(e.source, FactSource::Corrected);
        assert_eq!(e.session.as_deref(), Some("s3"));
        m.remember_from("people", "Dev \u{2014} framer", 300, FactSource::Stated, Some("s9".into()));
        assert_eq!(m.sections["people"][0].source, FactSource::Corrected, "no downgrade");
    }

    #[test]
    fn forget_removes_and_reports() {
        let mut m = mem_with("people", &[("Dev \u{2014} framer", 100)]);
        assert!(m.forget("people", "Dev \u{2014} framer"));
        assert!(!m.forget("people", "Dev \u{2014} framer"));
        assert!(!m.sections.contains_key("people"), "empty sections are dropped");
    }

    #[test]
    fn word_count_counts_entry_words() {
        let m = mem_with("vocabulary", &[("bark mulch", 1), ("french drain", 1)]);
        assert_eq!(m.word_count(), 4);
    }

    #[test]
    fn to_prompt_renders_sections_in_order() {
        let mut m = mem_with("people", &[("Dev \u{2014} framer", 1)]);
        m.remember("jobs", "Johnson remodel \u{2014} active", 1);
        assert_eq!(
            m.to_prompt(),
            "## jobs\n- Johnson remodel \u{2014} active\n\n## people\n- Dev \u{2014} framer\n"
        );
    }

    #[test]
    fn to_prompt_empty_memory_is_empty_string() {
        assert_eq!(Memory::default().to_prompt(), "");
    }

    #[test]
    fn section_texts_accessor() {
        let m = mem_with("vocabulary", &[("skid steer", 1), ("french drain", 1)]);
        assert_eq!(m.section_texts("vocabulary"), vec!["skid steer", "french drain"]);
        assert!(m.section_texts("nope").is_empty());
    }

    #[test]
    fn prune_stale_drops_old_entries_and_empty_sections() {
        let mut m = Memory::default();
        m.remember("people", "old contact", 100);
        m.remember("people", "fresh contact", 900);
        m.remember("jobs", "ancient job", 50);
        let removed = m.prune_stale(1000, 500); // older than 500s ago goes
        assert_eq!(removed, 2);
        assert_eq!(m.section_texts("people"), vec!["fresh contact"]);
        assert!(!m.sections.contains_key("jobs"));
    }

    #[test]
    fn clamp_to_cap_drops_oldest_first() {
        let mut m = Memory::default();
        m.remember("a", "one two three", 100); // 3 words, oldest
        m.remember("b", "four five", 200); // 2 words
        m.remember("c", "six seven eight nine", 300); // 4 words, newest
        let removed = m.clamp_to_cap(6);
        assert_eq!(removed, 1, "dropping the oldest entry reaches the cap");
        assert_eq!(m.word_count(), 6);
        assert!(!m.sections.contains_key("a"));
        assert_eq!(m.section_texts("b"), vec!["four five"]);
        assert_eq!(m.section_texts("c"), vec!["six seven eight nine"]);
    }

    #[test]
    fn clamp_to_cap_noop_when_within() {
        let mut m = Memory::default();
        m.remember("a", "one two", 100);
        assert_eq!(m.clamp_to_cap(10), 0);
        assert_eq!(m.word_count(), 2);
    }

    #[test]
    fn corrected_facts_survive_pruning_and_evict_last() {
        let mut m = Memory::default();
        m.remember_from("people", "Dev not Dave", 10, FactSource::Corrected, None);
        m.remember("people", "likes early starts", 9);
        assert_eq!(m.prune_stale(1000, 100), 1, "only the inferred fact prunes");
        assert_eq!(m.section_texts("people"), vec!["Dev not Dave"]);

        m.remember_from("a", "one two three four", 500, FactSource::Stated, None);
        // cap forces eviction: inferred gone already; stated (rank 1) goes before corrected (rank 2)
        m.clamp_to_cap(3);
        assert_eq!(m.section_texts("people"), vec!["Dev not Dave"]);
        assert!(!m.sections.contains_key("a"));

        // Corrected facts are last to go, not immune: with only Corrected
        // entries left, clamp_to_cap still evicts to honor the cap.
        m.remember_from("people", "prefers text over calls", 20, FactSource::Corrected, None);
        assert_eq!(m.word_count(), 7); // "Dev not Dave" (3) + new entry (4)
        let removed = m.clamp_to_cap(4);
        assert_eq!(removed, 1, "oldest corrected entry is evicted");
        assert!(m.word_count() <= 4);
        assert_eq!(m.section_texts("people"), vec!["prefers text over calls"]);
    }

    #[test]
    fn add_vocabulary_term_normalizes_and_defaults_stated() {
        let mut m = Memory::default();
        assert_eq!(m.add_vocabulary_term("  french   drain ", 10, FactSource::Stated), VocabAdd::Added);
        // normalized: trimmed + internal whitespace collapsed
        assert_eq!(m.vocabulary_terms(), vec!["french drain"]);
        let e = &m.sections[VOCABULARY_SECTION][0];
        assert_eq!(e.source, FactSource::Stated, "user vocabulary is Stated (survives casual eviction)");
        assert_eq!(e.last_touched, 10);
    }

    #[test]
    fn add_vocabulary_term_is_case_insensitively_idempotent() {
        let mut m = Memory::default();
        assert_eq!(m.add_vocabulary_term("French Drain", 1, FactSource::Stated), VocabAdd::Added);
        assert_eq!(m.add_vocabulary_term("french drain", 2, FactSource::Stated), VocabAdd::Duplicate);
        assert_eq!(m.vocabulary_terms(), vec!["French Drain"], "first-seen casing kept, one slot used");
    }

    #[test]
    fn add_vocabulary_term_rejects_empty_and_overlong() {
        let mut m = Memory::default();
        assert_eq!(m.add_vocabulary_term("   ", 1, FactSource::Stated), VocabAdd::Empty);
        // > MAX_VOCABULARY_TERM_WORDS (6): a sentence, not a term.
        assert_eq!(
            m.add_vocabulary_term("one two three four five six seven", 1, FactSource::Stated),
            VocabAdd::TooLong,
        );
        assert!(m.vocabulary_terms().is_empty());
        // exactly 6 words is allowed
        assert_eq!(m.add_vocabulary_term("a b c d e f", 1, FactSource::Stated), VocabAdd::Added);
    }

    #[test]
    fn matching_normalizes_the_stored_side_too() {
        // finding 1: a pre-existing term written by another path (update_memory /
        // reflection) with un-collapsed whitespace must still dedupe AND be removable.
        let mut m = Memory::default();
        m.remember_from(VOCABULARY_SECTION, "french   drain", 1, FactSource::Stated, None); // double space, verbatim
        assert_eq!(m.vocabulary_terms(), vec!["french   drain"], "stored text is listed as-is");
        // dedupe: adding the normalized form does not create a near-duplicate
        assert_eq!(m.add_vocabulary_term("french drain", 2, FactSource::Stated), VocabAdd::Duplicate);
        assert_eq!(m.vocabulary_terms().len(), 1);
        // removable despite the whitespace/casing mismatch
        assert!(m.remove_vocabulary_term("French Drain"), "normalize both sides before compare");
        assert!(m.vocabulary_terms().is_empty());
    }

    #[test]
    fn add_vocabulary_term_enforces_the_hundred_term_cap() {
        let mut m = Memory::default();
        for i in 0..MAX_VOCABULARY_TERMS {
            assert_eq!(m.add_vocabulary_term(&format!("term{i}"), 1, FactSource::Stated), VocabAdd::Added);
        }
        assert_eq!(m.vocabulary_terms().len(), MAX_VOCABULARY_TERMS);
        assert_eq!(m.add_vocabulary_term("one too many", 1, FactSource::Stated), VocabAdd::Full);
        assert_eq!(m.vocabulary_terms().len(), MAX_VOCABULARY_TERMS, "cap holds; nothing silently evicted");
        // a duplicate is NOT rejected as full — idempotent even at cap
        assert_eq!(m.add_vocabulary_term("term0", 2, FactSource::Stated), VocabAdd::Duplicate);
    }

    #[test]
    fn remove_vocabulary_term_is_case_insensitive_and_reports() {
        let mut m = Memory::default();
        m.add_vocabulary_term("French Drain", 1, FactSource::Stated);
        assert!(m.remove_vocabulary_term("french drain"), "case-insensitive match");
        assert!(m.vocabulary_terms().is_empty());
        assert!(!m.remove_vocabulary_term("french drain"), "already gone");
    }

    // ---- Plan 15 D5-15: internal `_`-prefixed sections ----

    #[test]
    fn internal_sections_are_excluded_from_prompt_rendering() {
        let mut m = mem_with("vocabulary", &[("french drain", 1)]);
        m.remember_from("_seeds", "landscape:1", 0, FactSource::Stated, None);
        let p = m.to_prompt();
        assert!(!p.contains("_seeds"), "internal section leaked into the prompt");
        assert!(!p.contains("landscape:1"), "marker text leaked into the prompt");
        assert!(p.contains("## vocabulary") && p.contains("- french drain"));
    }

    #[test]
    fn internal_sections_are_excluded_from_word_count() {
        let mut m = mem_with("vocabulary", &[("bark mulch", 1)]);
        assert_eq!(m.word_count(), 2);
        m.remember_from("_seeds", "landscape:1", 0, FactSource::Stated, None);
        assert_eq!(m.word_count(), 2, "marker words must not count toward the cap");
    }

    #[test]
    fn clamp_to_cap_never_evicts_internal_sections() {
        let mut m = Memory::default();
        m.remember_from("_seeds", "landscape:1", 0, FactSource::Stated, None);
        m.add_vocabulary_term("bark mulch", 100, FactSource::Stated);
        m.add_vocabulary_term("french drain", 200, FactSource::Stated);
        // Clamp to ZERO budget: every vocabulary entry must go, marker survives.
        let removed = m.clamp_to_cap(0);
        assert_eq!(removed, 2, "both vocabulary entries evicted");
        assert!(m.vocabulary_terms().is_empty());
        assert!(m.is_pack_seeded("landscape:1"), "marker survives to zero remaining budget");
    }

    #[test]
    fn prune_stale_keeps_internal_sections() {
        let mut m = Memory::default();
        m.remember_from("_seeds", "landscape:1", 0, FactSource::Stated, None); // ancient
        m.remember("people", "old contact", 0);
        let removed = m.prune_stale(1_000_000, 10);
        assert_eq!(removed, 1, "only the real stale entry prunes");
        assert!(m.is_pack_seeded("landscape:1"), "marker is never aged out");
        assert!(!m.sections.contains_key("people"));
    }

    #[test]
    fn mark_and_query_pack_seeded() {
        let mut m = Memory::default();
        assert!(!m.is_pack_seeded("landscape:1"));
        m.mark_pack_seeded("landscape:1");
        assert!(m.is_pack_seeded("landscape:1"));
        assert!(!m.is_pack_seeded("property:1"));
        m.mark_pack_seeded("landscape:1"); // marking twice is idempotent
        assert_eq!(m.sections[SEED_MARKER_SECTION].len(), 1);
    }

    #[test]
    fn normal_sections_still_render_count_and_evict() {
        // Regression pin: the `_` exclusion must not change non-`_` behavior.
        let mut m = mem_with("vocabulary", &[("skid steer", 100)]);
        m.remember("people", "Dev \u{2014} framer", 600);
        assert!(m.to_prompt().contains("## vocabulary"));
        assert!(m.to_prompt().contains("## people"));
        assert_eq!(m.word_count(), 5);
        assert_eq!(m.clamp_to_cap(3), 1, "normal sections still evictable");
        assert!(!m.sections.contains_key("vocabulary"), "oldest normal entry evicted");
        assert_eq!(m.prune_stale(1000, 500), 0);
        assert_eq!(m.prune_stale(1000, 100), 1, "normal sections still prune");
    }

    #[test]
    fn inferred_vocabulary_is_evicted_before_stated_vocabulary() {
        // D3: an auto-harvested (Inferred) term goes before a user (Stated) term under cap pressure.
        let mut m = Memory::default();
        m.add_vocabulary_term("user term one", 100, FactSource::Stated);   // 3 words
        m.add_vocabulary_term("harvested term", 200, FactSource::Inferred); // 2 words, newer
        m.clamp_to_cap(3); // must drop the Inferred one despite it being newer
        assert_eq!(m.vocabulary_terms(), vec!["user term one"]);
    }
}
