import DrownedStore
import DrownedUI
import ServiceManagement
import SwiftUI

@main
struct TheDrownedApp: App {
    @State private var launchError: String?

    var body: some Scene {
        WindowGroup {
            Root()
                .task {
                    registerAgent()
                }
        }
        .handlesExternalEvents(matching: ["*"])
    }

    private func registerAgent() {
        do {
            try SMAppService.agent(plistName: "com.panjas.thedrowned.agent.plist").register()
        } catch {
            launchError = error.localizedDescription
        }
    }
}

private struct Root: View {
    @State private var store: IncidentStore?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let store {
                TheDrownedRootView(store: store)
            } else if let errorMessage {
                ContentUnavailableView("The Drowned cannot start", systemImage: "exclamationmark.triangle")
                    .overlay(alignment: .bottom) {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .task {
                        do {
                            store = try IncidentStore()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
            }
        }
    }
}
