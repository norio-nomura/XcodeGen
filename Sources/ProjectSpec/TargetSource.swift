import Foundation
import JSONUtilities
import PathKit
import xcproj

public struct TargetSource: Swift.Decodable {

    public var path: String
    public var name: String?
    public var compilerFlags: [String]
    public var excludes: [String]
    public var type: SourceType?
    public var optional: Bool
    public var buildPhase: BuildPhase?
    public var headerVisibility: HeaderVisibility?

    public enum HeaderVisibility: String, Swift.Decodable {
        case `public`
        case `private`
        case project

        public var settingName: String {
            switch self {
            case .public: return "Public"
            case .private: return "Private"
            case .project: return "Project"
            }
        }

        enum CodingKeys: String, CodingKey {
            case `public` = "Public", `private` = "Private", project = "Project"
        }
    }

    public enum BuildPhase: String, Swift.Decodable {
        case sources
        case headers
        case resources
        case none

        public var buildPhase: xcproj.BuildPhase? {
            switch self {
            case .sources: return .sources
            case .headers: return .headers
            case .resources: return .resources
            case .none: return nil
            }
        }
    }

    public enum SourceType: String, Swift.Decodable {
        case group
        case file
        case folder
    }

    public init(
        path: String,
        name: String? = nil,
        compilerFlags: [String] = [],
        excludes: [String] = [],
        type: SourceType? = nil,
        optional: Bool = false,
        buildPhase: BuildPhase? = nil,
        headerVisibility: HeaderVisibility? = nil
    ) {
        self.path = path
        self.name = name
        self.compilerFlags = compilerFlags
        self.excludes = excludes
        self.type = type
        self.optional = optional
        self.buildPhase = buildPhase
    }

    enum CodingKeys: CodingKey {
        case path, name, compilerFlags, excludes, type, optional, buildPhase, headerVisibility
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        name = try container.decode(String.self, forKey: .name)
        do {
            compilerFlags = try container.decodeIfPresent([String].self, forKey: .compilerFlags) ?? []
        } catch {
            compilerFlags = try container.decodeIfPresent(String.self, forKey: .compilerFlags).map {
                $0.split(separator: " ").map { String($0) }
            } ?? []
        }
        excludes = try container.decodeIfPresent([String].self, forKey: .excludes) ?? []
        type = try container.decodeIfPresent(SourceType.self, forKey: .type)
        optional = try container.decodeIfPresent(Bool.self, forKey: .optional) ?? false
        buildPhase = try container.decodeIfPresent(BuildPhase.self, forKey: .buildPhase)
        headerVisibility = try container.decodeIfPresent(HeaderVisibility.self, forKey: .headerVisibility)
    }
}

extension TargetSource: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = TargetSource(path: value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self = TargetSource(path: value)
    }

    public init(unicodeScalarLiteral value: String) {
        self = TargetSource(path: value)
    }
}

extension TargetSource: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        path = try jsonDictionary.json(atKeyPath: "path")
        name = jsonDictionary.json(atKeyPath: "name")

        let maybeCompilerFlagsString: String? = jsonDictionary.json(atKeyPath: "compilerFlags")
        let maybeCompilerFlagsArray: [String]? = jsonDictionary.json(atKeyPath: "compilerFlags")
        compilerFlags = maybeCompilerFlagsArray ??
            maybeCompilerFlagsString.map { $0.split(separator: " ").map { String($0) } } ?? []

        headerVisibility = jsonDictionary.json(atKeyPath: "headerVisibility")
        excludes = jsonDictionary.json(atKeyPath: "excludes") ?? []
        type = jsonDictionary.json(atKeyPath: "type")
        optional = jsonDictionary.json(atKeyPath: "optional") ?? false
        if let string: String = jsonDictionary.json(atKeyPath: "buildPhase") {
            if let buildPhase = BuildPhase(rawValue: string) {
                self.buildPhase = buildPhase
            } else {
                throw SpecParsingError.unknownSourceBuildPhase(string)
            }
        }
    }
}

extension TargetSource: Equatable {

    public static func == (lhs: TargetSource, rhs: TargetSource) -> Bool {
        return lhs.path == rhs.path
            && lhs.name == rhs.name
            && lhs.compilerFlags == rhs.compilerFlags
            && lhs.excludes == rhs.excludes
            && lhs.type == rhs.type
            && lhs.optional == rhs.optional
            && lhs.buildPhase == rhs.buildPhase
    }
}
