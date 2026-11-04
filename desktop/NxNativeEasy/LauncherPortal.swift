import SwiftUI

// Preparation remains mounted during browsing; the decorative web player must
// not. Visibility is supplied separately so compilation state is never reset.
struct LauncherPortal:View {
    var visible=true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    var body:some View {
        Group {
            if visible {LibraryDropMotion(playing:phase == .active && !reduceMotion,resource:"ecosystem-sync")}
            else {Color.clear}
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
