import AppKit
import SwiftUI
import ShadcnUI

@main
struct GoveeMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = LightStore()
    @AppStorage("showMenuBar") private var showMenuBar = true

    var body: some Scene {
        WindowGroup("Govee Mac", id: "main") {
            ContentView(store: store)
                .shadcnTheme(glass: false)
                .frame(minWidth: 840, minHeight: 660)
                .task { await store.start() }
        }
        .defaultSize(width: 1080, height: 800)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { store.showsSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Lights") {
                Button("Discover Wi-Fi Lights") { Task { await store.scanLAN() } }
                    .keyboardShortcut("r")
                Button("Discover Bluetooth Lights") { store.scanBluetooth() }
                Divider()
                Button("Turn All On") { store.setAllPower(true) }
                    .disabled(store.availableCount == 0)
                Button("Turn All Off") { store.setAllPower(false) }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(store.availableCount == 0)
            }
            CommandGroup(replacing: .help) {
                Link("Govee Mac on GitHub", destination: Brand.repository)
                Link("Setup & Compatibility", destination: Brand.repository.appendingPathComponent("blob/main/docs/COMPATIBILITY.md"))
            }
        }
        MenuBarExtra("Govee Mac", systemImage: "lightbulb", isInserted: $showMenuBar) {
            MenuBarView(store: store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
