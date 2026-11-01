import Foundation

@main struct ReleaseChecks {
    static func main() throws {
        let data=Data(#"{"version":"1.4","build":5,"minimumMacOSMajor":26}"#.utf8)
        let release=try JSONDecoder().decode(UpdateRelease.self,from:data)
        try release.validate()
        precondition(release.isNewer(than:4) && !release.isNewer(than:5) && !release.isNewer(than:6))
        for version in ["latest","../invalid","", "1.4;command"] {
            do {try UpdateRelease(version:version,build:5,minimumMacOSMajor:26).validate();fatalError("Invalid version accepted")}
            catch {}
        }
        let sha=String(repeating:"a",count:40)
        let reference=try JSONDecoder().decode(RepositoryReference.self,from:Data("{\"object\":{\"type\":\"commit\",\"sha\":\"\(sha)\"}}".utf8))
        let resolved=try reference.commitSHA();precondition(resolved==sha)
        for object in [("tag",sha),("commit","bad")] {
            let bad=RepositoryReference(object:.init(type:object.0,sha:object.1))
            do {_=try bad.commitSHA();fatalError("Invalid branch reference accepted")}catch {}
        }
        print("Release metadata: new, equal, older and malformed versions passed")
    }
}
