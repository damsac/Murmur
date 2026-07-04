// T0 scaffold: minimal entry point to prove whisper-rs + whisper.cpp (Metal) builds.
// Real CLI subcommands (bench|stream|accuracy|bias) land in later tasks.
fn main() {
    // Reference the crate so the linker pulls in whisper.cpp — proves the native build.
    fn _assert_type<T>() {}
    _assert_type::<whisper_rs::WhisperContext>();
    println!("stt-whisper-spike scaffold: whisper-rs linked OK");
}
