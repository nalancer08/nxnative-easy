import Foundation
import Combine

// Presence metadata only. Reading a local save is not evidence of a cloud upload
// or a complete backup, and must never select/restore a progress branch.
struct LocalSavePresence:Equatable {
    enum State {case empty,present,unavailable}
    var state:State
    var files=0
    var modified:Date?
    static func inspect(root:URL)->Self {
        let fm=FileManager.default
        let keys:Set<URLResourceKey>=[.isDirectoryKey,.isRegularFileKey,.isSymbolicLinkKey,.contentModificationDateKey]
        func missing(_ error:Error)->Bool {
            let error=error as NSError
            return error.domain==NSCocoaErrorDomain && [NSFileReadNoSuchFileError,NSFileNoSuchFileError].contains(error.code)
        }
        do {
            let value=try root.resourceValues(forKeys:keys)
            guard value.isDirectory==true,value.isSymbolicLink != true else{return Self(state:.unavailable)}
        } catch {return Self(state:missing(error) ? .empty : .unavailable)}
        var count=0,visited=0,modified:Date?
        for name in ["save","save_device"] {
            let folder=root.appendingPathComponent(name)
            do {
                let value=try folder.resourceValues(forKeys:keys)
                guard value.isDirectory==true,value.isSymbolicLink != true else{return Self(state:.unavailable)}
            } catch {if missing(error){continue};return Self(state:.unavailable)}
            var failed=false
            guard let walk=fm.enumerator(at:folder,includingPropertiesForKeys:Array(keys),options:[],errorHandler:{_,_ in failed=true;return false}) else{return Self(state:.unavailable)}
            while let file=walk.nextObject() as? URL {
                visited+=1;guard visited<=8192 else{return Self(state:.unavailable)}
                guard let value=try? file.resourceValues(forKeys:keys),value.isSymbolicLink != true else{return Self(state:.unavailable)}
                if value.isRegularFile==true {
                    count+=1
                    if let date=value.contentModificationDate,date.timeIntervalSince1970.isFinite {modified=max(modified ?? date,date)}
                }
            }
            if failed {return Self(state:.unavailable)}
        }
        return Self(state:count==0 ? .empty : .present,files:count,modified:modified)
    }
}

@MainActor final class LocalSaveMonitor:ObservableObject {
    @Published private(set) var games:[String:LocalSavePresence]=[:]
    private let rootForTitle:(String)->URL
    private var generation=UUID()
    init(rootForTitle:@escaping(String)->URL = {SaveLocations.macRoot(titleID:$0)}) {self.rootForTitle=rootForTitle}
    func refresh(titles:[String])async {
        let token=UUID();generation=token
        let ids=Set(titles.map{$0.uppercased()}.filter{$0.range(of:"^[0-9A-F]{16}$",options:.regularExpression) != nil})
        let roots=Dictionary(uniqueKeysWithValues:ids.map{($0,rootForTitle($0))})
        let result=await Task.detached(priority:.utility) {roots.mapValues{LocalSavePresence.inspect(root:$0)}}.value
        guard !Task.isCancelled,generation==token else{return}
        if games != result {games=result}
    }
    func watch(titles:[String],interval:UInt64=3_000_000_000)async {
        while !Task.isCancelled {
            await refresh(titles:titles)
            do {try await Task.sleep(nanoseconds:interval)}catch{return}
        }
    }
}
