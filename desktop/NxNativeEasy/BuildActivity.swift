import Foundation

struct BuildStage:Identifiable {
    enum State {case active,done,failed,cancelled}
    let id:String
    var number:Int
    var name:String
    var state:State
}

// Parse complete UTF-8 lines: pipe reads may split a JSON record or a multibyte character.
struct BuildActivity {
    private var pending=Data()
    private(set) var transcript=""
    private mutating func record(_ text:String) {transcript+=text+"\n";if transcript.count>120000 {transcript=String(transcript.suffix(100000))}}
    private(set) var stage=""
    private(set) var step=""
    private(set) var stageNumber=0
    private(set) var stages=0
    private(set) var fraction:Double?
    private(set) var count=""
    private(set) var latest=""
    private(set) var history:[BuildStage]=[]
    private(set) var eta:Double?
    private(set) var estimated=false
    mutating func receive(_ data:Data) {
        pending.append(data)
        while let end=pending.firstIndex(of:10) {
            let line=String(decoding:pending[..<end],as:UTF8.self)
            pending.removeSubrange(...end);consume(line)
        }
        // A broken/no-newline tool must not grow the UI buffer without limit.
        if pending.count>65536 {consume(String(decoding:pending,as:UTF8.self));pending.removeAll()}
    }
    mutating func finish() {if !pending.isEmpty {consume(String(decoding:pending,as:UTF8.self));pending.removeAll()}}
    mutating func finish(logURL:URL?) {
        // Process exit and pipe callbacks can arrive out of order; replay the retained tail.
        if let logURL,let handle=try? FileHandle(forReadingFrom:logURL) {
            defer {try? handle.close()}
            if let size=try? handle.seekToEnd() {
                try? handle.seek(toOffset:size>524288 ? size-524288 : 0)
                if let data=try? handle.readToEnd() {
                    let previous=history
                    self=BuildActivity();receive(data)
                    let recovered=history
                    history=previous.filter {old in !recovered.contains(where:{$0.id==old.id})}+recovered
                }
            }
        }
        finish()
    }
    mutating func complete(exitCode:Int32,cancelled:Bool=false) {
        for index in history.indices where history[index].state == .active {
            history[index].state=cancelled ? .cancelled : exitCode==0 ? .done : .failed
        }
        eta=nil
        if exitCode != 0 || cancelled {fraction=nil}
    }
    private mutating func consume(_ line:String) {
        guard !line.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {return}
        guard let data=line.data(using:.utf8),let obj=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let event=obj["ev"] as? String else {latest=String(line.suffix(300));record(line);return}
        if let name=obj["name"] as? String {stage=name}
        if let value=obj["step"] as? String {step=value}
        if let k=obj["k"] as? Int {stageNumber=k}
        if let n=obj["n"] as? Int {stages=n}
        if event=="stage" || event=="step" {fraction=nil;count="";eta=nil;estimated=false}
        if event=="progress" {
            eta=(obj["eta"] as? Double).flatMap {$0.isFinite && $0>=0 && $0<Double(Int.max) ? $0 : nil}
            estimated=(obj["est"] as? Bool)==true
            fraction=(obj["frac"] as? Double).flatMap {$0.isFinite && $0>=0 && $0<=1 ? $0 : nil}
            if let done=obj["done"] as? Double,done.isFinite,done>=0 {
                let unit=obj["unit"] as? String ?? ""
                let prefix=(obj["est"] as? Bool)==true ? "~" : ""
                if let total=obj["total"] as? Double,total.isFinite,total>0 {count=String(format:"%.0f / %@%.0f %@",done,prefix,total,unit)}
                else {count=String(format:"%.0f %@",done,unit)}
            }
        }
        if ["stage","step","progress","stage_end"].contains(event),!stage.isEmpty {
            let key=stageNumber>0 ? "stage-\(stageNumber)" : "extra-"+stage
            let state:BuildStage.State=event=="stage_end" ? ((obj["ok"] as? Bool)==true ? .done : .failed) : .active
            if let index=history.firstIndex(where:{$0.id==key}) {history[index].name=stage;history[index].state=state}
            else {history.append(BuildStage(id:key,number:stageNumber,name:stage,state:state))}
        }
        if ["stage","step","stage_end"].contains(event) {record("[\(stageNumber)/\(stages)] \(stage) · \(step)")}
        if event=="progress" && !count.isEmpty {record(count)}
        if event=="stage_end" {eta=nil;fraction=(obj["ok"] as? Bool)==true ? 1 : nil}
        if let skipped=obj["skipped"] as? Int,skipped>0 {record("Live preview skipped \(skipped) older bytes; the original compiler log is complete.")}
        if let message=obj["msg"] as? String,let last=message.split(whereSeparator:\.isNewline).last {latest=String(last.suffix(300));record((obj["source"] as? String).map {"["+$0+"]\n"} ?? "");record(message)}
    }
}

struct PreviousPreparation {
    let target:String
    let version:String?
    let bundleID:String?
    static func load(folder:URL,target:String)->PreviousPreparation? {
        guard ["ios","mac"].contains(target),
              let data=try? Data(contentsOf:folder.appendingPathComponent("nxnative-\(target).json")),
              let record=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
              (record["schema"] as? Int ?? 1)==1 else {return nil}
        if target=="ios" {
            guard let id=record["bundle_id"] as? String,!id.isEmpty else {return nil}
            return Self(target:target,version:record["version"] as? String,bundleID:id)
        }
        guard let path=record["app_path"] as? String else {return nil}
        let info=(try? Data(contentsOf:URL(fileURLWithPath:path).appendingPathComponent("Contents/Info.plist"))).flatMap {try? PropertyListSerialization.propertyList(from:$0,format:nil)} as? [String:Any]
        return Self(target:target,version:record["version"] as? String ?? info?["CFBundleShortVersionString"] as? String,bundleID:record["bundle_id"] as? String ?? info?["CFBundleIdentifier"] as? String)
    }
}


// Full mode is explicit: older preparation records must be rebuilt so their
// runtime understands bundled-data priority over an older Documents/romfs.
enum IOSPackageOutput {
    static func load(record:[String:Any],split:Bool)->(ipa:URL,romfs:URL?)? {
        if !split {
            guard record["packaging"] as? String=="full",let path=record["full_ipa"] as? String,FileManager.default.isReadableFile(atPath:path) else {return nil}
            return (URL(fileURLWithPath:path),nil)
        }
        guard let path=record["light_dir"] as? String else {return nil}
        let root=URL(fileURLWithPath:path)
        guard let files=try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil),let ipa=files.sorted(by:{$0.path<$1.path}).first(where:{$0.pathExtension.lowercased()=="ipa"}) else {return nil}
        return (ipa,root.appendingPathComponent("romfs"))
    }
}
