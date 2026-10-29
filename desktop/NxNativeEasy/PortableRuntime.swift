import Foundation

// Bundled tool paths are relative to the app, so moving it does not break setup.
enum PortableRuntime {
    static var tools:URL? {
        guard let root=Bundle.main.resourceURL?.appendingPathComponent("Tools"),FileManager.default.isExecutableFile(atPath:root.appendingPathComponent("python/bin/python3").path) else{return nil}
        return root
    }
    static var python:URL {tools?.appendingPathComponent("python/bin/python3") ?? URL(fileURLWithPath:"/usr/bin/python3")}
    static func environment()->[String:String] {
        var env=ProcessInfo.processInfo.environment
        env["PYTHONDONTWRITEBYTECODE"]="1"
        env["DOTNET_CLI_TELEMETRY_OPTOUT"]="1"
        env["DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE"]="1"
        if let tools {
            env["NXE_BUNDLED_TOOLS"]=tools.path
            env["DOTNET_ROOT"]=tools.appendingPathComponent("dotnet").path
            env["PATH"]=[tools.appendingPathComponent("bin").path,tools.appendingPathComponent("python/bin").path,tools.appendingPathComponent("dotnet").path,env["PATH"] ?? "/usr/bin:/bin"].joined(separator:":")
        }
        return env
    }
    static func source(configured:String)->URL {
        guard let seed=Bundle.main.resourceURL?.appendingPathComponent("Source"),FileManager.default.fileExists(atPath:seed.appendingPathComponent("scripts/prepare_ios.sh").path) else{return URL(fileURLWithPath:configured)}
        let revision=(try? String(contentsOf:seed.appendingPathComponent("SOURCE_REVISION"),encoding:.utf8).trimmingCharacters(in:.whitespacesAndNewlines)) ?? ""
        guard revision.range(of:"^[0-9a-f]{40}$",options:.regularExpression) != nil else{return URL(fileURLWithPath:configured)}
        let root=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/nxnative Easy/PortableSources")
        let output=root.appendingPathComponent(revision)
        if FileManager.default.fileExists(atPath:output.appendingPathComponent("scripts/prepare_ios.sh").path) {return output}
        let temporary=root.appendingPathComponent(".partial-"+UUID().uuidString)
        do {try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);try FileManager.default.copyItem(at:seed,to:temporary);try FileManager.default.moveItem(at:temporary,to:output)}catch {try? FileManager.default.removeItem(at:temporary)}
        return output
    }
}
