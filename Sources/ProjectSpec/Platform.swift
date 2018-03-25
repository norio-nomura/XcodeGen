import Foundation

public enum Platform: String, Swift.Decodable {
    case iOS
    case watchOS
    case tvOS
    case macOS
    public var carthageDirectoryName: String {
        switch self {
        case .macOS:
            return "Mac"
        default:
            return rawValue
        }
    }

    public static var all: [Platform] = [.iOS, .tvOS, .watchOS, .macOS]
}
