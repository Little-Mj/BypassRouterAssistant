import SwiftUI
import AppKit
import Darwin

final class InstanceLock: @unchecked Sendable {
    let acquired: Bool
    private let descriptor: Int32

    init() {
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("local.bypass-router.assistant.instance.lock")
        descriptor = Darwin.open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        acquired = descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) == 0
        if !acquired, descriptor >= 0 { Darwin.close(descriptor) }
    }
}

enum InstanceGuard {
    static let shared = InstanceLock()
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let window = sender.windows.first(where: { $0.canBecomeKey && !$0.title.isEmpty }) {
            window.makeKeyAndOrderFront(nil)
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct BypassRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state: AppState

    init() {
        guard InstanceGuard.shared.acquired else {
            NSRunningApplication.runningApplications(withBundleIdentifier: "local.bypass-router.assistant")
                .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?
                .activate(options: [.activateAllWindows])
            Darwin.exit(EXIT_SUCCESS)
        }
        _state = StateObject(wrappedValue: AppState())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(state: state)
        } label: {
            Label("旁路由助手 · \(state.snapshot.mode.rawValue)", systemImage: state.snapshot.mode.symbol)
        }.menuBarExtraStyle(.window)

        Window("旁路由助手", id: "main") {
            MainView(state: state)
        }.defaultSize(width: 940, height: 650)
    }
}
