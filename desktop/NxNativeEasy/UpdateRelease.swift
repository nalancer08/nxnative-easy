import Foundation

struct RepositoryReference:Decodable {
    struct Object:Decodable {let type:String;let sha:String}
    let object:Object
    func commitSHA() throws -> String {
        guard object.type=="commit",object.sha.range(of:"^[0-9a-f]{40}$",options:.regularExpression) != nil else {throw URLError(.cannotParseResponse)}
        return object.sha
    }
}

struct UpdateRelease: Codable, Equatable {
    let version: String
    let build: Int
    let minimumMacOSMajor: Int
    func validate() throws {
        guard build>0,minimumMacOSMajor>0,
              version.range(of:"^[0-9]+\\.[0-9]+(?:\\.[0-9]+)?$",options:.regularExpression) != nil else {
            throw URLError(.cannotParseResponse)
        }
    }
    func isNewer(than build:Int) -> Bool {self.build>build}
}
