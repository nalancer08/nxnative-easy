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
        print("Release metadata: new, equal, older and malformed versions passed")
    }
}
