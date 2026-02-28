import SwiftUI

enum DevComponentSection: String, CaseIterable, Identifiable {
    case input = "Input & Controls"
    case display = "Display"
    case overlay = "Overlays"
    case navigation = "Navigation"
    case cards = "Cards"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .input: return "hand.tap"
        case .display: return "rectangle.3.group"
        case .overlay: return "square.stack"
        case .navigation: return "arrow.left.arrow.right"
        case .cards: return "rectangle.stack"
        }
    }

    var components: [DevComponent] {
        DevComponent.allCases.filter { $0.section == self }
    }
}

enum DevComponent: String, CaseIterable, Identifiable {
    // Input & Controls
    case micButton = "MicButton"
    case inputBar = "InputBar"
    case filterChips = "FilterChips"
    case bottomNavBar = "BottomNavBar"

    // Display
    case categoryBadge = "CategoryBadge"
    case tokenBalance = "TokenBalanceLabel"
    case toastView = "ToastView"
    case waveformView = "WaveformView"
    case pulsingMic = "PulsingMicView"

    // Overlays
    case recordingOverlay = "RecordingOverlay"
    case processingOverlay = "ProcessingOverlay"

    // Navigation
    case navHeader = "NavHeader"
    case settingsRow = "SettingsRow"

    // Cards
    case entryCard = "EntryCard"
    case reminderCard = "ReminderEntryCard"
    case todoListItem = "TodoListItem"

    var id: String { rawValue }

    var section: DevComponentSection {
        switch self {
        case .micButton, .inputBar, .filterChips, .bottomNavBar:
            return .input
        case .categoryBadge, .tokenBalance, .toastView, .waveformView, .pulsingMic:
            return .display
        case .recordingOverlay, .processingOverlay:
            return .overlay
        case .navHeader, .settingsRow:
            return .navigation
        case .entryCard, .reminderCard, .todoListItem:
            return .cards
        }
    }

    var description: String {
        switch self {
        case .micButton: return "Gradient mic button with recording indicator"
        case .inputBar: return "Text field with mic button, supports multiline"
        case .filterChips: return "Horizontal scrolling category filter pills"
        case .bottomNavBar: return "3-tab navigation bar with mic spacer"
        case .categoryBadge: return "Colored pill badge for entry categories"
        case .tokenBalance: return "Token count with warning states"
        case .toastView: return "Success/warning/error/info notifications"
        case .waveformView: return "Audio waveform with animating/frozen states"
        case .pulsingMic: return "Animated pulsing rings around mic"
        case .recordingOverlay: return "Full-screen recording with transcript"
        case .processingOverlay: return "Spinner with processing animation"
        case .navHeader: return "Top bar with title, back, and actions"
        case .settingsRow: return "Settings menu row with icon and value"
        case .entryCard: return "Card with summary, metadata, and category"
        case .reminderCard: return "Entry card with yellow accent and due date"
        case .todoListItem: return "Checkbox item with swipe actions"
        }
    }
}
