use crate::SttError;

/// Per-word timing within a segment (whisper `token_timestamps`, chunk-relative
/// centiseconds — same reference as `RawSegment.start_cs`/`end_cs`). Additive:
/// an empty `RawSegment.words` means "no word timing", and the `Finalizer`
/// degrades to segment-coarse spans (Plan 09 D4). `text` is carried so the
/// finalizer can cross-check alignment against the segment text and self-heal.
#[derive(Clone, Debug, PartialEq)]
pub struct WordTiming {
    pub text: String,
    pub start_cs: i64,
    pub end_cs: i64,
}

/// One decoded segment as whisper.cpp emits it: timestamps are CHUNK-RELATIVE
/// centiseconds (offset to absolute audio time by the engine, not here).
#[derive(Clone, Debug, PartialEq)]
pub struct RawSegment {
    pub start_cs: i64,
    pub end_cs: i64,
    pub text: String,
    /// whisper's per-segment "no speech" probability (Plan 08 Task 11b, R3).
    /// High values mean the model thinks this span is silence/noise it
    /// fluently hallucinated text over; the `Finalizer` drops segments above
    /// `SttConfig.no_speech_prob_threshold`. Default `0.0` (always keep) so the
    /// field is additive — non-whisper decoders (`ScriptedDecoder`) and all
    /// Plan-06 tests are unaffected. `WhisperDecoder` populates it from
    /// `whisper_state`.
    pub no_speech_prob: f32,
    /// Per-word timing (Plan 09 D3, whisper `token_timestamps`). Additive:
    /// default empty means "no word timing available", so the `Finalizer`
    /// degrades to segment-coarse spans (D4). `ScriptedDecoder` and every
    /// Plan-06/08 test keep passing with `words: vec![]`; `WhisperDecoder`
    /// populates it from token `t0`/`t1` when `word_timestamps` is on.
    pub words: Vec<WordTiming>,
}

impl RawSegment {
    /// Attach per-word timing to a base segment. Convenience for word-scripted
    /// tests and the whisper populate path; no effect on `ScriptedDecoder`.
    pub fn with_words(base: RawSegment, words: Vec<WordTiming>) -> Self {
        RawSegment { words, ..base }
    }
}

/// The one seam that touches whisper. Everything above it (chunk cutting,
/// overlap, LocalAgreement finalize, bias prompt) is pure and testable against
/// a fake. `decode` runs ONE window of samples with an optional `initial_prompt`
/// (the biasing surface). Implementations may be slow (Metal); the caller runs
/// them off the real-time thread (see `SttStream::poll`).
pub trait Decoder: Send {
    fn decode(&mut self, samples: &[f32], initial_prompt: Option<&str>)
        -> Result<Vec<RawSegment>, SttError>;
}

/// Test/example fake: replays scripted segment lists and records the prompts it
/// was handed, so the pure engine can be exercised with zero whisper dependency.
pub struct ScriptedDecoder {
    scripts: std::collections::VecDeque<Vec<RawSegment>>,
    captured_prompts: Vec<Option<String>>,
}

impl ScriptedDecoder {
    pub fn new(scripts: Vec<Vec<RawSegment>>) -> Self {
        Self { scripts: scripts.into(), captured_prompts: Vec::new() }
    }
    pub fn captured_prompts(&self) -> &[Option<String>] {
        &self.captured_prompts
    }
}

impl Decoder for ScriptedDecoder {
    fn decode(&mut self, _samples: &[f32], initial_prompt: Option<&str>)
        -> Result<Vec<RawSegment>, SttError> {
        self.captured_prompts.push(initial_prompt.map(str::to_string));
        self.scripts
            .pop_front()
            .ok_or_else(|| SttError::Decode("scripted decoder exhausted".into()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scripted_decoder_returns_scripts_in_order_and_captures_prompts() {
        let mut d = ScriptedDecoder::new(vec![
            vec![RawSegment { start_cs: 0, end_cs: 200, text: "hello world".into(), no_speech_prob: 0.0, words: vec![] }],
            vec![RawSegment { start_cs: 0, end_cs: 150, text: "again now".into(), no_speech_prob: 0.0, words: vec![] }],
        ]);
        let a = d.decode(&[0.0; 16], Some("french drain, ledger")).unwrap();
        assert_eq!(a[0].text, "hello world");
        let b = d.decode(&[0.0; 16], None).unwrap();
        assert_eq!(b[0].text, "again now");
        assert_eq!(d.captured_prompts(), &[Some("french drain, ledger".to_string()), None]);
    }

    #[test]
    fn scripted_decoder_errors_when_exhausted() {
        let mut d = ScriptedDecoder::new(vec![]);
        assert!(matches!(d.decode(&[0.0; 8], None), Err(SttError::Decode(_))));
    }

    #[test]
    fn raw_segment_defaults_to_no_word_timing() {
        let s = RawSegment { start_cs: 0, end_cs: 200, text: "hello world".into(),
            no_speech_prob: 0.0, words: vec![] };
        assert!(s.words.is_empty(), "empty words = degrade to segment-coarse");
    }

    #[test]
    fn with_words_builds_a_timed_segment_from_a_base() {
        // Ergonomic constructor for word-scripted tests: base carries text/span/nsp,
        // words carries per-word timing. No change to ScriptedDecoder.
        let s = RawSegment::with_words(
            RawSegment { start_cs: 0, end_cs: 300, text: "order twelve".into(),
                no_speech_prob: 0.0, words: vec![] },
            vec![
                WordTiming { text: "order".into(),  start_cs: 0,   end_cs: 120 },
                WordTiming { text: "twelve".into(), start_cs: 120, end_cs: 300 },
            ],
        );
        assert_eq!(s.words.len(), 2);
        assert_eq!(s.words[1].end_cs, 300);
        assert_eq!(s.text, "order twelve", "base text preserved");
    }

    #[test]
    fn scripted_decoder_replays_word_timed_segments_unchanged() {
        // The whole point of D3/D6: ScriptedDecoder needs NO change to script timings.
        let mut d = ScriptedDecoder::new(vec![vec![RawSegment::with_words(
            RawSegment { start_cs: 0, end_cs: 200, text: "french drain".into(),
                no_speech_prob: 0.0, words: vec![] },
            vec![
                WordTiming { text: "french".into(), start_cs: 0,  end_cs: 80 },
                WordTiming { text: "drain".into(),  start_cs: 80, end_cs: 200 },
            ],
        )]]);
        let out = d.decode(&[0.0; 16], None).unwrap();
        assert_eq!(out[0].words.len(), 2);
    }
}
