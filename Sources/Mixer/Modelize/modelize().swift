import struct Foundation.URLComponents
import struct Foundation.URL
import struct Basic.AbsolutePath
import PackageModel
import Base
import Path

/// returns topological sorted flat-list of module hierarchy
/// also copies sources into visible folders TODO this breaks the responsibility of this method
public func modelize(to root: Path, packages: [ResolvedPackage], targets: [ResolvedTarget]) throws -> DependenciesJSON {

    var map = [ResolvedTarget: (SwiftVersion, ResolvedPackage)]()

    do {
        var set = Set<ResolvedPackage>()

        func recursePackage(_ package: ResolvedPackage) {
            guard !set.contains(package) else { return }
            set.insert(package)

            let ver = package.swiftVersions.max() ?? SwiftVersion(package.manifest.manifestVersion)
            for target in package.targets {
                map[target] = (ver, package)
            }
            package.dependencies.forEach(recursePackage)
        }
        packages.forEach(recursePackage)
    }

    var roots = Set<Path>()
    var scaffolded = [ResolvedPackage: [ResolvedTarget: (Path, [Path])]]()

    func scaffold(package: ResolvedPackage) throws -> [ResolvedTarget: (Path, [Path])] {
        if let sources = scaffolded[package] {
            return sources
        }

        var packageDirname = package.checkoutBasename
        if let version = package.manifest.version {
            packageDirname += "-\(version)"
        }

        let targets = package.libraryTargets
        let map = try targets.map { target -> (ResolvedTarget, (Path, [Path])) in
            let srcroot = Path(absolutePath: target.sources.root)

            let dir: Path
            if targets.count > 1 {
                dir = root/packageDirname/target.name
            } else if let sourceFile = targets.first?.sources.singleFile {
                let sourceFile = try sourceFile.copy(to: root.mkdir(.p).join("\(packageDirname).swift"), overwrite: true)
                roots.insert(sourceFile)
                return (target, (root, [sourceFile]))
            } else {
                dir = root/packageDirname
            }

            let sources = try target.sources.paths.map { sourceFile -> Path in
                let sourceFile = Path(absolutePath: sourceFile)
                let relativeDir = sourceFile.parent.relative(to: srcroot)
                let into = try dir.join(relativeDir).mkdir(.p)
                return try sourceFile.copy(into: into, overwrite: true)
            }

            if !sources.isEmpty {
                roots.insert(dir)
            }

            return (target, (dir, sources))
        }
        let dict = Dictionary(uniqueKeysWithValues: map)
        scaffolded[package] = dict
        return dict
    }

    var modules = [ResolvedTarget: Module]()

    func recurseTarget(with target: ResolvedTarget) throws -> Module? {
        if let module = modules[target] {
            return module
        }
        guard target.type == .library else {
            return nil
        }
        guard let (version, package) = map[target] else {
            error("missing target to (version, pkg) entry for \(target)")
        }
        guard let (srcroot, sources) = try scaffold(package: package)[target] else {
            error("missing scaffolding for \(package)")
        }
        let deps = target.dependencies.flatMap { resolvedDependency -> [ResolvedTarget] in
            switch resolvedDependency {
            case .product(let product):
                return product.targets  // external dependencies
            case .target(let target):
                return [target]         // internal to the package these targets came from
            }
        }
        let module = Module(
            name: target.name,
            directory: srcroot,
            dependencies: try deps.compactMap(recurseTarget),
            files: sources,
            swift: version
        )
        modules[target] = module
        return module
    }

    let sortedModules = try targets.compactMap(recurseTarget).flattened

    if sortedModules.isEmpty {
        // if nothing left then delete entire Dependencies directory (let’s be clean)
        try root.delete()
    } else {
        // delete everything else ∵ old versions
        //TODO do better, only delete stuff that was here before (read Dependencies.json)
        for entry in try root.ls() where !roots.contains(entry.path) {
            try entry.path.delete()
        }
    }

    let pkgs = scaffolded.map { foo in
        DependenciesJSON.Package(
            name: foo.key.qualifiedName,
            path: Path(absolutePath: foo.key.path),
            version: foo.key.manifest.version,
            moduleNames: foo.value.keys.map{ modules[$0]!.name })
    }
    let imports = targets.map{ $0.c99name }

    return DependenciesJSON(modules: sortedModules, imports: imports, packages: pkgs)
}

private extension ResolvedPackage {
    var swiftVersions: [SwiftVersion] {
        return manifest.swiftLanguageVersions?.compactMap(SwiftVersion.init) ?? []
    }

    var qualifiedName: String {
        if let (user, repo) = URLComponents(string: manifest.url)?.githubPair {
            return "\(user)/\(repo)"
        } else {
            return name
        }
    }

    var checkoutBasename: String {
        let slash = "∕" // special unicode value that is _not_ the UNIX filesystem slash

        guard let cc = URLComponents(string: manifest.url) else {
            fatalError() //TODO
        }
        if let (user, repo) = cc.githubPair {
            return "\(user)\(slash)\(repo)"
        }

        guard let host = cc.host else {
            fatalError() //TODO
        }

        var components = cc.path.split(separator: "/")
        if let last = components.last, last.hasSuffix(".git") {
            components[components.endIndex - 1] = last.dropLast(4)
        }

        func sanitize<S>(_ s: S) -> String where S: StringProtocol {
            return s.replacingOccurrences(of: ":", with: "%3A")
        }

        let path = components.map(sanitize).joined(separator: slash)
        return sanitize(host) + slash + path
    }
}

public extension Path {
    init(absolutePath path: AbsolutePath) {
        self = Path.root / path.pathString
    }
}

private extension SwiftVersion {
    init?(spmValue: SwiftLanguageVersion) {
        if spmValue >= .v5 {
            self = .v5
        } else if spmValue >= .v4_2 {
            self = .v4_2
        } else if spmValue >= .v4 {
            self = .v4
        } else {
            return nil
        }
    }

    init(_ manifestVersion: ManifestVersion) {
        switch manifestVersion {
        case .v4:
            self = .v4
        case .v4_2:
            self = .v4_2
        case .v5:
            self = .v5
        }
    }
}

private extension URLComponents {
    var githubPair: (String.SubSequence, String.SubSequence)? {
        let cc = self
        guard let host = cc.host, host.hasSuffix("github.com") else { return nil }
        let components = cc.path.split(separator: "/")
        guard components.count == 2 else { return nil }
        let owner = components[0]
        var repo = components[1]
        if repo.hasSuffix(".git") {
            repo = repo.dropLast(4)
        }
        return (owner, repo)
    }
}

private extension Sources {
    var singleFile: Path? {
        guard relativePaths.count == 1 else { return nil }
        return Path(absolutePath: root.appending(relativePaths[0]))
    }
}

private extension Dictionary {
    func mapPairs<OutKey: Hashable, OutValue>(_ transform: (Element) throws -> (OutKey, OutValue)) rethrows -> [OutKey: OutValue] {
        return Dictionary<OutKey, OutValue>(uniqueKeysWithValues: try map(transform))
    }
}
