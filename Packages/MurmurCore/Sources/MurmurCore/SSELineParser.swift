import Foundation

/// Parses raw SSE text lines into structured events.
/// Handles the `data: ` prefix, `[DONE]` sentinel, and JSON parsing.
public enum SSELineParser {
    public enum Event {
        case data([String: Any])
        case done
    }

    public static func parse(line: String) -> Event? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty lines and SSE comments
        if trimmed.isEmpty || trimmed.hasPrefix(":") {
            return nil
        }

        // Must have data: prefix
        let payload: String
        if trimmed.hasPrefix("data: ") {
            payload = String(trimmed.dropFirst(6))
        } else if trimmed.hasPrefix("data:") {
            payload = String(trimmed.dropFirst(5))
        } else {
            return nil
        }

        // Check for [DONE] sentinel
        if payload.trimmingCharacters(in: .whitespaces) == "[DONE]" {
            return .done
        }

        // Parse JSON
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        return .data(json)
    }
}
