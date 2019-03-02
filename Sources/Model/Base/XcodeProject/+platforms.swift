import CakefileDescription
import xcodeproj
import Version
import Base

public extension XcodeProject {
    var platforms: Set<PlatformSpecification> {

        func extract(buildConfiguration: XCBuildConfiguration) -> [(Platform, Version)] {
            return buildConfiguration.platforms.compactMap {
                guard let v = buildConfiguration.deploymentVersion(for: $0) else { return nil }
                return ($0, v)
            }
        }

        var rv = [Platform: Version]()
        for (platform, version) in pbxproj.buildConfigurations.flatMap(extract) {
            rv[platform] = min(rv[platform, default: version], version)
        }

        return Set(rv.map(PlatformSpecification.init))
    }

    var swiftVersion: SwiftVersion {
        return pbxproj.buildConfigurations.compactMap {
            $0.buildSettings["SWIFT_VERSION"] as? String
        }.compactMap(SwiftVersion.init).max() ?? .default
    }
}

private extension Platform {
    init?(buildSetting: Any?) {
        switch buildSetting as? String {
        case "maxosx"?:
            self = .macOS
        case "iphoneos"?, "iphonesimulator"?:
            self = .iOS
        default:
            return nil
        }
    }
}

extension XCBuildConfiguration {
    fileprivate var platforms: Set<Platform> {
        if let foo = buildSettings["SUPPORTED_PLATFORMS"] as? [String] {
            return Set(foo.compactMap(Platform.init(buildSetting:)))
        } else if let foo = buildSettings["SDKROOT"] as? String, let platform = Platform(buildSetting: foo) {
            return [platform]
        } else {
            return []
        }
    }

    public func deploymentVersion(for platform: Platform) -> Version? {
        var string: String? {
            switch platform {
            case .macOS:
                return buildSettings["MACOSX_DEPLOYMENT_TARGET"] as? String
            case .iOS:
                return buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] as? String
            }
        }
        guard let str = string, let f = Double(str) else {
            return nil
        }
        return Version(floatLiteral: f)
    }
}

extension XcodeProject {
    public func deploymentVersion(for platform: Platform) -> Version? {
        return pbxproj.buildConfigurations.compactMap {
            $0.buildSettings[platform.buildConfigurationKey] as? String
        }.compactMap(Version.init(tolerant:)).max()
    }

    public var deploymentTargets: Set<PlatformSpecification> {
        return Set([Platform.iOS, .macOS].compactMap { platform in
            deploymentVersion(for: platform).map {
                PlatformSpecification(platform: platform, version: $0)
            }
        })
    }
}

private extension Platform {
    var buildConfigurationKey: String {
        switch self {
        case .iOS:
            return "IPHONEOS_DEPLOYMENT_TARGET"
        case .macOS:
            return "MACOSX_DEPLOYMENT_TARGET"
        }
    }
}
