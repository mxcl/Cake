#if SWIFT_PACKAGE
import struct Workspace.Version
#else
import Version
#endif
import Path

public struct DependenciesJSON {
    public let modules: [Module]  // topologically sorted
    public let imports: [String]  // topologically sorted
    public let packages: [Package]

    public struct Package: Codable {
        public let name: String
        public let path: Path
        public let version: Version?  //TODO VersionSpecification
        public let moduleNames: [String]
    }

    public var isEmpty: Bool {
        return modules.isEmpty
    }
}

extension DependenciesJSON: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imports = try container.decode([String].self, forKey: .imports)
        var arrayContainer = try container.nestedUnkeyedContainer(forKey: .modules)
        modules = try .decode(from: &arrayContainer)
        packages = try container.decode([Package].self, forKey: .packages)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(imports, forKey: .imports)
        var arrayContainer = container.nestedUnkeyedContainer(forKey: .modules)
        try modules.encode(to: &arrayContainer)
        try container.encode(packages, forKey: .packages)
    }

    enum CodingKeys: CodingKey {
        case modules, imports, packages
    }
}

public extension DependenciesJSON {
    init() {
        modules = []
        imports = []
        packages = []
    }
}
