#if !Cake
@_exported import struct Foundation.URL
#endif
import Foundation
import Version



#if !Cake
// ^^ Defined when building Batter, thus when building dylib for consumption
// by Cake Projects is *not* defined, thus anything here is available to
// all users of Cake except inside the mxcl/Cake project itself.

/// Dependencies for your Model (can be used by App too, but we will eventually add a separate
public var dependencies: [Dependency] = []

/// Checks out the dependency but does not integrate, integration is up to you
public var vendors: [Vendor] = []

/**
 Will also build executables and then make those executables available for scripts
 possibly make it possible for these tools to define their own scripts for user benefit
*/
public var buildDependencies: [Dependency] = []

/// Configures the build targets for model modules
public var platforms: Set<PlatformSpecification> = []

/// Configurable parameters for your Cake.
public var options = Options()

#endif


/// Various configurable properties.
public struct Options: Codable {
    /// The name of the base model module, if there is only one.
    public var baseModuleName = "Bakeware"

    /// If `true`, warnings in dependencies are suppressed.
    public var suppressDependencyWarnings = true

  #if Cake
    public init()
    {}
  #endif
}


public enum Dependency {
    case github(GitHubPackageSpecification)
    case git(PackageSpecification)
//TODO    case xcode(VersionSpecification)
    case cake(Range<Version>)
}

public enum VersionSpecification: Codable, Equatable {
    case version(Constraint)
    case ref(Ref)

    public enum Constraint {
        case range(Range<Version>)
        case exact(Version)
    }

    public enum Ref {
        case branch(String)
        case tag(String)
        case revision(String)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.version) {
            let str = try container.decode(String.self, forKey: .version)
            let parts = str.components(separatedBy: "..<")
            switch parts.count {
            case 2:
                guard let v1 = Version(parts[0]), let v2 = Version(parts[1]) else { fallthrough }
                self = .version(.range(v1..<v2))
            case 1:
                guard let v = Version(str) else { fallthrough }
                self = .version(.exact(v))
            default:
                throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.version], debugDescription: "Invalid version specification"))
            }
        } else if container.contains(.branch) {
            self = .ref(.branch(try container.decode(String.self, forKey: .branch)))
        } else if container.contains(.tag) {
            self = .ref(.tag(try container.decode(String.self, forKey: .tag)))
        } else if container.contains(.revision) {
            self = .ref(.revision(try container.decode(String.self, forKey: .revision)))
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid version specification"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .version(.range(let range)):
            try container.encode("\(range.lowerBound)..<\(range.upperBound)", forKey: .version)
        case .version(.exact(let version)):
            try container.encode(version, forKey: .version)
        case .ref(.branch(let branch)):
            try container.encode(branch, forKey: .branch)
        case .ref(.tag(let tag)):
            try container.encode(tag, forKey: .branch)
        case .ref(.revision(let sha)):
            try container.encode(sha, forKey: .branch)
        }
    }

    enum CodingKeys: CodingKey {
        case version
        case branch
        case tag
        case revision
    }

    public static func ==(lhs: VersionSpecification, rhs: VersionSpecification) -> Bool {
        switch (lhs, rhs) {
        case (.version(.range(let range1)), .version(.range(let range2))):
            return range1 == range2
        case (.version(.exact(let v1)), .version(.exact(let v2))):
            return v1 == v2
        case (.ref(.branch(let b1)), .ref(.branch(let b2))):
            return b1 == b2
        case (.ref(.tag(let b1)), .ref(.tag(let b2))):
            return b1 == b2
        case (.ref(.revision(let b1)), .ref(.revision(let b2))):
            return b1 == b2
        default:
            return false
        }
    }
}

public struct PackageSpecification: Codable, Equatable  {
    public init(url: URL, constraint: VersionSpecification) {
        self.url = url
        self.constraint = constraint
    }
    public var url: URL
    public var constraint: VersionSpecification

    enum CodingKeys: CodingKey {
        case url
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try constraint.encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        url = try decoder.container(keyedBy: CodingKeys.self).decode(URL.self, forKey: .url)
        constraint = try VersionSpecification(from: decoder)
    }
}

public struct GitHubPackageSpecification {
    public var user: String
    public var repo: String
    public var constraint: VersionSpecification

    fileprivate var packageSpecification: PackageSpecification {
        let url = URL(string: "https://github.com/\(user)/\(repo).git")!
        return .init(url: url, constraint: constraint)
    }

    public init(user: String, repo: String, constraint: VersionSpecification) {
        self.user = user
        self.repo = repo
        self.constraint = constraint
    }
}

public enum Platform: String, Codable, Hashable, Equatable {
    case iOS, macOS
}

public struct PlatformSpecification: Codable, Equatable, Hashable {
    public let platform: Platform
    public let version: Version

    //FIXME Set semantics may make this bad in practice
    func hasher(into hasher: inout Hasher) {
        hasher.combine(platform)
    }

    public init(platform: Platform, version: Version) {
        self.platform = platform
        self.version = version
    }
}

extension PlatformSpecification: CustomStringConvertible {
    public var description: String {
        var str = ".\(platform) ~> \(version.major).\(version.minor)"
        if version.patch > 0 {
            str += ".\(version.patch)"
        }
        return str
    }
}

extension GitHubPackageSpecification: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        (user, repo) = value.githubPair
        self.constraint = .version(.range(Version(0,0,0)..<Version(1_000_000,0,0)))

        warning("Specifying packages without a version constraint (~>) fetches the newest release, which while seemingly convenient—in extreme cases—may lead to irritable co‐workers.")
    }
}

extension PackageSpecification: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.url = URL(string: "https://github.com/\(value.githubPair).git")!
        self.constraint = .ref(.branch("master"))

        warning("Specifying packages without a version constraint (~>) fetches `master` which—in extreme cases—may lead to irritable co‐workers.")
    }
}

extension VersionSpecification: ExpressibleByFloatLiteral {
    @inlinable
    public init(floatLiteral value: FloatLiteralType) {
        self = .version(.exact(Version(value)))
    }
}

public enum Vendor {
    case github(PackageSpecification)
}

public func ~> (lhs: String, rhs: Double) -> GitHubPackageSpecification {
    let (user, repo) = lhs.githubPair
    return .init(user: user, repo: repo, constraint: .version(.range(~>rhs)))
}

public func ~> (lhs: String, rhs: Version) -> GitHubPackageSpecification {
    let (user, repo) = lhs.githubPair
    return .init(user: user, repo: repo, constraint: .version(.range(~>rhs)))
}

public func ~> (lhs: Platform, rhs: Double) -> PlatformSpecification {
    return .init(platform: lhs, version: Version(floatLiteral: rhs))
}

public func ~> (lhs: Platform, rhs: Version) -> PlatformSpecification {
    return .init(platform: lhs, version: rhs)
}

prefix operator ~>
public prefix func ~> (value: Double) -> Range<Version> {
    let v = Version(floatLiteral: value)
    return v..<Version(v.major + 1, 0, 0)
}

public prefix func ~> (value: Version) -> Range<Version> {
    return value..<Version(value.major + 1, 0, 0)
}

private func warning(_ msg: String) {
    fputs("warning: \(msg)\n", stderr)
}

private extension String {
    var githubPair: (String, String) {
        if hasPrefix("/") {
            warning("package specifier has leading slashes")
        }
        if hasSuffix("/") {
            warning("package specifier has trailing slashes")
        }

        let split = self.split(separator: "/", omittingEmptySubsequences: true)

        if split.count < 2 {
            warning("insufficient path components for package specification, SwiftPM *will* fail")
        }
        if split.count > 2 {
            warning("ignoring components in package specification beyond 2")
        }

        return (String(split[0]), String(split[1]))
    }
}

public struct CakefileDump: Codable {
    public let platforms: Set<PlatformSpecification>
    public let dependencies: [PackageSpecification]
    public let options: Options
    public let cake: VersionSpecification?
    // ^^ not Range<Version> as Range is not codable, and we cannot
    // make it codable without a public impl which would infect
    // the entire app. Swift 5 has a Codable impl though.

    public init(platforms: Set<PlatformSpecification>, dependencies: [Dependency], options: Options) {
        self.platforms = platforms
        self.dependencies = dependencies.compactMap {
            if case .github(let spec) = $0 {
                return spec.packageSpecification
            } else {
                return nil
            }
        }
        self.options = options
        self.cake = dependencies.compactMap {
            if case .cake(let range) = $0 {
                return .version(.range(range))
            } else {
                return nil
            }
        }.last
    }
}
