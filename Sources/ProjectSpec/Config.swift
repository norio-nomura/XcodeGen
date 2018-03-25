import Foundation
import JSONUtilities
import xcproj

public struct Config: Equatable, Swift.Decodable {
    public var name: String
    public var type: ConfigType?

    public init(name: String, type: ConfigType? = nil) {
        self.name = name
        self.type = type
    }

    public static func == (lhs: Config, rhs: Config) -> Bool {
        return lhs.name == rhs.name && lhs.type == rhs.type
    }

    public static var defaultConfigs: [Config] = [Config(name: "Debug", type: .debug), Config(name: "Release", type: .release)]
}

public enum ConfigType: String, Swift.Decodable {
    case debug
    case release
}
