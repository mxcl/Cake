import class Modelizer.Module
import XcodeObserver
import Foundation
import Processor
import Version
import Path

enum E: Error {
    case notCake(Path)
    case xcodeTooOld
    case xcodeVersionUnavailable
}

public extension Version {
    static var minXcode: Version {
        return Version(10,2,0)
    }
}

/// knows what Xcode projects are open and which are Cakes
public class Kitchen {
    public init(cake version: Version) {
        self.cakeVersion = version
    }

    let cakeVersion: Version

    public weak var delegate: KitchenDelegate? {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            
            xcodeObserver.delegate = delegate == nil ? nil : self
        }
    }

    let xcodeObserver = XcodeObserver()

    public private(set) var cakes: [CakeProject] = []
    public private(set) var notCakes: [Path] = []

    /// called via AppleScript bridge
    public func generate(for path: Path) throws {
        dispatchPrecondition(condition: .onQueue(.main))

        for cake in cakes {
            if cake.prefix == path {
                _ = try cake.generateXcodeproj()
                return
            }
        }
        throw E.notCake(path)
    }

    public var activeWorkspace: Path? {
        return xcodeObserver.activeWorkspace
    }
}

extension Kitchen: XcodeObserverDelegate {
    public func xcode(runStatus: RunStatus) {
        dispatchPrecondition(condition: .onQueue(.main))

        switch runStatus {
        case .notRunning:
            delegate?.xcode(isRunning: false)
        case .running(let versions) where versions.count == 1 && versions[0] < .minXcode:
            delegate?.kitchen(error: E.xcodeTooOld)
        case .running:
            delegate?.xcode(isRunning: true)
        }
    }

    public func xcode(workspaceDiff diff: Diff<Path>) {
        dispatchPrecondition(condition: .onQueue(.main))

        cakes.remove(paths: diff.removed)

        for path in diff.added {
            do {
                //TODO path needs to be determined from the Xcode for this project
                guard let xcodePath = xcodeObserver.paths.first, let toolkit = Processor.Toolkit(cake: cakeVersion, xcode: xcodePath) else {
                    throw E.xcodeVersionUnavailable
                }
                let proj = try CakeProject(xcodeproj: path, toolkit: toolkit)
                proj.delegate = self
                cakes.append(proj)
            } catch E.notCake {
                //noop
            } catch {
                delegate?.kitchen(error: error)
            }
        }

        notCakes = xcodeObserver.openWorkspaces.subtracting(cakes.map(\.xcodeproj)).sorted()

        delegate?.kitchen(
            cake: cakes,
            notCake: notCakes.map{ $0.basename(dropExtension: true) })
    }

    public func xcode(error: Error) {
        dispatchPrecondition(condition: .onQueue(.main))

        delegate?.kitchen(error: error)
    }
}

extension Kitchen: CakeProjectDelegate {
    public func cakeProjectCakefileChanged(_ cake: CakeProject) {
        dispatchPrecondition(condition: .onQueue(.main))

        do {
            try cake.processCakefile()
            if try cake.generateXcodeproj() {
                delegate?.kitchen(regenerated: cake)
            }
        } catch {
            delegate?.kitchen(error: error)
        }
    }

    public func cakeProjectModulesChanged(_ cake: CakeProject) {
        dispatchPrecondition(condition: .onQueue(.main))

        do {
            if try cake.generateXcodeproj() {
                delegate?.kitchen(regenerated: cake)
            }
        } catch {
            delegate?.kitchen(error: error)
        }
    }

    public func cakeProjectDependenciesUpdated(_ cake: CakeProject) {
        dispatchPrecondition(condition: .onQueue(.main))

        delegate?.kitchen(regenerated: cake)
    }
}

private extension Array where Element == CakeProject {
    mutating func remove(paths: Set<Path>) {
        guard !paths.isEmpty else { return }
        removeAll {
            paths.contains($0.xcodeproj)
        }
    }
}
