import SwiftUI
import AppKit
@_silgen_name("nxe_test_reset") private func reset(_ json: UnsafePointer<CChar>)
@_silgen_name("nxe_test_reply") private func reply(_ json: UnsafePointer<CChar>)
@_silgen_name("nxe_test_calls") private func calls() -> Int32
private enum Failure:Error {case check(String)}
private func json(_ status:String)->String {"{\"status\":\"\(status)\",\"message\":\"synthetic\",\"choices\":[]}"}
@main private struct Check {
    @MainActor static func until(_ condition:()->Bool)async throws {
        for _ in 0..<200 {
            if condition(){return}
            try await Task.sleep(nanoseconds:10_000_000)
        }
        throw Failure.check("late waiting state did not restart the panel check")
    }
    @MainActor static func main()async {
        do {
            NSApplication.shared.setActivationPolicy(.prohibited)
            reset(json("available"));let m=CloudSaveModel();m.ready=true;m.blocked=false
            m.folder=URL(fileURLWithPath:"/synthetic-no-folder-access")
            let view=NSHostingView(rootView:CloudSavePanel(model:m).frame(width:600))
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:600,height:800),styleMask:.borderless,backing:.buffered,defer:false)
            window.isReleasedWhenClosed=false;window.contentView=view;view.layoutSubtreeIfNeeded();view.display()
            try await until {calls()>0 && !m.busy}
            let before=calls();reply(json("waiting"));await m.check()
            try await until {calls()>before+1 && !m.busy}
            reply(json("available"))
            // Returning to the embedded AppKit panel must recheck immediately.
            NotificationCenter.default.post(name:NSApplication.didResignActiveNotification,object:nil)
            try await Task.sleep(nanoseconds:100_000_000)
            NotificationCenter.default.post(name:NSApplication.didBecomeActiveNotification,object:nil)
            try await until {m.status=="available" && !m.busy}
            // Let SwiftUI finish the task-key transition out of retry mode.
            // It may make one final check; it must then remain quiescent.
            let delivered=calls();try await Task.sleep(nanoseconds:200_000_000)
            guard calls()<=delivered+1 else {throw Failure.check("unbounded healthy transition checks")}
            let settled=calls();try await Task.sleep(nanoseconds:200_000_000)
            guard calls()==settled else {throw Failure.check("healthy panel kept polling")}
            window.close();print("automatic panel: late delivery and embedded AppKit foreground passed")
        }catch {fputs("automatic panel failed: \(error)\n",stderr);exit(1)}
    }
}
