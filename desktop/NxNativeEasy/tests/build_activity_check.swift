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
        print("Build activity PASS: split UTF-8/JSON, real fractions, bounded transcript, partial final line and target-specific previous preparation")
    }
}
