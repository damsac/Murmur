// Deterministic synthetic construction-site noise (Plan 08 Task 12).
//
// SPIKE-GRADE PROXY (deviation from the plan's "public corpora"): ESC-50 /
// FSD50K / freesound are not reachable from the sandbox, so we SYNTHESIZE the
// characteristic spectral/temporal signatures of four jobsite sources and mix
// them into the TTS speech at a target SNR. This is honest for RELATIVE
// comparison (base.en vs small.en, threshold tuning) and for the R3
// hallucination probe (does whisper invent text over machinery drone on a
// noise-ONLY clip?), but it is NOT an absolute WER claim on real ambience.
// Real jobsite recordings remain the aspirational corpus (Plan 06 note).
//
// No `rand` crate: a fixed-seed xorshift keeps every clip byte-reproducible so
// the RESULTS table is regenerable.

const SR: f64 = 16_000.0;
const TAU: f64 = std::f64::consts::TAU;

struct Xorshift(u64);
impl Xorshift {
    fn new(seed: u64) -> Self {
        Self(seed)
    }
    /// uniform [0,1)
    fn unit(&mut self) -> f64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        (self.0 >> 11) as f64 / (1u64 << 53) as f64
    }
    /// uniform [-1,1)
    fn bipolar(&mut self) -> f64 {
        self.unit() * 2.0 - 1.0
    }
}

/// Generate `n` samples of the named noise, normalized to unit RMS so `mix`
/// can scale it to any target power cleanly.
pub fn generate(kind: &str, n: usize) -> Vec<f32> {
    let mut v = match kind {
        "jackhammer" => jackhammer(n),
        "saw" => saw(n),
        "generator" => generator(n),
        "wind" => wind(n),
        "white" => white(n),
        other => panic!("unknown noise kind '{other}' (jackhammer|saw|generator|wind|white)"),
    };
    normalize_rms(&mut v);
    v
}

pub const KINDS: [&str; 4] = ["jackhammer", "saw", "generator", "wind"];

/// Pneumatic jackhammer: a ~12 Hz train of short broadband impacts, each a
/// sharp-attack decaying burst of white noise; near-silent between strikes.
fn jackhammer(n: usize) -> Vec<f32> {
    let mut rng = Xorshift::new(0x1234_5678_9ABC_DEF0);
    let strike_hz = 12.0;
    let period = (SR / strike_hz) as usize;
    let burst = (period as f64 * 0.35) as usize; // ~35% duty
    let mut out = vec![0.0f32; n];
    for (i, s) in out.iter_mut().enumerate() {
        let phase = i % period.max(1);
        if phase < burst {
            // exponential-decay envelope on the impact
            let env = (-(phase as f64) / (burst as f64 * 0.4)).exp();
            *s = (rng.bipolar() * env) as f32;
        }
    }
    out
}

/// Circular saw: a bright, harmonic-rich tone near 3.4 kHz, amplitude-modulated
/// at ~28 Hz (the blade-in-material growl), with a little broadband hiss.
fn saw(n: usize) -> Vec<f32> {
    let mut rng = Xorshift::new(0x0FED_CBA9_8765_4321);
    let f0 = 3400.0;
    let am = 28.0;
    let mut out = vec![0.0f32; n];
    for (i, s) in out.iter_mut().enumerate() {
        let t = i as f64 / SR;
        // sawtooth via first few harmonics
        let saw = (0..4)
            .map(|k| {
                let h = (k + 1) as f64;
                (TAU * f0 * h * t).sin() / h
            })
            .sum::<f64>();
        let env = 0.6 + 0.4 * (TAU * am * t).sin();
        *s = ((saw * env) + rng.bipolar() * 0.15) as f32;
    }
    out
}

/// Portable generator / compressor: steady low drone — a 60 Hz fundamental plus
/// harmonics and low broadband rumble. The classic "whisper hallucinates over a
/// constant machine hum" case.
fn generator(n: usize) -> Vec<f32> {
    let mut rng = Xorshift::new(0x2468_ACE0_1357_9BDF);
    let mut lp = 0.0f64; // 1-pole low-pass state for the rumble
    let mut out = vec![0.0f32; n];
    for (i, s) in out.iter_mut().enumerate() {
        let t = i as f64 / SR;
        let hum: f64 = [60.0, 120.0, 180.0, 240.0]
            .iter()
            .enumerate()
            .map(|(k, f)| (TAU * f * t).sin() / (k + 1) as f64)
            .sum();
        // low-passed white → rumble
        lp += 0.02 * (rng.bipolar() - lp);
        *s = (hum * 0.7 + lp * 3.0) as f32;
    }
    out
}

/// Wind across the mic: low-passed (pink-ish) noise with slow gusting.
fn wind(n: usize) -> Vec<f32> {
    let mut rng = Xorshift::new(0x1111_2222_3333_4444);
    let mut lp = 0.0f64;
    let mut out = vec![0.0f32; n];
    for (i, s) in out.iter_mut().enumerate() {
        let t = i as f64 / SR;
        // heavy low-pass → wind roar; slow gust envelope
        lp += 0.008 * (rng.bipolar() - lp);
        let gust = 0.5 + 0.5 * (TAU * 0.3 * t).sin();
        *s = (lp * 8.0 * gust) as f32;
    }
    out
}

fn white(n: usize) -> Vec<f32> {
    let mut rng = Xorshift::new(0x9E37_79B9_7F4A_7C15);
    (0..n).map(|_| rng.bipolar() as f32).collect()
}

fn rms(v: &[f32]) -> f64 {
    if v.is_empty() {
        return 0.0;
    }
    (v.iter().map(|&s| (s as f64) * (s as f64)).sum::<f64>() / v.len() as f64).sqrt()
}

fn normalize_rms(v: &mut [f32]) {
    let r = rms(v);
    if r > 1e-12 {
        let g = (1.0 / r) as f32;
        for s in v.iter_mut() {
            *s *= g;
        }
    }
}

/// Mix unit-RMS `noise` into `signal` at `snr_db` (noise tiles/cycles to fill).
/// Returns the mixed signal (leaves `signal` untouched).
pub fn mix_at_snr(signal: &[f32], noise: &[f32], snr_db: f64) -> Vec<f32> {
    let sig_pow =
        signal.iter().map(|&s| (s as f64) * (s as f64)).sum::<f64>() / signal.len().max(1) as f64;
    let noise_pow_target = sig_pow / 10f64.powf(snr_db / 10.0);
    let amp = noise_pow_target.sqrt(); // noise is unit-RMS (power 1) → scale = sqrt(target power)
    signal
        .iter()
        .zip(noise.iter().cycle())
        .map(|(&s, &nz)| (s as f64 + nz as f64 * amp) as f32)
        .collect()
}
