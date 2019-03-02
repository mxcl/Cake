import Base
import Path

public final class Module: Codable {
    public let name: String
    public let path: Path
    public let dependencies: [Module]
    public let files: [Path]

    // if nil the SwiftVersion is determined by the project
    public let swiftVersion: SwiftVersion?

    var relativeFiles: [String] {
        return files.map{ $0.relative(to: path) }
    }

    init(name: String, directory: Path, dependencies: [Module], files: [Path], swift: SwiftVersion? = nil) {
        self.name = name
        self.path = directory
        self.dependencies = dependencies.sorted()
        self.files = files.sorted()
        self.swiftVersion = swift
    }

    enum CodingKeys: CodingKey {
        case name, path, dependencies, files, swiftVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(Path.self, forKey: .path)
        files = try container.decode([String].self, forKey: .files).map(path.join)
        dependencies = try container.decode([Module].self, forKey: .dependencies)
        swiftVersion = try container.decode(SwiftVersion?.self, forKey: .swiftVersion)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try encodeCommon(to: &container)
        try container.encode(dependencies, forKey: .dependencies)
    }

    fileprivate func encodeCommon(to container: inout KeyedEncodingContainer<CodingKeys>) throws {
        //TODO no bangs!
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(files.map{ $0.relative(to: path) }, forKey: .files)
        try container.encode(swiftVersion, forKey: .swiftVersion)
    }
}

extension Array where Element == Module {
    /// encodes dependencies as references, thus avoiding potentially enormous JSON
    public func encode(to arrayContainer: inout UnkeyedEncodingContainer) throws {
        var encoded = Set<Module>()
        var stack = self
        while let module = stack.popLast() {
            var container = arrayContainer.nestedContainer(keyedBy: Module.CodingKeys.self)
            try module.encodeCommon(to: &container)
            try container.encode(module.dependencies.map(\.name), forKey: .dependencies)
            stack.append(contentsOf: module.dependencies.filter{ !encoded.contains($0) })
            encoded.insert(module)
        }
    }

    /// - Note: requires modules to be topographically sorted
    static public func decode(from arrayContainer: inout UnkeyedDecodingContainer) throws -> [Module] {
        var decoded: [String: Module] = [:]
        var rv = [Module]()
        while !arrayContainer.isAtEnd {
            let container = try arrayContainer.nestedContainer(keyedBy: Module.CodingKeys.self)
            let path = try container.decode(Path.self, forKey: .path)
            let deps = try container.decode([String].self, forKey: .dependencies).map{ decoded[$0]! }
            let files = try container.decode([String].self, forKey: .files).map(path.join)
            let name = try container.decode(String.self, forKey: .name)
            let swift = try container.decode(SwiftVersion?.self, forKey: .swiftVersion)
            let module = Module(name: name, directory: path, dependencies: deps, files: files, swift: swift)
            decoded[module.name] = module
            rv.append(module)
        }
        //TODO only return the “tips” (maybe?)
        return rv
    }
}

extension Module: Equatable, Hashable, Comparable {
    public static func ==(lhs: Module, rhs: Module) -> Bool {
        return lhs.path == rhs.path && lhs.dependencies == rhs.dependencies && lhs.files == rhs.files
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    public static func <(lhs: Module, rhs: Module) -> Bool {
        return lhs.name.compare(rhs.name) == .orderedAscending
    }
}

public extension Array where Element == Module {
    var flattened: [Module] {
        return topologicallySorted{ $0.dependencies }
    }

    var bases: [Module] {
        return flattened.filter {
            $0.dependencies.isEmpty
        }
    }
}

extension Module: CustomStringConvertible {
    public var description: String {
        return "<Module: \(name) [\(dependencies.map(\.name).joined(separator: ", "))]>"
    }

    public func dump() {
        func recursiveWalk(modules: [Module], prefix: String = "") {
            var hanger = prefix + "├── "

            for (index, module) in modules.enumerated() {
                if index == modules.count - 1 {
                    hanger = prefix + "└── "
                }

                print("\(hanger)\(module.name)")

                if !module.dependencies.isEmpty {
                    let replacement = (index == modules.count - 1) ?  "    " : "│   "
                    var childPrefix = hanger
                    let startIndex = childPrefix.index(childPrefix.endIndex, offsetBy: -4)
                    childPrefix.replaceSubrange(startIndex..<childPrefix.endIndex, with: replacement)
                    recursiveWalk(modules: module.dependencies, prefix: childPrefix)
                }
            }
        }

        print(name)
        recursiveWalk(modules: dependencies)
    }
}
