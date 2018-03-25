import Foundation
import JSONUtilities
import PathKit
import xcproj

public struct Settings: Equatable, JSONObjectConvertible, CustomStringConvertible, Swift.Decodable {

    public let buildSettings: BuildSettings
    public let configSettings: [String: Settings]
    public let groups: [String]

    public init(buildSettings: BuildSettings = [:], configSettings: [String: Settings] = [:], groups: [String] = []) {
        self.buildSettings = buildSettings
        self.configSettings = configSettings
        self.groups = groups
    }

    public init(dictionary: [String: Any]) {
        buildSettings = dictionary
        configSettings = [:]
        groups = []
    }

    public static let empty: Settings = Settings(dictionary: [:])

    public init(jsonDictionary: JSONDictionary) throws {
        if jsonDictionary["configs"] != nil || jsonDictionary["groups"] != nil || jsonDictionary["base"] != nil {
            groups = jsonDictionary.json(atKeyPath: "groups") ?? jsonDictionary.json(atKeyPath: "presets") ?? []
            let buildSettingsDictionary: JSONDictionary = jsonDictionary.json(atKeyPath: "base") ?? [:]
            buildSettings = buildSettingsDictionary
            configSettings = jsonDictionary.json(atKeyPath: "configs") ?? [:]
        } else {
            buildSettings = jsonDictionary
            configSettings = [:]
            groups = []
        }
    }

    public static func == (lhs: Settings, rhs: Settings) -> Bool {
        return NSDictionary(dictionary: lhs.buildSettings).isEqual(to: rhs.buildSettings) &&
            lhs.configSettings == rhs.configSettings &&
            lhs.groups == rhs.groups
    }

    public var description: String {
        var string: String = ""
        if !buildSettings.isEmpty {
            let buildSettingDescription = buildSettings.map { "\($0) = \($1)" }.joined(separator: "\n")
            if !configSettings.isEmpty || !groups.isEmpty {
                string += "base:\n  " + buildSettingDescription.replacingOccurrences(of: "(.)\n", with: "$1\n  ", options: .regularExpression, range: nil)
            } else {
                string += buildSettingDescription
            }
        }
        if !configSettings.isEmpty {
            if !string.isEmpty {
                string += "\n"
            }
            for (config, buildSettings) in configSettings {
                if !buildSettings.description.isEmpty {
                    string += "configs:\n"
                    string += "  \(config):\n    " + buildSettings.description.replacingOccurrences(of: "(.)\n", with: "$1\n    ", options: .regularExpression, range: nil)
                }
            }
        }
        if !groups.isEmpty {
            if !string.isEmpty {
                string += "\n"
            }
            string += "groups:\n  \(groups.joined(separator: "\n  "))"
        }
        return string
    }

    enum CodingKeys: CodingKey {
        case configs, groups, base, presets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let configs = try container.decodeIfPresent([String: Settings].self, forKey: .configs)
        let groups = try container.decodeIfPresent([String].self, forKey: .groups)
        // FIXME
        let base: BuildSettings? = nil // = try container.decodeIfPresent(BuildSettings.self, forKey: .base)
        if configs != nil || groups != nil || base != nil {
            self.groups = groups ?? (try? container.decode([String].self, forKey: .presets)) ?? []
            self.buildSettings = base ?? [:]
            self.configSettings = configs ?? [:]
        } else {
            self.buildSettings = [:] // FIXME
            self.configSettings = [:]
            self.groups = []
        }
    }
}

extension Settings: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (String, Any)...) {
        var dictionary: [String: Any] = [:]
        elements.forEach { dictionary[$0.0] = $0.1 }
        self.init(dictionary: dictionary)
    }
}

extension Dictionary where Key == String, Value: Any {

    public func merged(_ dictionary: [Key: Value]) -> [Key: Value] {
        var mergedDictionary = self
        mergedDictionary.merge(dictionary)
        return mergedDictionary
    }

    public mutating func merge(_ dictionary: [Key: Value]) {
        for (key, value) in dictionary {
            self[key] = value
        }
    }

    public func equals(_ dictionary: BuildSettings) -> Bool {
        return NSDictionary(dictionary: self).isEqual(to: dictionary)
    }
}

public func += (lhs: inout BuildSettings, rhs: BuildSettings?) {
    guard let rhs = rhs else { return }
    lhs.merge(rhs)
}
