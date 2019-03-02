enum Error: Swift.Error {
    /// Couldn't find all tools needed by the package manager.
    case invalidToolchain(problem: String)

    /// The root manifest was not found.
    case rootManifestFileNotFound

    /// There were fatal diagnostics during the operation.
    case hasFatalDiagnostics
}

import protocol Workspace.WorkspaceDelegate
import struct PackageGraph.PackageGraph
import struct Basic.Diagnostic
import class Workspace.ManagedDependency

public class Delegate: WorkspaceDelegate {
    public init()
    {}

    public func packageGraphWillLoad(currentGraph: PackageGraph, dependencies: AnySequence<ManagedDependency>, missingURLs: Set<String>) {

    }

    public func fetchingWillBegin(repository: String) {

    }

    public func fetchingDidFinish(repository: String, diagnostic: Diagnostic?) {

    }

    public func cloning(repository: String) {

    }

    public func removing(repository: String) {

    }

    public func managedDependenciesDidUpdate(_ dependencies: AnySequence<ManagedDependency>) {

    }
}

import struct Basic.Diagnostic

extension Diagnostic.Behavior: CustomStringConvertible {
    public var description: String {
        switch self {
        case .error:
            return "error"
        case .warning:
            return "warning"
        case .note:
            return "note"
        case .ignored:
            return "ignored"
        }
    }
}

import func Darwin.fputs
import func Darwin.exit
import var Darwin.stderr

public func doctor(diagnostic: Diagnostic) {
    switch diagnostic.id.name {
    case "org.swift.diags.workspace.PD3DeprecatedDiagnostic":
        // The consumer cannot help that the Package in question is poorly maintained
        // we *could* show the warning as it would encourage the consumer to report
        // the bug or even update the manifest with a PR. But in my experience nobody
        // does, instead they have to search the Internet for workarounds so that they
        // can hide this warning. We prioritize DX and user-satisfaction.
        break
    case "org.swift.diags.unused-dependency":
        // Our manifest has no targets so this warning is always emitted
        break
    default:
        fputs("\(diagnostic.behavior): \(diagnostic.data)\n", stderr)
    }
}

public func error(_ message: Any) -> Never {
    fputs("error: \(message)\n", stderr)
    exit(1)
}

public func warning(_ message: Any) {
    fputs("warning: \(message)\n", stderr)
}

import class PackageModel.ResolvedPackage
import class PackageModel.ResolvedTarget

public extension ResolvedPackage {
    var libraryTargets: [ResolvedTarget] {
        return targets.filter{ $0.type == .library }
    }
}

public extension Array where Element == ResolvedPackage {
    var libraryTargets: [ResolvedTarget] {
        return flatMap(\.targets).filter{ $0.type == .library }
    }
}
