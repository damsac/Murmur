//! On-device streaming STT over whisper.cpp (spec Rev 2 §2). PCM in → append-only
//! finalized transcript segments out, biased by the user's ≤100-term vocabulary.
//! The whisper backend is behind the `whisper` feature; the pure chunk/finalize/
//! bias logic compiles and tests everywhere with no native toolchain or model file.

mod bias;
mod chunk;
mod decoder;
mod finalize;
#[cfg(feature = "whisper")]
mod whisper;

pub use decoder::{Decoder, RawSegment, ScriptedDecoder};
#[cfg(feature = "whisper")]
pub use whisper::WhisperDecoder;

/// A finalized, never-to-be-revised transcript segment (append-only contract).
/// Timestamps are ABSOLUTE audio milliseconds from stream start. The shell
/// appends `text` to `Store::append_transcript` (Plan 05 cursor feeder).
#[derive(Clone, Debug, PartialEq)]
pub struct FinalizedSegment {
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
}

#[derive(Clone, Debug)]
pub struct SttConfig {
    /// Decode window length (spike default 5 s).
    pub chunk_secs: f64,
    /// Overlap re-decoded each window for LocalAgreement (spike default 1 s).
    pub overlap_secs: f64,
    /// Sample rate the shell must feed (whisper wants 16 kHz mono f32).
    pub sample_rate: u32,
    /// Whisper language hint ("en" for the *.en models).
    pub language: String,
    /// Hard cap on vocabulary terms injected via initial_prompt (spec: ≤100).
    pub max_bias_terms: usize,
}

impl Default for SttConfig {
    fn default() -> Self {
        Self {
            chunk_secs: 5.0,
            overlap_secs: 1.0,
            sample_rate: 16_000,
            language: "en".into(),
            max_bias_terms: 100,
        }
    }
}

impl SttConfig {
    /// Reject configs the pipeline math can't honor. `overlap_secs >= chunk_secs`
    /// makes the finalize horizon (`chunk_len_ms − overlap_ms`, u64) underflow and
    /// leaves no forward progress per window, so it is a `Config` error. Called by
    /// `SttStream::with_model` (the production constructor); `with_decoder` also
    /// guards the horizon with `saturating_sub` for the test/FFI seam.
    pub fn validate(&self) -> Result<(), SttError> {
        if self.overlap_secs >= self.chunk_secs {
            return Err(SttError::Config(format!(
                "overlap_secs ({}) must be < chunk_secs ({})",
                self.overlap_secs, self.chunk_secs
            )));
        }
        Ok(())
    }
}

#[derive(Debug, thiserror::Error)]
pub enum SttError {
    #[error("model load failed: {0}")]
    ModelLoad(String),
    #[error("decode failed: {0}")]
    Decode(String),
    #[error("invalid config: {0}")]
    Config(String),
}
