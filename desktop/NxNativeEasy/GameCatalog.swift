import Foundation

enum CatalogConsoleFilter:String,CaseIterable,Identifiable {
    case all,switch1,switch2
    var id:String {rawValue}
    var title:String {self == .all ? "Todos los juegos" : self == .switch1 ? "Switch 1" : "Switch 2"}
    func includes(_ game:CatalogGame)->Bool {self == .all || (self == .switch2) == game.isSwitch2}
}

struct CatalogGame: Identifiable, Equatable {
    let id: String
    let name: String
    let versions: [String]
    let artworkURL: URL?
    var isSwitch2:Bool {id.hasPrefix("04")}
    var consoleTitle:String {isSwitch2 ? "Switch 2" : "Switch 1"}
    init(id:String,name:String,versions:[String],artworkURL:URL? = nil) {
        self.id=id;self.name=name;self.versions=versions;self.artworkURL=artworkURL
    }

    func matches(_ query: String) -> Bool {
        let normalize: (String) -> String = {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier:"en_US_POSIX"))
        }
        let haystack=normalize(([name,id,"Nintendo",consoleTitle,isSwitch2 ? "switch2 ns2 Mac dump NUP" : "switch1 ns1"]+versions).joined(separator:" "))
        return normalize(query).split(whereSeparator: {$0.isWhitespace}).allSatisfy {haystack.contains($0)}
    }
    var notesURL: URL {
        URL(string:"https://github.com/nalancer08/nxnative-easy/blob/main/dm/games/\(id)/README.md")!
    }
}

struct GameCatalog {
    // Read the installed checkout, not a manually maintained compatibility list.
    static func load(repo: URL) throws -> [CatalogGame] {
        let directory=repo.appendingPathComponent("dm/games",isDirectory:true)
        let children=try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)
        let artworkFile=repo.appendingPathComponent("desktop/NxNativeEasy/game-artwork.json")
        let artwork=(try? JSONDecoder().decode([String:String].self,from:Data(contentsOf:artworkFile))) ?? [:]
        var games: [CatalogGame]=[]
        for child in children {
            let id=child.lastPathComponent
            guard id.range(of:"^[0-9A-Fa-f]{16}$",options:.regularExpression) != nil else {continue}
            let profile=child.appendingPathComponent("game.tsv")
            guard FileManager.default.fileExists(atPath:profile.path) else {continue}
            let source=try String(contentsOf:profile,encoding:.utf8)
            var name: String?;var versions: [String]=[];var parent:String?
            for line in source.components(separatedBy:.newlines) {
                guard !line.trimmingCharacters(in:.whitespaces).hasPrefix("#") else {continue}
                let fields=line.components(separatedBy:"\t")
                if fields.count>1 && fields[0]=="name" {name=fields[1].trimmingCharacters(in:.whitespaces)}
                if fields.count>1 && fields[0]=="program_of" {parent=fields[1].trimmingCharacters(in:.whitespaces)}
                if fields.count>2 && fields[0]=="build" {
                    let version=fields[2].trimmingCharacters(in:.whitespaces)
                    if !version.isEmpty && !versions.contains(version) {versions.append(version)}
                }
            }
            if parent != nil {continue} // The parent game packs and describes its programs.
            var image: URL?
            if let path=artwork[id],path.hasPrefix("docs/images/"),!path.contains("..") {
                let candidate=repo.appendingPathComponent(path).resolvingSymlinksInPath()
                if candidate.path.hasPrefix(repo.resolvingSymlinksInPath().path+"/"),FileManager.default.fileExists(atPath:candidate.path) {image=candidate}
            }
            games.append(CatalogGame(id:id,name:name?.isEmpty == false ? name! : id,versions:versions,artworkURL:image))
        }
        return games.sorted {
            let comparison=$0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }
    static func search(_ games: [CatalogGame], query: String, console:CatalogConsoleFilter = .all) -> [CatalogGame] {
        let one=query.range(of:#"\b(?:switch\s*1|ns1)\b"#,options:[.regularExpression,.caseInsensitive]) != nil
        let two=query.range(of:#"\b(?:switch\s*2|ns2)\b"#,options:[.regularExpression,.caseInsensitive]) != nil
        return games.filter {console.includes($0) && (!one || !$0.isSwitch2) && (!two || $0.isSwitch2) && $0.matches(query)}
    }
}
