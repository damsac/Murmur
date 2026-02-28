use std::io::{self, BufRead, Write};

use murmur_core::action::{AgentPipelineAction, AppAction};
use murmur_core::entry::EntrySource;
use murmur_core::update::{App, AppUpdate};

fn main() {
    let api_key = std::env::var("PPQ_API_KEY").unwrap_or_default();
    if api_key.is_empty() {
        eprintln!("Error: PPQ_API_KEY environment variable not set");
        eprintln!("Usage: PPQ_API_KEY=sk-... cargo run -p murmur-cli");
        std::process::exit(1);
    }

    let db_path = std::env::var("MURMUR_DB").unwrap_or_else(|_| "murmur.db".to_string());
    let app = App::with_llm(&db_path, &api_key).expect("failed to open database");

    // Show existing entries
    print_entries(&app);

    println!("\nType a message and press Enter to send it to the agent.");
    println!("Commands: /list, /quit\n");

    let stdin = io::stdin();
    loop {
        print!("> ");
        io::stdout().flush().unwrap();

        let mut line = String::new();
        if stdin.lock().read_line(&mut line).unwrap() == 0 {
            break; // EOF
        }
        let input = line.trim();
        if input.is_empty() {
            continue;
        }

        match input {
            "/quit" | "/q" => break,
            "/list" | "/ls" => {
                print_entries(&app);
                continue;
            }
            _ => {}
        }

        println!("Processing...");
        app.dispatch(AppAction::Agent(AgentPipelineAction::ProcessTranscript {
            transcript: input.to_string(),
            source: EntrySource::Text,
        }));

        // Wait for ProcessTranscript state update (sets processing=true)
        let _ = app.recv_update();

        // Wait for agent result (ApplyAgentActions or AgentError)
        match app.recv_update() {
            Ok(AppUpdate::StateChanged(_)) => {
                let state = app.state();
                let guard = state.read().unwrap();
                if let Some(ref toast) = guard.toast {
                    println!("Error: {toast}");
                } else {
                    println!("Done.");
                }
            }
            Err(e) => {
                eprintln!("Channel error: {e}");
                break;
            }
        }

        print_entries(&app);
        println!();
    }

    println!("Bye!");
}

fn print_entries(app: &App) {
    let state = app.state();
    let guard = state.read().unwrap();
    if guard.entries.is_empty() {
        println!("(no entries)");
        return;
    }
    println!("\n--- Entries ({}) ---", guard.entries.len());
    for entry in &guard.entries {
        let pri = entry
            .priority
            .map(|p| format!("P{p}"))
            .unwrap_or_else(|| "-".into());
        println!(
            "  [{}] {} | {} | {} | {}",
            entry.short_id(),
            entry.summary,
            entry.category.display_name(),
            pri,
            entry.status.display_name(),
        );
    }
}
