import SwiftUI
import AppKit
import LocalImageSearchCore

@main
struct LocalImageSearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var environment: AppEnvironment
    private let databaseStartupError: String?

    init() {
        #if os(macOS)
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif

        do {
            let dbURL = try AppDatabase.defaultDatabaseURL()
            let db = try AppDatabase.persistent(at: dbURL)
            let env = AppEnvironment(database: db)
            _environment = StateObject(wrappedValue: env)
            databaseStartupError = nil
        } catch {
            // Never show an empty in-memory catalog as though the user's database were
            // erased. Keep the existing files untouched and surface a blocking error.
            let fallbackDB = try! AppDatabase.inMemory()
            let env = AppEnvironment(database: fallbackDB)
            _environment = StateObject(wrappedValue: env)
            databaseStartupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let databaseStartupError {
                DatabaseUnavailableView(errorMessage: databaseStartupError)
                    .frame(minWidth: 800, minHeight: 500)
            } else {
                MainContentView(env: environment)
                    .frame(minWidth: 800, minHeight: 500)
                    .onAppear {
                        #if os(macOS)
                        NSApplication.shared.setActivationPolicy(.regular)
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        #endif
                    }
            }
        }
        .windowStyle(.titleBar)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appInfo) {
                Button("About Local Image Search") {
                    #if os(macOS)
                    NSApplication.shared.orderFrontStandardAboutPanel()
                    #endif
                }
            }
        }

        Settings {
            if databaseStartupError == nil {
                SettingsView(env: environment)
            } else {
                Text("Settings are unavailable while the catalog database cannot be opened.")
                    .padding()
            }
        }
    }
}

private struct DatabaseUnavailableView: View {
    let errorMessage: String

    var body: some View {
        ContentUnavailableView {
            Label("Catalog Database Unavailable", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Your existing catalog has not been deleted or replaced. Local Image Search could not open it: \(errorMessage)")
        } actions: {
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(40)
    }
}
