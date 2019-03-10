import Foundation
import Modelizer
import Processor
import Path

public protocol CakeProjectDelegate: class {
    func cakeProjectCakefileChanged(_ cake: CakeProject)
    func cakeProjectModulesChanged(_ cake: CakeProject)
    func cakeProjectDependenciesUpdated(_ cake: CakeProject)
}

public class CakeProject {
    let processor: Processor

    public var xcodeproj: Path { return processor.xcodeproj }
    public var prefix: Path { return processor.prefix }
    public var lastGenerationTime: Date? { return processor.lastGenerationTime }

    private let fswatcher = FSWatcher()

    weak var delegate: CakeProjectDelegate?

    var modelsPrefix: Path { return processor.modelsPrefix }
    var cakefile: Path { return processor.cakefilePath }

    public var name: String {
        return xcodeproj.basename(dropExtension: true)
    }

    init(xcodeproj: Path, toolkit: Processor.Toolkit) throws {
        do {
            processor = try Processor(xcodeproj: xcodeproj, toolkit: toolkit)

            fswatcher.delegate = self
            fswatcher.watchingPaths = [modelsPrefix.string, cakefile.string]

            try generateXcodeproj()

        } catch ProcessorError.noCakefile {
            throw E.notCake(xcodeproj.parent)
        }
    }

    public func forceRegenerate() throws {
        try processor.generate(force: true)
    }

    func processCakefile() throws {
        fatalError()
    }

    @discardableResult
    func generateXcodeproj() throws -> Bool {
        //TODO don't do cakefile too!
        return try processor.generate()
    }

    public func updateDependencies() throws {
        try processor.updateDependencies()
        delegate?.cakeProjectDependenciesUpdated(self)
    }
}

extension CakeProject: FSWatcherDelegate {
    func fsWatcherRescanRequired() {
        delegate?.cakeProjectModulesChanged(self)
    }

    func fsWatcher(paths: [String], events: [FSWatcher.Event]) {
        for (path, event) in zip(paths, events) {
            if path == cakefile.string {
                if event == .modified {
                    delegate?.cakeProjectCakefileChanged(self)
                    return  // triggers module scan too
                }
            } else {
                delegate?.cakeProjectModulesChanged(self)
            }
        }
    }
}
