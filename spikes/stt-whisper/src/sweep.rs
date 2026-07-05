// `sweep` — construction-noise SNR sweep (Plan 08 Task 12).
//
// For each model × noise-kind × SNR: mix synthetic jobsite noise into the TTS
// speech, decode, and report WER + a hallucination flag. Plus a NOISE-ONLY
// probe per kind (no speech at all): the R3 metric — does whisper invent text
// over pure machinery, and what no_speech_prob does it assign? That distribution
// is exactly what sets the Task 11 no_speech_prob threshold.
//
// Manual / not CI: needs the model files + macOS `say`-generated WAVs.

use crate::noise;
use crate::wer::{hallucination_flag, wer};
use crate::{load_wav_16k_mono, make_ctx, make_params, model_label};
use std::collections::HashMap;
use whisper_rs::WhisperContext;

const SNRS_DB: [f64; 4] = [20.0, 10.0, 5.0, 0.0];

struct SegInfo {
    text: String,
    no_speech_prob: f32,
}

/// Decode capturing per-segment no_speech_prob (the spike's shared `decode`
/// drops it; the sweep needs it for the R3 threshold call).
fn decode_with_nsp(ctx: &WhisperContext, samples: &[f32], prompt: Option<&str>) -> (String, Vec<SegInfo>) {
    let mut state = ctx.create_state().expect("create state");
    state.full(make_params(prompt), samples).expect("full decode");
    let n = state.full_n_segments();
    let mut text = String::new();
    let mut segs = Vec::with_capacity(n as usize);
    for i in 0..n {
        if let Some(seg) = state.get_segment(i) {
            let s = seg.to_str_lossy().map(|c| c.into_owned()).unwrap_or_default();
            text.push_str(&s);
            segs.push(SegInfo { text: s.trim().to_string(), no_speech_prob: seg.no_speech_probability() });
        }
    }
    (text.trim().to_string(), segs)
}

pub fn run(flags: &HashMap<String, String>) {
    // --models: comma-separated model paths (default: base.en + small.en if a
    // --modeldir is given).
    let models: Vec<String> = if let Some(m) = flags.get("models") {
        m.split(',').map(|s| s.trim().to_string()).collect()
    } else if let Some(dir) = flags.get("modeldir") {
        ["ggml-base.en-q5_1.bin", "ggml-small.en-q5_1.bin"]
            .iter()
            .map(|f| format!("{}/{f}", dir.trim_end_matches('/')))
            .collect()
    } else {
        vec![flags.get("model").expect("--model, --models, or --modeldir required").clone()]
    };
    let audio = flags.get("audio").expect("--audio required");
    let reference =
        std::fs::read_to_string(flags.get("reference").expect("--reference required")).expect("read reference");
    let (clean, dur) = load_wav_16k_mono(audio);
    let clip = audio.rsplit('/').next().unwrap().to_string();

    // Pre-generate each noise track once, tiled to the speech length.
    let noises: Vec<(&str, Vec<f32>)> =
        noise::KINDS.iter().map(|k| (*k, noise::generate(k, clean.len()))).collect();
    // A pure-noise, speech-free track (~same duration) for the R3 probe.
    let noise_only_len = clean.len();

    println!("## Task 12 — construction-noise SNR sweep\n");
    println!("Clip `{clip}` ({dur:.1} s). Synthetic noise (spike proxy — see `noise.rs`). SNRs in dB.\n");

    // ---- Table A: WER curves (per model, per noise, per SNR) ----
    println!("### Table A — WER (%) vs SNR\n");
    println!("| Model | Noise | clean | +20 dB | +10 dB | +5 dB | 0 dB | halluc @ 0 dB |");
    println!("|-------|-------|-------|--------|--------|-------|------|---------------|");
    for model in &models {
        let label = model_label(model);
        let ctx = make_ctx(model);
        // clean baseline
        let (clean_text, _) = decode_with_nsp(&ctx, &clean, None);
        let clean_wer = wer(&reference, &clean_text) * 100.0;
        for (kind, track) in &noises {
            let mut row_wer = Vec::new();
            let mut halluc0 = "no".to_string();
            for &snr in &SNRS_DB {
                let mixed = noise::mix_at_snr(&clean, track, snr);
                let (text, _) = decode_with_nsp(&ctx, &mixed, None);
                let w = wer(&reference, &text) * 100.0;
                row_wer.push(w);
                if snr == 0.0 {
                    halluc0 = hallucination_flag(&reference, &text)
                        .map(|s| format!("YES ({s})"))
                        .unwrap_or_else(|| "no".to_string());
                }
            }
            println!(
                "| {label} | {kind} | {clean_wer:.1} | {:.1} | {:.1} | {:.1} | {:.1} | {halluc0} |",
                row_wer[0], row_wer[1], row_wer[2], row_wer[3]
            );
        }
    }

    // ---- Table B: R3 probe — noise-ONLY (no speech). Invented tokens + no_speech_prob. ----
    println!("\n### Table B — R3 probe: decode of noise-ONLY clips (no speech present)\n");
    println!("Any committed token here is a hallucination. `max no_speech_prob` across segments");
    println!("is the signal the Task 11b gate keys on.\n");
    println!("| Model | Noise | segments | invented tokens | max no_speech_prob | min no_speech_prob |");
    println!("|-------|-------|----------|-----------------|--------------------|--------------------|");
    for model in &models {
        let label = model_label(model);
        let ctx = make_ctx(model);
        for kind in noise::KINDS {
            // unit-RMS noise scaled to a realistic absolute level (~0.1 RMS).
            let track = noise::generate(kind, noise_only_len);
            let clip: Vec<f32> = track.iter().map(|&s| s * 0.1).collect();
            let (_text, segs) = decode_with_nsp(&ctx, &clip, None);
            let invented: usize = segs.iter().map(|s| s.text.split_whitespace().count()).sum();
            let max_nsp = segs.iter().map(|s| s.no_speech_prob).fold(0.0f32, f32::max);
            let min_nsp = segs.iter().map(|s| s.no_speech_prob).fold(1.0f32, f32::min);
            let (max_s, min_s) = if segs.is_empty() {
                ("n/a".to_string(), "n/a".to_string())
            } else {
                (format!("{max_nsp:.3}"), format!("{min_nsp:.3}"))
            };
            println!(
                "| {label} | {kind} | {} | {invented} | {max_s} | {min_s} |",
                segs.len()
            );
        }
    }
    eprintln!("[sweep] done: {} model(s) × {} noises × {} SNRs + noise-only probe",
        models.len(), noise::KINDS.len(), SNRS_DB.len());
}
