import Foundation
import JSONUtilities
import xcproj

public typealias BuildType = XCScheme.BuildAction.Entry.BuildFor

public struct Scheme: Equatable, Swift.Decodable {

    public var name: String
    public var build: Build
    public var run: Run?
    public var archive: Archive?
    public var analyze: Analyze?
    public var test: Test?
    public var profile: Profile?

    public init(
        name: String,
        build: Build,
        run: Run? = nil,
        test: Test? = nil,
        profile: Profile? = nil,
        analyze: Analyze? = nil,
        archive: Archive? = nil
    ) {
        self.name = name
        self.build = build
        self.run = run
        self.test = test
        self.profile = profile
        self.analyze = analyze
        self.archive = archive
    }

    public struct ExecutionAction: Equatable, Swift.Decodable {
        public var script: String
        public var name: String
        public var settingsTarget: String?
        public init(name: String, script: String, settingsTarget: String?) {
            self.script = script
            self.name = name
            self.settingsTarget = settingsTarget
        }

        public static func == (lhs: ExecutionAction, rhs: ExecutionAction) -> Bool {
            return lhs.script == rhs.script &&
                lhs.name == rhs.name &&
                lhs.settingsTarget == rhs.settingsTarget
        }

        private enum CodingKeys: CodingKey {
            case script, name, settingsTarget
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            script = try container.decode(String.self, forKey: .script)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Run Script"
            settingsTarget = try container.decodeIfPresent(String.self, forKey: .settingsTarget)
        }
    }

    public struct Build: Equatable, Swift.Decodable {
        public var targets: [BuildTarget]
        public var parallelizeBuild: Bool
        public var buildImplicitDependencies: Bool
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public init(
            targets: [BuildTarget],
            parallelizeBuild: Bool = true,
            buildImplicitDependencies: Bool = true,
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = []
        ) {
            self.targets = targets
            self.parallelizeBuild = parallelizeBuild
            self.buildImplicitDependencies = buildImplicitDependencies
            self.preActions = preActions
            self.postActions = postActions
        }

        public static func == (lhs: Build, rhs: Build) -> Bool {
            return lhs.targets == rhs.targets &&
                lhs.preActions == rhs.postActions &&
                lhs.postActions == rhs.postActions
        }

        private enum Types: Swift.Decodable {
            case string(String)
            case dictionary([String:Bool])
            case array([String])

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                do {
                    self = .string(try container.decode(String.self))
                } catch {
                    do {
                        self = .dictionary(try container.decode([String:Bool].self))
                    } catch {
                        self = .array(try container.decode([String].self))
                    }
                }
            }

            var buildTypes: [BuildType] {
                switch self {
                case .string(let string):
                    switch string {
                    case "all": return BuildType.all
                    case "none": return []
                    case "testing": return [.testing, .analyzing]
                    case "indexing": return [.testing, .analyzing, .archiving]
                    default: return BuildType.all
                    }
                case .dictionary(let enabledDictionary):
                    return enabledDictionary.filter { $0.value }.flatMap { BuildType.from(jsonValue: $0.key) }
                case .array(let array):
                    return array.flatMap(BuildType.from)
                }
            }
        }

        private enum CodingKeys: CodingKey {
            case targets, parallelizeBuild, buildImplicitDependencies, preActions, postActions
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            targets = try container.decode([String: Types].self, forKey: .targets).map {
                .init(target: $0.key, buildTypes: $0.value.buildTypes)
            }.sorted { $0.target < $1.target }
            parallelizeBuild = try container.decode(Bool.self, forKey: .parallelizeBuild)
            buildImplicitDependencies = try container.decode(Bool.self, forKey: .buildImplicitDependencies)
            preActions = try container.decode([ExecutionAction].self, forKey: .preActions)
            postActions = try container.decode([ExecutionAction].self, forKey: .postActions)
        }
    }

    public struct Run: BuildAction, Swift.Decodable {
        public var config: String?
        public var commandLineArguments: [String: Bool]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public init(
            config: String,
            commandLineArguments: [String: Bool] = [:],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = []
        ) {
            self.config = config
            self.commandLineArguments = commandLineArguments
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
        }

        public static func == (lhs: Run, rhs: Run) -> Bool {
            return lhs.config == rhs.config &&
                lhs.commandLineArguments == rhs.commandLineArguments &&
                lhs.preActions == rhs.postActions &&
                lhs.postActions == rhs.postActions &&
                lhs.environmentVariables == rhs.environmentVariables
        }

        enum CodingKeys: CodingKey {
            case config, commandLineArguments, preActions, postActions, environmentVariables
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            config = try container.decodeIfPresent(String.self, forKey: .config)
            commandLineArguments = try container.decodeIfPresent([String: Bool].self, forKey: .commandLineArguments) ?? [:]
            preActions = try container.decodeIfPresent([ExecutionAction].self, forKey: .preActions) ?? []
            postActions = try container.decodeIfPresent([ExecutionAction].self, forKey: .postActions) ?? []
            let decodableEnvironmentVariable = try container.decodeIfPresent([DecodableEnvironmentVariable].self,
                                                                             forKey: .environmentVariables) ?? []
            environmentVariables = decodableEnvironmentVariable.map { $0.environmentVariable }
        }
    }

    public struct Test: BuildAction, Swift.Decodable {
        public var config: String?
        public var gatherCoverageData: Bool
        public var commandLineArguments: [String: Bool]
        public var targets: [String]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public init(
            config: String,
            gatherCoverageData: Bool = false,
            commandLineArguments: [String: Bool] = [:],
            targets: [String] = [],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = []
        ) {
            self.config = config
            self.gatherCoverageData = gatherCoverageData
            self.commandLineArguments = commandLineArguments
            self.targets = targets
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
        }

        public static func == (lhs: Test, rhs: Test) -> Bool {
            return lhs.config == rhs.config &&
                lhs.commandLineArguments == rhs.commandLineArguments &&
                lhs.gatherCoverageData == rhs.gatherCoverageData &&
                lhs.targets == rhs.targets &&
                lhs.preActions == rhs.postActions &&
                lhs.postActions == rhs.postActions &&
                lhs.environmentVariables == rhs.environmentVariables
        }

        public var shouldUseLaunchSchemeArgsEnv: Bool {
            return commandLineArguments.isEmpty && environmentVariables.isEmpty
        }

        enum CodingKeys: CodingKey {
            case config, gatherCoverageData, commandLineArguments, targets, preActions, postActions, environmentVariables
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            config = try container.decodeIfPresent(String.self, forKey: .config)
            gatherCoverageData = try container.decodeIfPresent(Bool.self, forKey: .gatherCoverageData) ?? false
            commandLineArguments = try container.decodeIfPresent([String: Bool].self, forKey: .commandLineArguments) ?? [:]
            targets = try container.decodeIfPresent([String].self, forKey: .targets) ?? []
            preActions = try container.decodeIfPresent([ExecutionAction].self, forKey: .preActions) ?? []
            postActions = try container.decodeIfPresent([ExecutionAction].self, forKey: .postActions) ?? []
            let decodableEnvironmentVariable = try container.decodeIfPresent([DecodableEnvironmentVariable].self,
                                                                             forKey: .environmentVariables) ?? []
            environmentVariables = decodableEnvironmentVariable.map { $0.environmentVariable }
        }
    }

    public struct Analyze: BuildAction, Swift.Decodable {
        public var config: String?
        public init(config: String) {
            self.config = config
        }

        public static func == (lhs: Analyze, rhs: Analyze) -> Bool {
            return lhs.config == rhs.config
        }
    }

    public struct Profile: BuildAction, Swift.Decodable {
        public var config: String?
        public var commandLineArguments: [String: Bool]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public init(
            config: String,
            commandLineArguments: [String: Bool] = [:],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = []
        ) {
            self.config = config
            self.commandLineArguments = commandLineArguments
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
        }

        public static func == (lhs: Profile, rhs: Profile) -> Bool {
            return lhs.config == rhs.config &&
                lhs.commandLineArguments == rhs.commandLineArguments &&
                lhs.preActions == rhs.postActions &&
                lhs.postActions == rhs.postActions &&
                lhs.environmentVariables == rhs.environmentVariables
        }

        public var shouldUseLaunchSchemeArgsEnv: Bool {
            return commandLineArguments.isEmpty && environmentVariables.isEmpty
        }

        enum CodingKeys: CodingKey {
            case config, commandLineArguments, preActions, postActions, environmentVariables
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            config = try container.decodeIfPresent(String.self, forKey: .config)
            commandLineArguments = try container.decodeIfPresent([String: Bool].self, forKey: .commandLineArguments) ?? [:]
            preActions = try container.decodeIfPresent([ExecutionAction].self, forKey: .preActions) ?? []
            postActions = try container.decodeIfPresent([ExecutionAction].self, forKey: .postActions) ?? []
            let decodableEnvironmentVariable = try container.decodeIfPresent([DecodableEnvironmentVariable].self,
                                                                             forKey: .environmentVariables) ?? []
            environmentVariables = decodableEnvironmentVariable.map { $0.environmentVariable }
        }
    }

    public struct Archive: BuildAction, Swift.Decodable {
        public var config: String?
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public init(
            config: String,
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = []
        ) {
            self.config = config
            self.preActions = preActions
            self.postActions = postActions
        }

        public static func == (lhs: Archive, rhs: Archive) -> Bool {
            return lhs.config == rhs.config &&
                lhs.preActions == rhs.postActions &&
                lhs.postActions == rhs.postActions
        }
    }

    public struct BuildTarget: Equatable {
        public var target: String
        public var buildTypes: [BuildType]

        public init(target: String, buildTypes: [BuildType] = BuildType.all) {
            self.target = target
            self.buildTypes = buildTypes
        }

        public static func == (lhs: BuildTarget, rhs: BuildTarget) -> Bool {
            return lhs.target == rhs.target && lhs.buildTypes == rhs.buildTypes
        }
    }

    public static func == (lhs: Scheme, rhs: Scheme) -> Bool {
        return lhs.build == rhs.build &&
            lhs.run == rhs.run &&
            lhs.test == rhs.test &&
            lhs.analyze == rhs.analyze &&
            lhs.profile == rhs.profile &&
            lhs.archive == rhs.archive
    }
}

protocol BuildAction: Equatable {
    var config: String? { get }
}

extension Scheme.ExecutionAction: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        script = try jsonDictionary.json(atKeyPath: "script")
        name = jsonDictionary.json(atKeyPath: "name") ?? "Run Script"
        settingsTarget = jsonDictionary.json(atKeyPath: "settingsTarget")
    }
}

extension Scheme.Run: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        preActions = try jsonDictionary.json(atKeyPath: "preActions")?.map(Scheme.ExecutionAction.init) ?? []
        postActions = try jsonDictionary.json(atKeyPath: "postActions")?.map(Scheme.ExecutionAction.init) ?? []
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
    }
}

extension Scheme.Test: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        gatherCoverageData = jsonDictionary.json(atKeyPath: "gatherCoverageData") ?? false
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        targets = jsonDictionary.json(atKeyPath: "targets") ?? []
        preActions = try jsonDictionary.json(atKeyPath: "preActions")?.map(Scheme.ExecutionAction.init) ?? []
        postActions = try jsonDictionary.json(atKeyPath: "postActions")?.map(Scheme.ExecutionAction.init) ?? []
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
    }
}

extension Scheme.Profile: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        preActions = try jsonDictionary.json(atKeyPath: "preActions")?.map(Scheme.ExecutionAction.init) ?? []
        postActions = try jsonDictionary.json(atKeyPath: "postActions")?.map(Scheme.ExecutionAction.init) ?? []
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
    }
}

extension Scheme.Analyze: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
    }
}

extension Scheme.Archive: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        preActions = try jsonDictionary.json(atKeyPath: "preActions")?.map(Scheme.ExecutionAction.init) ?? []
        postActions = try jsonDictionary.json(atKeyPath: "postActions")?.map(Scheme.ExecutionAction.init) ?? []
    }
}

extension Scheme: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        build = try jsonDictionary.json(atKeyPath: "build")
        run = jsonDictionary.json(atKeyPath: "run")
        test = jsonDictionary.json(atKeyPath: "test")
        analyze = jsonDictionary.json(atKeyPath: "analyze")
        profile = jsonDictionary.json(atKeyPath: "profile")
        archive = jsonDictionary.json(atKeyPath: "archive")
    }
}

extension Scheme.Build: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        let targetDictionary: JSONDictionary = try jsonDictionary.json(atKeyPath: "targets")
        var targets: [Scheme.BuildTarget] = []
        for (target, possibleBuildTypes) in targetDictionary {
            let buildTypes: [BuildType]
            if let string = possibleBuildTypes as? String {
                switch string {
                case "all": buildTypes = BuildType.all
                case "none": buildTypes = []
                case "testing": buildTypes = [.testing, .analyzing]
                case "indexing": buildTypes = [.testing, .analyzing, .archiving]
                default: buildTypes = BuildType.all
                }
            } else if let enabledDictionary = possibleBuildTypes as? [String: Bool] {
                buildTypes = enabledDictionary.filter { $0.value }.flatMap { BuildType.from(jsonValue: $0.key) }
            } else if let array = possibleBuildTypes as? [String] {
                buildTypes = array.flatMap(BuildType.from)
            } else {
                buildTypes = BuildType.all
            }
            targets.append(Scheme.BuildTarget(target: target, buildTypes: buildTypes))
        }
        self.targets = targets.sorted { $0.target < $1.target }
        preActions = try jsonDictionary.json(atKeyPath: "preActions")?.map(Scheme.ExecutionAction.init) ?? []
        postActions = try jsonDictionary.json(atKeyPath: "postActions")?.map(Scheme.ExecutionAction.init) ?? []
        parallelizeBuild = jsonDictionary.json(atKeyPath: "parallelizeBuild") ?? true
        buildImplicitDependencies = jsonDictionary.json(atKeyPath: "buildImplicitDependencies") ?? true
    }
}

extension BuildType: JSONPrimitiveConvertible {

    public typealias JSONType = String

    public static func from(jsonValue: String) -> BuildType? {
        switch jsonValue {
        case "test", "testing": return .testing
        case "profile", "profiling": return .profiling
        case "run", "running": return .running
        case "archive", "archiving": return .archiving
        case "analyze", "analyzing": return .analyzing
        default: return nil
        }
    }

    public static var all: [BuildType] {
        return [.running, .testing, .profiling, .analyzing, .archiving]
    }
}

extension XCScheme.EnvironmentVariable: JSONObjectConvertible, Equatable {

    private static func parseValue(_ value: Any) -> String {
        if let bool = value as? Bool {
            return bool ? "YES" : "NO"
        } else {
            return String(describing: value)
        }
    }

    public init(jsonDictionary: JSONDictionary) throws {

        if let value = jsonDictionary["value"] {
            self.value = XCScheme.EnvironmentVariable.parseValue(value)
        } else {
            // will throw error
            value = try jsonDictionary.json(atKeyPath: "value")
        }
        variable = try jsonDictionary.json(atKeyPath: "variable")
        enabled = (try? jsonDictionary.json(atKeyPath: "isEnabled")) ?? true
    }

    static func parseAll(jsonDictionary: JSONDictionary) throws -> [XCScheme.EnvironmentVariable] {
        if let variablesDictionary: [String: Any] = jsonDictionary.json(atKeyPath: "environmentVariables") {
            return variablesDictionary.mapValues(parseValue)
                .map { XCScheme.EnvironmentVariable(variable: $0.key, value: $0.value, enabled: true) }
                .sorted { $0.variable < $1.variable }
        } else if let variablesArray: [JSONDictionary] = jsonDictionary.json(atKeyPath: "environmentVariables") {
            return try variablesArray.map(XCScheme.EnvironmentVariable.init)
        } else {
            return []
        }
    }

    public static func == (lhs: XCScheme.EnvironmentVariable, rhs: XCScheme.EnvironmentVariable) -> Bool {
        return lhs.variable == rhs.variable &&
            lhs.value == rhs.value &&
            lhs.enabled == rhs.enabled
    }
}
