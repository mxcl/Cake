import struct CakefileDescription.PlatformSpecification
import enum Base.SwiftVersion
import XcodeProject
import Foundation
import Path

struct ExtractedData {
    let path: Path
    let swiftVersion: Base.SwiftVersion
    let platforms: Set<PlatformSpecification>
    let mtime: Date?

    init(path: Path) throws {
        self.path = path
        let xcodeproj = try XcodeProject(existing: path)
        swiftVersion = xcodeproj.swiftVersion
        platforms = xcodeproj.deploymentTargets
        mtime = path.mtime
    }
}
