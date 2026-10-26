import Foundation

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
