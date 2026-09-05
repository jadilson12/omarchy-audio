import AppKit
import SwiftUI

@main
struct OmarchyAudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var controller = AudioController.shared

    var body: some Scene {
        MenuBarExtra {
            PlayerView(controller: controller, inMenu: true)
        } label: {
            Image(systemName: controller.state == .listening ? "headphones.circle.fill" : "headphones")
                .accessibilityLabel("Omarchy Audio — \(controller.statusLabel)")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--check-stream") {
            MainActor.assumeIsolated {
                let controller = AudioController.shared
                controller.connect()
                Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { _ in
                    Task { @MainActor in
                        let received = controller.receivedFrames
                        let played = controller.playedFrames
                        let dropped = controller.droppedFrames
                        let success = controller.state == .listening && received > 48_000 && played > 48_000 && dropped == 0
                        print("Stream check: received=\(received) played=\(played) dropped=\(dropped) state=\(controller.state) result=\(success ? "PASS" : "FAIL")")
                        if !success { print(controller.message) }
                        controller.disconnect()
                        exit(success ? 0 : 1)
                    }
                }
            }
        } else {
            MainActor.assumeIsolated { AppWindows.shared.showPlayer() }
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { AudioController.shared.disconnect() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { AppWindows.shared.showPlayer() }
        return true
    }
}

@MainActor
final class AppWindows {
    static let shared = AppWindows()
    private var player: NSWindow?
    private var settings: NSWindow?

    func showPlayer() {
        if player == nil {
            player = makeWindow(title: "Omarchy Audio", view: PlayerView(controller: .shared), compact: true)
        }
        player?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        if settings == nil {
            settings = makeWindow(title: "Omarchy Audio Settings", view: ConnectionSettings(controller: .shared), compact: false)
        }
        settings?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow<Content: View>(title: String, view: Content, compact: Bool) -> NSWindow {
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                              styleMask: compact ? [.titled, .closable, .miniaturizable, .fullSizeContentView] : [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = title
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = true
        if compact {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(calibratedRed: 0.065, green: 0.085, blue: 0.085, alpha: 1)
        }
        window.center()
        return window
    }
}
