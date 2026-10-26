import SwiftUI
import Combine
import GameController

struct ControllerInputState: Equatable {
    var buttons: Set<String> = []
    var lx: Float = 0, ly: Float = 0, rx: Float = 0, ry: Float = 0
    var lt: Float = 0, rt: Float = 0
    var playStation = false
    var playStation5 = false
    var active: Bool {
        !buttons.isEmpty || [lx,ly,rx,ry].contains {abs($0)>0.15} || lt>0.1 || rt>0.1
    }
    init() {}
    init(_ g:GCExtendedGamepad) {
        let inputs: [(String,GCControllerButtonInput?)] = [
            ("a",g.buttonA),("b",g.buttonB),("x",g.buttonX),("y",g.buttonY),
            ("lb",g.leftShoulder),("rb",g.rightShoulder),("ls",g.leftThumbstickButton),("rs",g.rightThumbstickButton),
            ("menu",g.buttonMenu),("options",g.buttonOptions),
            ("up",g.dpad.up),("down",g.dpad.down),("left",g.dpad.left),("right",g.dpad.right)]
        buttons=Set(inputs.compactMap {$0.1?.isPressed == true ? $0.0 : nil})
        lx=g.leftThumbstick.xAxis.value;ly=g.leftThumbstick.yAxis.value
        rx=g.rightThumbstick.xAxis.value;ry=g.rightThumbstick.yAxis.value
        lt=g.leftTrigger.value;rt=g.rightTrigger.value
        playStation5=g is GCDualSenseGamepad
        playStation=playStation5 || g is GCDualShockGamepad
    }
}

// Sample only while the tester is visible. No handlers, pairing or background capture.
@MainActor final class ControllerTester: ObservableObject {
    @Published private(set) var devices: [DetectedController] = []
    @Published var selected: ObjectIdentifier? {
        didSet {if selected != oldValue {clear();confirmed=false}}
    }
    @Published private(set) var state=ControllerInputState()
    @Published private(set) var confirmed=false
    private let query: () -> [GCController]
    init(query:(() -> [GCController])? = nil) {self.query=query ?? {GCController.controllers()};sample()}
    func clear() {state=ControllerInputState()}
    func sample() {
        let connected=query().filter {$0.extendedGamepad != nil}
        let next=connected.map {DetectedController(id:ObjectIdentifier($0),name:$0.vendorName ?? "",supported:true)}
        if next.map(\.id) != devices.map(\.id) {devices=next}
        if !next.contains(where:{$0.id == selected}) {selected=next.first?.id}
        guard let controller=connected.first(where:{ObjectIdentifier($0)==selected}),let pad=controller.extendedGamepad else {
            clear();confirmed=false;return
        }
        let current=ControllerInputState(pad)
        if current != state {state=current}
        if current.active && !confirmed {confirmed=true}
    }
}

struct ControllerTestView: View {
    let text: (String) -> String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tester=ControllerTester()
    private let lime=Color(red:0.79,green:0.95,blue:0.37)
    private let tick=Timer.publish(every:1.0/60.0,on:.main,in:.common).autoconnect()
    private var state: ControllerInputState {tester.state}

    private func button(_ key:String,_ label:String,_ size:CGFloat=36) -> some View {
        let pressed=state.buttons.contains(key)
        return Text(label).font(.system(size:13,weight:.bold,design:.rounded)).lineLimit(1).minimumScaleFactor(0.7)
            .frame(width:size,height:size).foregroundStyle(pressed ? Color.black : Color.white.opacity(0.75))
            .background(pressed ? lime : Color.white.opacity(0.08),in:RoundedRectangle(cornerRadius:size/3))
            .overlay(RoundedRectangle(cornerRadius:size/3).stroke(pressed ? lime : Color.white.opacity(0.12)))
            .accessibilityLabel(label).accessibilityValue(pressed ? text("Presionado") : text("Suelto"))
    }
    private func stick(_ key:String,_ label:String,_ x:Float,_ y:Float) -> some View {
        VStack(spacing:8) {
            ZStack {
                Circle().fill(Color.black.opacity(0.24)).frame(width:92,height:92)
                Path {p in p.move(to:CGPoint(x:46,y:4));p.addLine(to:CGPoint(x:46,y:88));p.move(to:CGPoint(x:4,y:46));p.addLine(to:CGPoint(x:88,y:46))}
                    .stroke(Color.white.opacity(0.08),lineWidth:1).frame(width:92,height:92)
                Circle().fill(state.buttons.contains(key) ? lime : Color.white.opacity(0.72)).frame(width:38,height:38)
                    .offset(x:CGFloat(x)*26,y:-CGFloat(y)*26)
            }
            Text(label).font(.system(size:11,weight:.semibold)).foregroundStyle(.secondary)
        }.accessibilityElement(children:.ignore).accessibilityLabel(label)
            .accessibilityValue(String(format:"X %.2f, Y %.2f",x,y))
    }
    private func trigger(_ label:String,_ value:Float) -> some View {
        VStack(alignment:.leading,spacing:7) {
            HStack {Text(label);Spacer();Text("\(Int(value*100))%").monospacedDigit()}
                .font(.system(size:12,weight:.semibold)).foregroundStyle(value>0.1 ? lime : .secondary)
            ProgressView(value:Double(value)).tint(lime)
        }.frame(width:170)
    }
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack {
                VStack(alignment:.leading,spacing:5) {
                    Text(text("Prueba tu control")).font(.system(size:25,weight:.bold,design:.rounded))
                    Text(text("Pulsa botones y mueve los sticks. Verás cada movimiento aquí."))
                        .font(.system(size:13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(text("Cerrar")){dismiss()}.keyboardShortcut(.cancelAction)
            }
            if tester.devices.isEmpty {
                Label(text("Conecta un control a este Mac por Bluetooth."),systemImage:"gamecontroller")
                    .font(.system(size:13)).foregroundStyle(.secondary)
            } else {
                HStack {
                    if tester.devices.count>1 {
                        Picker(text("Control"),selection:$tester.selected) {
                            ForEach(tester.devices) {device in
                                Text(device.name.isEmpty ? text("Control") : device.name).tag(Optional(device.id))
                            }
                        }.frame(maxWidth:310)
                    } else {
                        Text(tester.devices.first?.name.isEmpty == false ? tester.devices.first!.name : text("Control"))
                            .font(.system(size:14,weight:.semibold))
                    }
                    Spacer()
                    Label(text(tester.confirmed ? "¡Está respondiendo!" : "Esperando tu primera pulsación…"),
                          systemImage:tester.confirmed ? "checkmark.circle.fill" : "hand.tap")
                        .font(.system(size:12,weight:.medium)).foregroundStyle(tester.confirmed ? lime : .secondary)
                }
            }
            VStack(spacing:22) {
                HStack {
                    trigger(state.playStation ? "L2" : "LT",state.lt)
                    Spacer()
                    trigger(state.playStation ? "R2" : "RT",state.rt)
                }
                HStack {
                    button("lb",state.playStation ? "L1" : "LB",42)
                    Spacer()
                    button("options",state.playStation5 ? "Create" : state.playStation ? "Share" : "View",42)
                    button("menu",state.playStation ? "Options" : "Menu",42)
                    Spacer()
                    button("rb",state.playStation ? "R1" : "RB",42)
                }
                HStack(alignment:.center) {
                    stick("ls","L3",state.lx,state.ly)
                    Spacer()
                    VStack(spacing:3) {
                        button("up","↑")
                        HStack(spacing:3) {button("left","←");Color.clear.frame(width:36,height:36);button("right","→")}
                        button("down","↓")
                    }
                    Spacer()
                    VStack(spacing:3) {
                        button("y",state.playStation ? "△" : "Y")
                        HStack(spacing:3) {button("x",state.playStation ? "□" : "X");button("b",state.playStation ? "○" : "B")}
                        button("a",state.playStation ? "×" : "A")
                    }
                    Spacer()
                    stick("rs","R3",state.rx,state.ry)
                }
            }.padding(26).background(Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:24))
            Text(text("Esta prueba comprueba la entrada del control en este Mac, no la compatibilidad de un juego."))
                .font(.system(size:11)).foregroundStyle(.secondary)
        }.padding(26).frame(width:690).preferredColorScheme(.dark)
        .onReceive(tick) {_ in if NSApplication.shared.isActive {tester.sample()} else {tester.clear()}}
        .onDisappear {tester.clear()}
    }
}
