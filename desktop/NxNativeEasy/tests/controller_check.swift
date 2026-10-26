import AppKit
import GameController

@main struct ControllerChecks {
    @MainActor static func main() async {
        let center=NotificationCenter()
        var connected: [GCController]=[]
        let monitor=ControllerMonitor(center:center,query:{connected})
        precondition(monitor.controllers.isEmpty,"No controller must never be ready")
        let supported=GCController.withExtendedGamepad()
        precondition(supported.extendedGamepad != nil)
        let preconnected=ControllerMonitor(query:{[supported]})
        precondition(preconnected.controllers.count == 1 && preconnected.controllers[0].supported,"A controller connected before launch must be discovered")
        connected=[supported]
        center.post(name:.GCControllerDidConnect,object:supported)
        try? await Task.sleep(nanoseconds:30_000_000)
        precondition(monitor.controllers.count == 1 && monitor.controllers[0].supported,"Connect must automatically report the recognized gamepad")
        connected=[]
        center.post(name:.GCControllerDidDisconnect,object:supported)
        try? await Task.sleep(nanoseconds:30_000_000)
        precondition(monitor.controllers.isEmpty,"Disconnect must clear stale readiness")
        connected=[supported]
        center.post(name:NSApplication.didBecomeActiveNotification,object:nil)
        try? await Task.sleep(nanoseconds:30_000_000)
        precondition(monitor.controllers.count == 1,"Returning to the app must refresh device status")
        let unsupported=GCController()
        connected=[unsupported]
        monitor.refresh()
        precondition(monitor.controllers.count == 1 && !monitor.controllers[0].supported,"An unsupported profile must not be declared ready")
        print("Controller discovery: initial, connect, disconnect, foreground refresh and unsupported profile passed")
    }
}
