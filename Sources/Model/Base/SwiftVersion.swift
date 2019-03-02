/// The Swift version specifications that Xcode supports
public enum SwiftVersion: String, Comparable, Codable {
    case v4 = "4"
    case v4_2 = "4.2"
    case v5 = "5.0"

    private var intValue: Int {
        switch self {
        case .v4:
            return 04_00_00
        case .v4_2:
            return 04_02_00
        case .v5:
            return 05_00_00
        }
    }

    public static func <(lhs: SwiftVersion, rhs: SwiftVersion) -> Bool {
        return lhs.intValue < rhs.intValue
    }

#if false
    public var version: Version {
        switch self {
        case .v4:
            return Version(4,0,0)
        case .v4_2:
            return Version(4,2,0)
        case .v5:
            return Version(5,0,0)
        }
    }
#endif

#if swift(>=5)
    public static let `default` = SwiftVersion.v5
#else
    public static let `default` = SwiftVersion.v4_2
#endif
}
