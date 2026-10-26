import AppKit
import Combine
import GameController

struct DetectedController: Identifiable, Equatable {
    let id: ObjectIdentifier
    let name: String
    let supported: Bool
}

// Observe connections only. Never take input handlers away from a running game.
@MainActor final class ControllerMonitor: ObservableObject {
    @Published private(set) var controllers: [DetectedController] = []
    private let query: () -> [GCController]
    private let center: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(center:NotificationCenter = .default, query:(() -> [GCController])? = nil) {
        self.center=center
        self.query=query ?? {GCController.controllers()}
        for name in [NSNotification.Name.GCControllerDidConnect, .GCControllerDidDisconnect,
                     NSApplication.didBecomeActiveNotification] {
            observers.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        refresh()
    }
    deinit {for observer in observers {center.removeObserver(observer)}}
    func refresh() {
        let next=query().map {
            DetectedController(id:ObjectIdentifier($0),name:$0.vendorName ?? "",supported:$0.extendedGamepad != nil)
        }
        if next != controllers {controllers=next}
    }
}

// All launchers share one app identity, even when opened through an old shortcut.
final class LauncherDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification:Notification) {
        guard let identifier=Bundle.main.bundleIdentifier else {return}
        if let existing=NSRunningApplication.runningApplications(withBundleIdentifier:identifier)
            .first(where:{$0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated}) {
            existing.activate(options:[.activateAllWindows])
            NSApplication.shared.terminate(nil)
        }
    }
}
