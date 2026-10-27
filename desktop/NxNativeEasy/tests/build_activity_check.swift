import Foundation

@main struct BuildActivityCheck {
    static func main() throws {
        var activity=BuildActivity()
        let lines="""
        {"ev":"stage","k":2,"n":8,"name":"iOS shaders","step":"compiling"}
        {"ev":"progress","k":2,"name":"iOS shaders","done":15,"total":30,"unit":"shaders","frac":0.5}
        {"ev":"tool_log","source":"shader.log","msg":"Compilación ✓\\n"}
        """+"\n"
        // Deliberately split every UTF-8 byte, including the accent and checkmark.
        for byte in Data(lines.utf8) {activity.receive(Data([byte]))}
        assert(activity.stageNumber==2 && activity.stages==8)
        assert(activity.fraction==0.5 && activity.count=="15 / 30 shaders")
        assert(activity.latest=="Compilación ✓" && activity.transcript.contains("[shader.log]"))
        activity.receive(Data("{\"ev\":\"step\",\"step\":\"linking\"}\n".utf8))
        assert(activity.fraction==nil && activity.count.isEmpty)
        activity.receive(Data("{\"ev\":\"progress\",\"frac\":-4}\npartial error".utf8));activity.finish()
        assert(activity.fraction==nil && activity.latest=="partial error")
        activity.receive(Data("{\"ev\":\"stage_end\",\"ok\":false}\n".utf8));assert(activity.fraction==nil)
        activity.receive(Data("{\"ev\":\"stage_end\",\"ok\":true}\n".utf8));assert(activity.fraction==1)
        activity.receive(Data(String(repeating:"x",count:200000).utf8));assert(activity.transcript.count<=120000)
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:folder)}
        let log=folder.appendingPathComponent("worker.log")
        try Data("last retained error".utf8).write(to:log)
        activity.finish(logURL:log);assert(activity.latest=="last retained error")
        assert(PreviousPreparation.load(folder:folder,target:"ios")==nil)
        try Data("{\"schema\":1,\"bundle_id\":\"org.game.same\",\"version\":\"2.0\"}".utf8).write(to:folder.appendingPathComponent("nxnative-ios.json"))
        assert(PreviousPreparation.load(folder:folder,target:"ios")?.version=="2.0")
        assert(PreviousPreparation.load(folder:folder,target:"mac")==nil)
        try Data("{\"schema\":1,\"app_path\":\"/missing/old.app\",\"bundle_id\":\"org.mac.same\",\"version\":\"1.0\"}".utf8).write(to:folder.appendingPathComponent("nxnative-mac.json"))
        assert(PreviousPreparation.load(folder:folder,target:"mac")?.bundleID=="org.mac.same")
        try Data("{\"schema\":99,\"bundle_id\":\"unknown\"}".utf8).write(to:folder.appendingPathComponent("nxnative-ios.json"))
        assert(PreviousPreparation.load(folder:folder,target:"ios")==nil)
        var stream=BuildActivity()
        stream.receive(Data("{\"ev\":\"stage\",\"k\":1,\"n\":2,\"name\":\"Extract\"}\n{\"ev\":\"stage_end\",\"ok\":true}\n{\"ev\":\"stage\",\"k\":2,\"n\":3,\"name\":\"Rewrite\"}\n{\"ev\":\"progress\",\"frac\":0.25,\"eta\":42,\"est\":true}\n".utf8))
        assert(stream.stages==3 && stream.history.count==2 && stream.history[0].state == .done && stream.eta==42 && stream.estimated)
        stream.receive(Data("{\"ev\":\"progress\",\"eta\":1e100}\n".utf8));assert(stream.eta==nil)
        stream.receive(Data("{\"ev\":\"step\",\"step\":\"Next step\"}\n".utf8));assert(stream.eta==nil && stream.fraction==nil && !stream.estimated)
        try Data("{\"ev\":\"say\",\"msg\":\"Tail only\"}\n".utf8).write(to:log)
        stream.finish(logURL:log);assert(stream.history.count==2 && stream.history[0].state == .done)
        stream.complete(exitCode:1);assert(stream.history[1].state == .failed)
        var cancelled=BuildActivity();cancelled.receive(Data("{\"ev\":\"stage\",\"k\":1,\"n\":2,\"name\":\"Compile\"}\n".utf8));cancelled.complete(exitCode:130,cancelled:true);assert(cancelled.history[0].state == .cancelled)
        print("Build activity PASS: dynamic stage totals, real ETA, reset between steps, retained timeline after tail replay, failed/cancelled outcomes; split UTF-8/JSON, real fractions, bounded transcript, partial final line and target-specific previous preparation")
    }
}
