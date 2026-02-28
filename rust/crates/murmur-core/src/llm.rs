use serde::Deserialize;

use crate::action::{
    AgentArchiveAction, AgentCompleteAction, AgentCreateAction, AgentResultAction,
    AgentUpdateAction, AgentUpdateFields,
};
use crate::agent::{
    format_user_content, tool_schemas, AgentContextEntry, AgentResponse, TokenUsage,
    ENTRY_MANAGER_SYSTEM_PROMPT,
};
use crate::entry::{EntryCategory, HabitCadence};

// ---------------------------------------------------------------------------
// LlmService — PPQ.ai HTTP client
// ---------------------------------------------------------------------------

pub struct LlmService {
    api_key: String,
    model: String,
    client: reqwest::Client,
}

impl LlmService {
    pub fn new(api_key: String) -> Self {
        Self {
            api_key,
            model: "anthropic/claude-sonnet-4.6".to_string(),
            client: reqwest::Client::new(),
        }
    }

    pub fn with_model(api_key: String, model: String) -> Self {
        Self {
            api_key,
            model,
            client: reqwest::Client::new(),
        }
    }

    /// Process a transcript against existing entries via the LLM.
    pub async fn process(
        &self,
        transcript: &str,
        existing_entries: &[AgentContextEntry],
    ) -> Result<AgentResponse, LlmError> {
        let user_content = format_user_content(transcript, existing_entries);

        let now = chrono::Local::now();
        let datetime_str = now.format("%A, %B %-d, %Y at %-I:%M %p %Z").to_string();
        let system_content = format!(
            "Current date and time: {}\n\n{}",
            datetime_str, ENTRY_MANAGER_SYSTEM_PROMPT
        );

        let body = serde_json::json!({
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_content},
                {"role": "user", "content": user_content}
            ],
            "tools": tool_schemas(),
            "tool_choice": "auto"
        });

        let response = self
            .client
            .post("https://api.ppq.ai/chat/completions")
            .header("Authorization", format!("Bearer {}", self.api_key))
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(LlmError::Http)?;

        let status = response.status().as_u16();
        let response_body = response.text().await.map_err(LlmError::Http)?;

        if status != 200 {
            return Err(LlmError::ApiError {
                status,
                body: response_body,
            });
        }

        parse_response(&response_body)
    }
}

// ---------------------------------------------------------------------------
// Response parsing
// ---------------------------------------------------------------------------

/// Parse a raw PPQ.ai/OpenAI-compatible JSON response into an AgentResponse.
/// Exposed as pub(crate) for unit testing without making real API calls.
pub(crate) fn parse_response(body: &str) -> Result<AgentResponse, LlmError> {
    let api_response: ApiResponse =
        serde_json::from_str(body).map_err(|e| LlmError::ParseError(e.to_string()))?;

    let choice = api_response
        .choices
        .first()
        .ok_or_else(|| LlmError::ParseError("No choices in response".to_string()))?;

    let message = &choice.message;

    // Parse actions from tool_calls
    let actions = if let Some(ref tool_calls) = message.tool_calls {
        let mut actions = Vec::new();
        for tc in tool_calls {
            let mut parsed = parse_tool_call(&tc.function.name, &tc.function.arguments)?;
            actions.append(&mut parsed);
        }
        actions
    } else {
        Vec::new()
    };

    // Parse summary from content or generate from actions
    let summary = extract_content_string(&message.content)
        .unwrap_or_else(|| summarize_actions(&actions));

    // Parse usage (handle both OpenAI and Anthropic field names)
    let usage = if let Some(ref u) = api_response.usage {
        TokenUsage {
            input_tokens: u.prompt_tokens.or(u.input_tokens).unwrap_or(0),
            output_tokens: u.completion_tokens.or(u.output_tokens).unwrap_or(0),
        }
    } else {
        TokenUsage::default()
    };

    Ok(AgentResponse {
        actions,
        summary,
        usage,
    })
}

fn extract_content_string(content: &Option<serde_json::Value>) -> Option<String> {
    match content {
        Some(serde_json::Value::String(s)) => {
            let trimmed = s.trim();
            if trimmed.is_empty() {
                None
            } else {
                Some(trimmed.to_string())
            }
        }
        Some(serde_json::Value::Array(parts)) => {
            let text: String = parts
                .iter()
                .filter_map(|p| p.get("text")?.as_str())
                .collect::<Vec<_>>()
                .join(" ");
            let trimmed = text.trim();
            if trimmed.is_empty() {
                None
            } else {
                Some(trimmed.to_string())
            }
        }
        _ => None,
    }
}

fn parse_tool_call(name: &str, arguments: &str) -> Result<Vec<AgentResultAction>, LlmError> {
    match name {
        "create_entries" => {
            let args: CreateEntriesArgs = serde_json::from_str(arguments)
                .map_err(|e| LlmError::ParseError(e.to_string()))?;
            Ok(args
                .entries
                .into_iter()
                .map(|e| {
                    let source_text = e
                        .source_text
                        .as_deref()
                        .map(str::trim)
                        .filter(|s| !s.is_empty())
                        .unwrap_or(&e.content)
                        .to_string();
                    let summary = e
                        .summary
                        .as_deref()
                        .map(str::trim)
                        .unwrap_or("")
                        .to_string();
                    AgentResultAction::Create(AgentCreateAction {
                        content: e.content,
                        category: e.category,
                        source_text,
                        summary,
                        priority: e.priority,
                        due_date_description: e.due_date,
                        cadence: e.cadence,
                    })
                })
                .collect())
        }
        "update_entries" => {
            let args: UpdateEntriesArgs = serde_json::from_str(arguments)
                .map_err(|e| LlmError::ParseError(e.to_string()))?;
            Ok(args
                .updates
                .into_iter()
                .map(|u| {
                    AgentResultAction::Update(AgentUpdateAction {
                        id: u.id,
                        fields: AgentUpdateFields {
                            content: u.fields.content,
                            summary: u.fields.summary,
                            category: u.fields.category,
                            priority: u.fields.priority,
                            due_date_description: u.fields.due_date,
                            cadence: u.fields.cadence,
                            status: u.fields.status,
                            snooze_until: u.fields.snooze_until,
                        },
                        reason: normalize_reason(u.reason.as_deref()),
                    })
                })
                .collect())
        }
        "complete_entries" => {
            let args: CompleteMutationArgs = serde_json::from_str(arguments)
                .map_err(|e| LlmError::ParseError(e.to_string()))?;
            Ok(args
                .entries
                .into_iter()
                .map(|m| {
                    AgentResultAction::Complete(AgentCompleteAction {
                        id: m.id,
                        reason: normalize_reason(m.reason.as_deref()),
                    })
                })
                .collect())
        }
        "archive_entries" => {
            let args: ArchiveMutationArgs = serde_json::from_str(arguments)
                .map_err(|e| LlmError::ParseError(e.to_string()))?;
            Ok(args
                .entries
                .into_iter()
                .map(|m| {
                    AgentResultAction::Archive(AgentArchiveAction {
                        id: m.id,
                        reason: normalize_reason(m.reason.as_deref()),
                    })
                })
                .collect())
        }
        _ => Ok(Vec::new()),
    }
}

fn normalize_reason(reason: Option<&str>) -> String {
    match reason {
        Some(r) => {
            let trimmed = r.trim();
            if trimmed.is_empty() {
                "No reason provided".to_string()
            } else {
                trimmed.to_string()
            }
        }
        None => "No reason provided".to_string(),
    }
}

fn summarize_actions(actions: &[AgentResultAction]) -> String {
    if actions.is_empty() {
        return "No actions".to_string();
    }

    let mut create_count = 0;
    let mut update_count = 0;
    let mut complete_count = 0;
    let mut archive_count = 0;

    for action in actions {
        match action {
            AgentResultAction::Create(_) => create_count += 1,
            AgentResultAction::Update(_) => update_count += 1,
            AgentResultAction::Complete(_) => complete_count += 1,
            AgentResultAction::Archive(_) => archive_count += 1,
        }
    }

    let mut parts = Vec::new();
    if create_count > 0 {
        parts.push(format!("created {}", create_count));
    }
    if update_count > 0 {
        parts.push(format!("updated {}", update_count));
    }
    if complete_count > 0 {
        parts.push(format!("completed {}", complete_count));
    }
    if archive_count > 0 {
        parts.push(format!("archived {}", archive_count));
    }

    parts.join(", ")
}

// ---------------------------------------------------------------------------
// API response types (private deserialization)
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct ApiResponse {
    choices: Vec<ApiChoice>,
    #[serde(default)]
    usage: Option<ApiUsage>,
}

#[derive(Deserialize)]
struct ApiChoice {
    message: ApiMessage,
}

#[derive(Deserialize)]
struct ApiMessage {
    #[serde(default)]
    content: Option<serde_json::Value>,
    #[serde(default)]
    tool_calls: Option<Vec<ApiToolCall>>,
}

#[derive(Deserialize)]
struct ApiToolCall {
    function: ApiFunction,
}

#[derive(Deserialize)]
struct ApiFunction {
    name: String,
    arguments: String,
}

#[derive(Deserialize)]
struct ApiUsage {
    #[serde(default)]
    prompt_tokens: Option<u32>,
    #[serde(default)]
    completion_tokens: Option<u32>,
    #[serde(default)]
    input_tokens: Option<u32>,
    #[serde(default)]
    output_tokens: Option<u32>,
}

// ---------------------------------------------------------------------------
// Tool call argument types (private deserialization)
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct CreateEntriesArgs {
    entries: Vec<RawCreateEntry>,
}

#[derive(Deserialize)]
struct RawCreateEntry {
    content: String,
    category: EntryCategory,
    #[serde(default, rename = "source_text")]
    source_text: Option<String>,
    #[serde(default)]
    summary: Option<String>,
    #[serde(default)]
    priority: Option<i32>,
    #[serde(default, rename = "due_date")]
    due_date: Option<String>,
    #[serde(default)]
    cadence: Option<HabitCadence>,
}

#[derive(Deserialize)]
struct UpdateEntriesArgs {
    updates: Vec<RawUpdate>,
}

#[derive(Deserialize)]
struct RawUpdate {
    id: String,
    fields: RawUpdateFields,
    #[serde(default)]
    reason: Option<String>,
}

#[derive(Deserialize)]
struct RawUpdateFields {
    #[serde(default)]
    content: Option<String>,
    #[serde(default)]
    summary: Option<String>,
    #[serde(default)]
    category: Option<EntryCategory>,
    #[serde(default)]
    priority: Option<i32>,
    #[serde(default, rename = "due_date")]
    due_date: Option<String>,
    #[serde(default)]
    cadence: Option<HabitCadence>,
    #[serde(default)]
    status: Option<String>,
    #[serde(default, rename = "snooze_until")]
    snooze_until: Option<String>,
}

#[derive(Deserialize)]
struct CompleteMutationArgs {
    entries: Vec<RawMutation>,
}

#[derive(Deserialize)]
struct ArchiveMutationArgs {
    entries: Vec<RawMutation>,
}

#[derive(Deserialize)]
struct RawMutation {
    id: String,
    #[serde(default)]
    reason: Option<String>,
}

// ---------------------------------------------------------------------------
// LlmError
// ---------------------------------------------------------------------------

#[derive(Debug)]
pub enum LlmError {
    Http(reqwest::Error),
    ApiError { status: u16, body: String },
    ParseError(String),
}

impl std::fmt::Display for LlmError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Http(e) => write!(f, "HTTP error: {}", e),
            Self::ApiError { status, body } => {
                write!(f, "API error (HTTP {}): {}", status, body)
            }
            Self::ParseError(msg) => write!(f, "Parse error: {}", msg),
        }
    }
}

impl std::error::Error for LlmError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Http(e) => Some(e),
            _ => None,
        }
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_create_entries_response() {
        let body = serde_json::json!({
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {
                            "name": "create_entries",
                            "arguments": "{\"entries\":[{\"content\":\"Buy milk\",\"category\":\"todo\",\"source_text\":\"buy milk tomorrow\",\"summary\":\"Buy milk\",\"priority\":2,\"due_date\":\"tomorrow\"}]}"
                        }
                    }]
                }
            }],
            "usage": {"prompt_tokens": 100, "completion_tokens": 50}
        })
        .to_string();

        let result = parse_response(&body).unwrap();
        assert_eq!(result.actions.len(), 1);
        match &result.actions[0] {
            AgentResultAction::Create(create) => {
                assert_eq!(create.content, "Buy milk");
                assert_eq!(create.category, EntryCategory::Todo);
                assert_eq!(create.source_text, "buy milk tomorrow");
                assert_eq!(create.summary, "Buy milk");
                assert_eq!(create.priority, Some(2));
                assert_eq!(create.due_date_description.as_deref(), Some("tomorrow"));
            }
            _ => panic!("Expected Create action"),
        }
    }

    #[test]
    fn parse_update_entries_response() {
        let body = serde_json::json!({
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {
                            "name": "update_entries",
                            "arguments": "{\"updates\":[{\"id\":\"abc123\",\"fields\":{\"priority\":1,\"due_date\":\"today\"},\"reason\":\"User said it's urgent\"}]}"
                        }
                    }]
                }
            }],
            "usage": {"prompt_tokens": 80, "completion_tokens": 30}
        })
        .to_string();

        let result = parse_response(&body).unwrap();
        assert_eq!(result.actions.len(), 1);
        match &result.actions[0] {
            AgentResultAction::Update(update) => {
                assert_eq!(update.id, "abc123");
                assert_eq!(update.fields.priority, Some(1));
                assert_eq!(
                    update.fields.due_date_description.as_deref(),
                    Some("today")
                );
                assert_eq!(update.reason, "User said it's urgent");
            }
            _ => panic!("Expected Update action"),
        }
    }

    #[test]
    fn parse_complete_entries_response() {
        let body = serde_json::json!({
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {
                            "name": "complete_entries",
                            "arguments": "{\"entries\":[{\"id\":\"abc123\",\"reason\":\"User said it's done\"}]}"
                        }
                    }]
                }
            }],
            "usage": {"prompt_tokens": 50, "completion_tokens": 20}
        })
        .to_string();

        let result = parse_response(&body).unwrap();
        assert_eq!(result.actions.len(), 1);
        match &result.actions[0] {
            AgentResultAction::Complete(complete) => {
                assert_eq!(complete.id, "abc123");
                assert_eq!(complete.reason, "User said it's done");
            }
            _ => panic!("Expected Complete action"),
        }
    }

    #[test]
    fn parse_archive_entries_response() {
        let body = serde_json::json!({
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {
                            "name": "archive_entries",
                            "arguments": "{\"entries\":[{\"id\":\"xyz789\",\"reason\":\"No longer relevant\"}]}"
                        }
                    }]
                }
            }],
            "usage": {"prompt_tokens": 40, "completion_tokens": 15}
        })
        .to_string();

        let result = parse_response(&body).unwrap();
        assert_eq!(result.actions.len(), 1);
        match &result.actions[0] {
            AgentResultAction::Archive(archive) => {
                assert_eq!(archive.id, "xyz789");
                assert_eq!(archive.reason, "No longer relevant");
            }
            _ => panic!("Expected Archive action"),
        }
    }

    #[test]
    fn parse_no_tool_calls_response() {
        let body = serde_json::json!({
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": "I don't understand what you want me to do."
                }
            }],
            "usage": {"prompt_tokens": 50, "completion_tokens": 15}
        })
        .to_string();

        let result = parse_response(&body).unwrap();
        assert!(result.actions.is_empty());
        assert_eq!(
            result.summary,
            "I don't understand what you want me to do."
        );
    }

    #[test]
    fn parse_usage_openai_format() {
        let body = serde_json::json!({
            "choices": [{"message": {"role": "assistant", "content": "test"}}],
            "usage": {"prompt_tokens": 100, "completion_tokens": 50}
        })
        .to_string();

        let result = parse_response(&body).unwrap();
        assert_eq!(result.usage.input_tokens, 100);
        assert_eq!(result.usage.output_tokens, 50);
    }

    #[test]
    fn parse_usage_anthropic_format() {
        let body = serde_json::json!({
            "choices": [{"message": {"role": "assistant", "content": "test"}}],
            "usage": {"input_tokens": 200, "output_tokens": 75}
        })
        .to_string();

        let result = parse_response(&body).unwrap();
        assert_eq!(result.usage.input_tokens, 200);
        assert_eq!(result.usage.output_tokens, 75);
    }

    #[test]
    fn parse_missing_reason_gets_default() {
        let body = serde_json::json!({
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_1",
                        "type": "function",
                        "function": {
                            "name": "complete_entries",
                            "arguments": "{\"entries\":[{\"id\":\"abc123\"}]}"
                        }
                    }]
                }
            }],
            "usage": {"prompt_tokens": 10, "completion_tokens": 5}
        })
        .to_string();

        let result = parse_response(&body).unwrap();
        match &result.actions[0] {
            AgentResultAction::Complete(c) => {
                assert_eq!(c.reason, "No reason provided");
            }
            _ => panic!("Expected Complete action"),
        }
    }

    #[test]
    fn parse_multiple_tool_calls() {
        let body = serde_json::json!({
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [
                        {
                            "id": "call_1",
                            "type": "function",
                            "function": {
                                "name": "create_entries",
                                "arguments": "{\"entries\":[{\"content\":\"Buy eggs\",\"category\":\"todo\",\"source_text\":\"buy eggs\",\"summary\":\"Buy eggs\"}]}"
                            }
                        },
                        {
                            "id": "call_2",
                            "type": "function",
                            "function": {
                                "name": "complete_entries",
                                "arguments": "{\"entries\":[{\"id\":\"old123\",\"reason\":\"Done\"}]}"
                            }
                        }
                    ]
                }
            }],
            "usage": {"prompt_tokens": 150, "completion_tokens": 60}
        })
        .to_string();

        let result = parse_response(&body).unwrap();
        assert_eq!(result.actions.len(), 2);
        assert!(matches!(&result.actions[0], AgentResultAction::Create(_)));
        assert!(matches!(
            &result.actions[1],
            AgentResultAction::Complete(_)
        ));
        assert_eq!(result.summary, "created 1, completed 1");
    }
}
