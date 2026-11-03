import Foundation

// Separate from GameCatalog: an open proposal never makes an input ready or
// adds a title to the supported-games inventory.
struct PendingGameProposal:Decodable {
    let titleID,name,url,reportedVersion,head,reviewedMain:String
    static func find(repo:URL,title:String?)->PendingGameProposal? {
        guard let title else {return nil}
        let path=repo.appendingPathComponent("desktop/NxNativeEasy/pending-game-proposals.json")
        guard let handle=try? FileHandle(forReadingFrom:path) else {return nil}
        defer {try? handle.close()}
        guard let data=try? handle.read(upToCount:65537),data.count<=65536,
              let entries=try? JSONDecoder().decode([PendingGameProposal].self,from:data) else {return nil}
        return entries.first {$0.titleID==title && $0.url.range(of:"^https://github.com/seedds/nxnative/pull/[0-9]+$",options:.regularExpression) != nil}
    }
}
