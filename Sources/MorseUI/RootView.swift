import SwiftUI
import MorseKit

/// App entry point. Owns the process-lifetime shared state — settings
/// persistence, mastery progress, and the shared audio pipeline — and
/// presents the four screens in a platform-appropriate navigation shell:
/// a `TabView` on compact/iOS layouts, a `NavigationSplitView` sidebar
/// everywhere else (macOS, iPadOS regular width).
public struct RootView: View {
    @StateObject private var store = SettingsStore()
    @State private var progress: ProgressStore
    @State private var tone: ToneGenerator
    @State private var player: MorsePlayer
    @State private var showReference = false

    #if !os(iOS)
    @State private var selection: Destination? = .learn
    #endif

    public init() {
        let resolvedProgress: ProgressStore
        if let disk = try? ProgressStore(inMemory: false) {
            resolvedProgress = disk
        } else {
            resolvedProgress = try! ProgressStore(inMemory: true)
        }
        _progress = State(initialValue: resolvedProgress)

        let resolvedTone = ToneGenerator()
        _tone = State(initialValue: resolvedTone)
        _player = State(initialValue: MorsePlayer(tone: resolvedTone))
    }

    public var body: some View {
        platformBody
            .tint(store.settings.appColor.color)
            .sheet(isPresented: $showReference) {
                ReferenceSheet(
                    play: { player.play($0, settings: store.settings.timing, frequency: store.settings.frequencyHz) },
                    confidence: { progress.confidence(for: String($0)) }
                )
            }
    }

    @ViewBuilder
    private var platformBody: some View {
        #if os(iOS)
        TabView {
            ForEach(Destination.allCases) { destination in
                NavigationStack {
                    screen(for: destination)
                        .navigationTitle(destination.title)
                        .toolbar { referenceToolbar }
                }
                .tabItem { Label(destination.title, systemImage: destination.icon) }
                .tag(destination)
            }
        }
        #else
        NavigationSplitView {
            List(Destination.allCases, selection: $selection) { destination in
                Label(destination.title, systemImage: destination.icon)
                    .tag(destination)
            }
            .navigationTitle("Dah Vinci")
        } detail: {
            NavigationStack {
                if let selection {
                    screen(for: selection)
                        .navigationTitle(selection.title)
                } else {
                    ContentUnavailableView("Select a screen", systemImage: "square.grid.2x2")
                }
            }
            .toolbar { referenceToolbar }
        }
        #endif
    }

    @ViewBuilder
    private func screen(for destination: Destination) -> some View {
        switch destination {
        case .learn:
            LearnSendView(
                settings: store.settings, progress: progress, player: player,
                tone: tone, stageIndex: progress.highestUnlockedStage
            )
        case .listen:
            ListenView(settings: store.settings, progress: progress, player: player)
        case .playground:
            PlaygroundView(settings: store.settings, player: player)
        case .settings:
            SettingsView(store: store)
        }
    }

    @ToolbarContentBuilder
    private var referenceToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showReference = true
            } label: {
                Image(systemName: "book.fill")
            }
            .accessibilityLabel("Reference chart")
        }
    }
}

/// The four top-level screens, shared between the iOS tab bar and the
/// macOS/iPadOS sidebar so the destination list and its icons/titles are
/// defined exactly once.
private enum Destination: String, CaseIterable, Identifiable, Hashable {
    case learn, listen, playground, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .learn: return "Learn"
        case .listen: return "Listen"
        case .playground: return "Playground"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .learn: return "hand.tap.fill"
        case .listen: return "ear.fill"
        case .playground: return "keyboard.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

#Preview("RootView") {
    RootView()
}
