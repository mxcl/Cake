import Foundation

func warning(_ msg: Any) {
    fputs("warning: \(msg)\n", stderr)
}

func error(_ msg: Any) -> Never {
    fputs("error: \(msg)\n", stderr)
    exit(1)
}

import Version
import Path

public extension Processor {
    struct Toolkit {
        public let xcodePath: Path
        public let cakeVersion: Version
        public let xcodeProductBuildVersion: String

        static var derivedData: Path {
            return Path.home.Library.Developer.Cake.DerivedData
        }

        var makedir: Path {
            return Toolkit.derivedData/xcodeProductBuildVersion
        }
        var L: Path {
            return makedir/"lib"
        }
        var I: Path {
            return L
        }
        var pm: Path {
            return L.pm
        }

        public var swift: Path {
            return xcodePath/"Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
        }

        public init?(cake: Version, xcode: Path) {
            guard let dict = NSDictionary(contentsOf: xcode.join("Contents/version.plist").url) else {
                return nil
            }
            guard let v = dict["ProductBuildVersion"] as? String else {
                return nil
            }
            xcodeProductBuildVersion = v
            cakeVersion = cake
            xcodePath = xcode
        }
    }
}

func isDirty(input: Date?, cache: Date?) -> Bool {
    if let a = input, let b = cache {
        return a > b
    } else {
        return true
    }
}
