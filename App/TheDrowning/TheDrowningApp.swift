import DrownedStore
import DrownedUI
import ServiceManagement
import SwiftUI

@main
struct TheDrowningApp: App {
    @State private var launchError: String?

    var body: some Scene {
        WindowGroup("The Drowning") {
            Root()
                .task {
                    registerAgent()
                }
        }
        .handlesExternalEvents(matching: ["*"])
    }

    private func registerAgent() {
        do {
            try SMAppService.agent(plistName: "com.panjas.thedrowning.agent.plist").register()
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
                TheDrowningRootView(store: store)
            } else if let errorMessage {
                ContentUnavailableView("The Drowning cannot start", systemImage: "exclamationmark.triangle")
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
