import XcodeProject

public extension XcakeProject {
    func deintegrate(_ proj: XcodeProject) throws {

        for target in proj.nativeTargets {
            target.purge(cakeTarget)
        }
        proj.removeProjectReference(self)

        try proj.write()
    }
}
