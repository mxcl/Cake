import struct CakefileDescription.PlatformSpecification
import enum Base.SwiftVersion
import XcakeProject
import XcodeProject
import Foundation
import Modelizer
import Path

public class Processor {
    /// path to the Xcode Project that is Cake
    public let xcodeproj: Path

    /// time that the last generation attempt *completed*
    public internal(set) var lastGenerationTime: Date?

    var cakefile: Cakefile
    var dependencies: Dependencies
    var extractedData: ExtractedData

    var platforms: Set<PlatformSpecification> {
        return cakefile.platforms.union(extractedData.platforms)
    }

    public var cakefilePath: Path { return cakefile.path }
    public var prefix: Path { return xcodeproj.parent }
    public var modelsPrefix: Path { return prefix/"Sources/Model" }

    public let toolkit: Toolkit

    public init(xcodeproj: Path, toolkit: Toolkit) throws {
        //TODO should load from JSON unless mtime is greater
        self.toolkit = toolkit
        self.xcodeproj = xcodeproj
        (cakefile, dependencies) = try toolkit.foo(prefix: xcodeproj.parent)
        self.extractedData = try ExtractedData(path: xcodeproj)
        try _generate(tips: getTips())
    }

    var previousTips = Set<Module>()

    private func getTips() throws -> [Module] {
        return try modelize(root: modelsPrefix, basename: cakefile.options.baseModuleName)
    }

    func _generate(tips: [Module], set: Set<Module>? = nil) throws {
        try XcakeProject(
            tips: tips,
            dependencies: dependencies.json,
            prefix: prefix,
            platforms: platforms,
            swift: extractedData.swiftVersion,
            suppressDependencyWarnings: cakefile.options.suppressDependencyWarnings
        ).write()
        previousTips = set ?? Set(tips)
        lastGenerationTime = Date()
    }

    /// - Parameter force: force generation ignoring dependency information
    /// - Returns: if generation occurred
    @discardableResult
    public func generate(force: Bool = false) throws -> Bool {

        //TODO change detection could be more efficient
        // no need to calculate modules for eg. if directory structure is identical
        // FSEvent system provides granular event detail, and we're only interested
        // in move, rename, create and delete basically and then only if they are
        // swift files or directories that contain swift files or subdirectories
        // with swift files

        var needsGeneration = false

        guard !force else {
            (cakefile, dependencies) = try toolkit.foo(prefix: prefix)
            extractedData = try ExtractedData(path: xcodeproj)
            let tips = try getTips()
            previousTips = Set(tips)
            try _generate(tips: tips)
            return true
        }

        try toolkit.make()

        if isDirty(input: cakefilePath.mtime, cache: cakefile.mtime) {
            cakefile = try toolkit.bar(prefix: prefix)
            needsGeneration = true
        }

        if cakefile.dependencies != dependencies.cakefileRepresentation {
            //FIXME not DRY
            dependencies = try Dependencies(deps: cakefile.dependencies, prefix: prefix, bindir: toolkit.bindir, libpmdir: toolkit.pm, DEVELOPER_DIR: toolkit.xcodePath)
            needsGeneration = true

            //FIXME currently the Mixer writes dependencies.json, but maybe we should?
        }

        if isDirty(input: extractedData.path.mtime, cache: extractedData.mtime) {
            extractedData = try ExtractedData(path: xcodeproj)
        }

        let tips = try getTips()
        let set = Set(tips)

        needsGeneration = needsGeneration || set != previousTips

        if needsGeneration {
            try _generate(tips: tips, set: set)
            return true
        } else {
            return false
        }
    }
}


private extension Processor.Toolkit {
    func foo(prefix: Path) throws -> (Cakefile, Dependencies) {
        try make()
        let cakefile = try bar(prefix: prefix)
        let dependencies = try Dependencies(deps: cakefile.dependencies, prefix: prefix, bindir: bindir, libpmdir: pm, DEVELOPER_DIR: xcodePath)
        return (cakefile, dependencies)
    }

    func bar(prefix: Path) throws -> Cakefile {
        let cakefile = try Cakefile(path: prefix/"Cakefile.swift", toolkit: self)
        if let requirement = cakefile.cakeRequirement, !requirement.contains(cakeVersion) {
            throw E.toolkit(required: requirement, available: cakeVersion)
        }
        return cakefile
    }
}

private extension Bundle {
    var executables: Path {
        return executablePath.flatMap(Path.init)!.parent
    }
}
