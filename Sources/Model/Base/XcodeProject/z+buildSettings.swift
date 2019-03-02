import CakefileDescription
import xcodeproj
import Base
import Path

public extension XcodeProject.Target {
    var debug: XCBuildConfiguration { return find(name: "Debug") }
    var release: XCBuildConfiguration { return find(name: "Release") }

    subscript(key: String) -> Any? {
        set {
            //TODO if nil don’t create configurations if so far they aren't created (which can happen easily for eg. target specific configuration lists)
            debug.buildSettings[key] = newValue
            release.buildSettings[key] = newValue
        }
        get {
            fatalError()
        }
    }

    private func find(name: String) -> XCBuildConfiguration {
        if let c = underlyingTarget.buildConfigurationList?.configuration(name: name) {
            return c
        } else {
            let c = XCBuildConfiguration(name: name)
            owner.add(c)
            if let list = underlyingTarget.buildConfigurationList {
                list.buildConfigurations.append(c)
            } else {
                let list = XCConfigurationList(buildConfigurations: [c])
                underlyingTarget.buildConfigurationList = list
                owner.add(list)
            }
            return c
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    static func commonBuildSettings(for platforms: Set<PlatformSpecification>, swift swiftVersion: SwiftVersion) -> [String: Any] {
        var foo: [String: Any] = [
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "COMBINE_HIDPI_IMAGES": "YES",  //prevents Xcode warning
            "SUPPORTED_PLATFORMS": platforms.flatMap(\.platform.supportedPlatforms),
            "SDKROOT": platforms.suggestedSdkRoot,
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": ["Cake"],
            "USE_HEADERMAP": "NO", // copied from SwiftPM which provides rationale
            "CLANG_ENABLE_OBJC_WEAK": "YES",
            "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
            "CLANG_WARN_BOOL_CONVERSION": "YES",
            "CLANG_WARN_COMMA": "YES",
            "CLANG_WARN_CONSTANT_CONVERSION": "YES",
            "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
            "CLANG_WARN_EMPTY_BODY": "YES",
            "CLANG_WARN_ENUM_CONVERSION": "YES",
            "CLANG_WARN_INFINITE_RECURSION": "YES",
            "CLANG_WARN_INT_CONVERSION": "YES",
            "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
            "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
            "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
            "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
            "CLANG_WARN_STRICT_PROTOTYPES": "YES",
            "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
            "CLANG_WARN_UNREACHABLE_CODE": "YES",
            "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
            "ENABLE_STRICT_OBJC_MSGSEND": "YES",
            "GCC_NO_COMMON_BLOCKS": "YES",
            "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
            "GCC_WARN_ABOUT_RETURN_TYPE": "YES",
            "GCC_WARN_UNDECLARED_SELECTOR": "YES",
            "GCC_WARN_UNINITIALIZED_AUTOS": "YES",
            "GCC_WARN_UNUSED_FUNCTION": "YES",
            "GCC_WARN_UNUSED_VARIABLE": "YES",
            "SWIFT_VERSION": swiftVersion.rawValue,
            "SKIP_INSTALL": "YES"
        ]
        for spec in platforms {
            switch spec.platform {
            case .iOS:
                foo["IPHONEOS_DEPLOYMENT_TARGET"] = spec.version.description
            case .macOS:
                foo["MACOSX_DEPLOYMENT_TARGET"] = spec.version.description
            }
        }
        return foo
    }

    static var debugBuildSettings: [String: Any] {
        return [
            "COPY_PHASE_STRIP": "NO",
            "DEBUG_INFORMATION_FORMAT": "dwarf",
            "ENABLE_NS_ASSERTIONS": "YES",
            "GCC_OPTIMIZATION_LEVEL": "0",
            "ONLY_ACTIVE_ARCH": "YES",
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": ["Cake", "DEBUG"],
            "ENABLE_TESTABILITY": "YES",
        ]
    }

    static var releaseBuildSettings: [String: Any] {
        return [
            "COPY_PHASE_STRIP": "YES",
            "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
            "GCC_OPTIMIZATION_LEVEL": "s",
            "SWIFT_OPTIMIZATION_LEVEL": "-Owholemodule",
            "SWIFT_COMPILATION_MODE": "wholemodule",
        ]
    }
}

private extension Platform {
    var supportedPlatforms: [String] {
        switch self {
        case .iOS:
            return ["iphoneos", "iphonesimulator"]
        case .macOS:
            return ["macosx"]
        }
    }
}

private extension Set where Element == PlatformSpecification {
    var suggestedSdkRoot: String {
        if map(\.platform).contains(.macOS) {
            return "macosx"
        } else {
            return "iphoneos"
        }
    }
}
