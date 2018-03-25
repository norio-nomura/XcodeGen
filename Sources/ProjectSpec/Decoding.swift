import Foundation
import JSONUtilities
import PathKit
import xcproj
import Yams

extension Dictionary where Key: JSONKey {

    public func json<T: NamedJSONDictionaryConvertible>(atKeyPath keyPath: JSONUtilities.KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [T] {
        guard let dictionary = json(atKeyPath: keyPath) as JSONDictionary? else {
            return []
        }
        var items: [T] = []
        for (key, _) in dictionary {
            let jsonDictionary: JSONDictionary = try dictionary.json(atKeyPath: .key(key))
            let item = try T(name: key, jsonDictionary: jsonDictionary)
            items.append(item)
        }
        return items
    }

    public func json<T: NamedJSONConvertible>(atKeyPath keyPath: JSONUtilities.KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [T] {
        guard let dictionary = json(atKeyPath: keyPath) as JSONDictionary? else {
            return []
        }
        var items: [T] = []
        for (key, value) in dictionary {
            let item = try T(name: key, json: value)
            items.append(item)
        }
        return items
    }
}

public protocol NamedJSONDictionaryConvertible {

    init(name: String, jsonDictionary: JSONDictionary) throws
}

public protocol NamedJSONConvertible {

    init(name: String, json: Any) throws
}

extension JSONObjectConvertible {

    public init(path: Path) throws {
        let content: String = try path.read()
        if content == "" {
            try self.init(jsonDictionary: [:])
            return
        }
        let yaml = try Yams.load(yaml: content)
        guard let jsonDictionary = yaml as? JSONDictionary else {
            throw JSONUtilsError.fileNotAJSONDictionary
        }
        try self.init(jsonDictionary: jsonDictionary)
    }
}

// MARK: - Decodable support

struct DecodableEnvironmentVariable: Swift.Decodable {
    public let variable: String
    public let value: String
    public let enabled: Bool

    private enum Value: Swift.Decodable {
        case bool(Bool)
        case string(String)
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            do {
                self = .bool(try container.decode(Bool.self))
            } catch {
                self = .string(try container.decode(String.self))
            }
        }

        var string: String {
            switch self {
            case .bool(let bool): return bool ? "YES" : "NO"
            case .string(let string): return string
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case variable, value, enabled = "isEnabled"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        variable = try container.decode(String.self, forKey: .variable)
        value = try container.decode(Value.self, forKey: .value).string
        enabled = (try? container.decode(Bool.self, forKey: .enabled)) ?? true
    }

    var environmentVariable: XCScheme.EnvironmentVariable {
        return .init(variable: variable, value: value, enabled: enabled)
    }
}
