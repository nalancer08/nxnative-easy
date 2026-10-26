import GameController

@main struct InputChecks {
    @MainActor static func main() {
        let controller=GCController.withExtendedGamepad()
        let gamepad=controller.extendedGamepad!
        var connected=[controller]
        let tester=ControllerTester(query:{connected})
        precondition(!tester.confirmed && !tester.state.active)
        gamepad.buttonA.setValue(1)
        gamepad.leftShoulder.setValue(1)
        gamepad.dpad.setValueForXAxis(-1,yAxis:1)
        gamepad.leftThumbstick.setValueForXAxis(0.75,yAxis:-0.5)
        gamepad.rightThumbstick.setValueForXAxis(-0.5,yAxis:0.25)
        gamepad.leftTrigger.setValue(0.6)
        tester.sample()
        precondition(tester.state.buttons.contains("a") && tester.state.buttons.contains("lb"))
        precondition(tester.state.buttons.contains("left") && tester.state.buttons.contains("up"))
        precondition(abs(tester.state.lx-0.75)<0.01 && abs(tester.state.ly+0.5)<0.01)
        precondition(abs(tester.state.rx+0.5)<0.01 && abs(tester.state.ry-0.25)<0.01)
        precondition(abs(tester.state.lt-0.6)<0.01 && tester.confirmed)
        gamepad.buttonA.setValue(0);gamepad.leftShoulder.setValue(0)
        gamepad.dpad.setValueForXAxis(0,yAxis:0)
        gamepad.leftThumbstick.setValueForXAxis(0,yAxis:0)
        gamepad.rightThumbstick.setValueForXAxis(0,yAxis:0)
        gamepad.leftTrigger.setValue(0)
        tester.sample()
        precondition(!tester.state.active && tester.state.buttons.isEmpty && tester.confirmed)
        let second=GCController.withExtendedGamepad()
        connected=[controller,second];tester.sample()
        tester.selected=ObjectIdentifier(second)
        gamepad.buttonA.setValue(1);tester.sample()
        precondition(!tester.state.active && !tester.confirmed,"A different controller must not light up the selected gamepad")
        connected=[];tester.sample()
        precondition(tester.devices.isEmpty && !tester.state.active && !tester.confirmed)
        print("Live input: buttons, D-pad, both sticks, trigger pressure, release and disconnect passed")
    }
}
