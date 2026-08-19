import SwiftUI
import AppKit
import LocalImageSearchCore

@main
struct LocalImageSearchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var environment: AppEnvironment

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
        } catch {
            let fallbackDB = try! AppDatabase.inMemory()
            let env = AppEnvironment(database: fallbackDB)
            _environment = StateObject(wrappedValue: env)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainContentView(env: environment)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    #if os(macOS)
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    #endif
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
            SettingsView(env: environment)
        }
    }
}
