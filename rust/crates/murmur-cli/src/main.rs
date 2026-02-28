use murmur_core::state::AppState;

fn main() {
    let state = AppState::new();
    println!("Murmur CLI — state rev: {}, entries: {}", state.rev, state.entries.len());
    println!("(interactive mode not yet implemented)");
}
