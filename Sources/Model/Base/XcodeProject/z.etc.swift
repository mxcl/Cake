import struct PathKit.Path
import struct Path.Path
import Foundation
import xcodeproj

typealias PathKitPath = PathKit.Path

extension PathKitPath {
    init(_ path: PathType) {
        self.init(path.string)
    }
}

extension XcodeProject.NativeTarget {
    var linkPhase: PBXFrameworksBuildPhase {
        if let phase = underlyingTarget.buildPhases.first(where: { $0 is PBXFrameworksBuildPhase }) {
            return phase as! PBXFrameworksBuildPhase
        } else {
            let phase = PBXFrameworksBuildPhase()
            underlyingTarget.buildPhases.append(phase)
            owner.add(phase)
            return phase
        }
    }

    var sourcesPhase: PBXSourcesBuildPhase {
        if let phase = try? underlyingTarget.sourcesBuildPhase() {
            return phase
        } else {
            let phase = PBXSourcesBuildPhase()
            underlyingTarget.buildPhases.append(phase)
            owner.add(phase)
            return phase
        }
    }

    var resourcesPhase: PBXResourcesBuildPhase {
        if let phase = try? underlyingTarget.resourcesBuildPhase() {
            return phase
        } else {
            let phase = PBXResourcesBuildPhase()
            underlyingTarget.buildPhases.append(phase)
            owner.add(phase)
            return phase
        }
    }
}
