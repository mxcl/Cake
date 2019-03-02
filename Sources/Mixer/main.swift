/*
 Reads a Package.swift and converts the output to a list of Modules that
 Cake can embed in Cake.xcodeproj.

 We tried to use the generated Xcodeproj that SwiftPM can use but that
 proved overall undesirable since we needed to edit the resulting project
 to have a dependency on the Cakefile target in our Cake.xcodeproj.

 This worked but was tedious. Also the generated project only produced
 dynamic frameworks and we want static ones.

 This approach is neater and makes it possible to make it possible for
 Cake projects to be standalone which was a goal of the Cake menifesto.

 The other attempt was to use SwiftPM’s commands to output the module
 content for a Package.swift, however these commands do not output
 all the information we need (most vital was inter-package module
 dependencies). We may submit this PR to SwiftPM to add the information
 we need. But since SwiftPM has an annual release cycle, this was no
 good for our immediate needs.
 */

import struct Foundation.URL
import class Foundation.JSONEncoder
import class SourceControl.GitRepositoryProvider
import func Darwin.exit
import PackageLoading
import PackageGraph
import SPMUtility
import Workspace
import Modelize
import Basic
import Base
import Path

// hi, this code is hard to understand and really I don’t know what
// to do about it other than make a facade wrapper for SwiftPM.

guard CommandLine.arguments.count == 3 else {
    error("error: mixer <project-dir> <lib-pm-dir>")
}

let root = AbsolutePath(CommandLine.arguments[1])
let pkgpath = root.appending(component: ".cake")
let depsPath = root.appending(component: "Dependencies")
let swiftPath = try Process.checkNonZeroExit(arguments: ["xcrun", "--sdk", "macosx", "-f", "swift"]).spm_chomp()
let sdkroot = try Process.checkNonZeroExit(arguments: ["xcrun", "--sdk", "macosx", "--show-sdk-path"]).spm_chomp()
let L = AbsolutePath(CommandLine.arguments[2])

struct UserManifestResources: ManifestResourceProvider {
    let swiftCompiler: AbsolutePath
    let libDir: AbsolutePath
    let sdkRoot: AbsolutePath?
}

let manifestResources = UserManifestResources(
    swiftCompiler: AbsolutePath(swiftPath).parentDirectory.appending(component: "swiftc"),
    libDir: L,
    sdkRoot: AbsolutePath(sdkroot)
)

let loader = ManifestLoader(manifestResources: manifestResources)
let delegate = Delegate()
let provider = GitRepositoryProvider()
let workspace = Workspace(
    dataPath: pkgpath.appending(component: "swift-pm"),
    editablesPath: depsPath,
    pinsFile: pkgpath.appending(component: "Package.resolved"),
    manifestLoader: loader,
    toolsVersionLoader: ToolsVersionLoader(),
    delegate: delegate,
    repositoryProvider: provider,
    isResolverPrefetchingEnabled: true,
    skipUpdate: true
)

let diagnostics = DiagnosticsEngine(handlers: [doctor])
let graphRootInput = PackageGraphRootInput(packages: [pkgpath])

workspace.resolve(root: graphRootInput, diagnostics: diagnostics)
guard !diagnostics.hasErrors else { exit(2) }

let graph = workspace.loadPackageGraph(root: graphRootInput, diagnostics: diagnostics)
guard !diagnostics.hasErrors else { exit(3) }

let rootPackages = graph.rootPackages.flatMap{ $0.dependencies }
let rootTargets = rootPackages.libraryTargets
let output = try modelize(to: Path(absolutePath: depsPath), packages: rootPackages, targets: rootTargets)

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
encoder.userInfo[.relativePath] = Path(absolutePath: depsPath)
let data = try encoder.encode(output)
let outpath = pkgpath.appending(component: "Dependencies.json").pathString
try data.write(to: URL(fileURLWithPath: outpath))

print(String(data: data, encoding: .utf8)!)
