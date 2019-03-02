import Foundation
import Path

public func modelize(root: Path, basename: String) throws -> [Module] {
    let modelizer = Modelizer(root: root, basename: basename)
    return try modelizer.go()
}

public enum ModelizerError: Error {
    case noSwiftFiles(Path)
}

private class Modelizer {
    let root: Path
    var tips: [Module] = []
    let basename: String

    init(root: Path, basename: String) {
        self.root = root
        self.basename = basename
    }

    func go() throws -> [Module] {
        let base = try Module(directory: root, name: basename)
        let deps = base.map{ [$0] } ?? []

        try descend(into: ModuleOrPath(path: root, module: base), deps: deps)

        if tips.isEmpty {
            throw ModelizerError.noSwiftFiles(root)
        }

        return tips
    }

    @discardableResult
    private func descend(into: ModuleOrPath, deps: [Module]) throws -> Bool {
        let descendables = try into.path.ls().directories.map {
            ModuleOrPath(path: $0, module: try Module(directory: $0, deps: deps))
        }
        var consumers = descendables.compactMap(\.module)

        // if no descendent directories are modules
        // we push the undelying deps forward instead
        if consumers.isEmpty {
            consumers = deps
        }

        var validDescendents = false
        for descendable in descendables {
            if try descend(into: descendable, deps: consumers) {
                validDescendents = true
            }
        }

        if let module = into.module {
            if !module.files.isEmpty {
                if !validDescendents {
                    tips.append(module)
                }
                return true
            } else {
                return validDescendents
            }
        } else {
            return validDescendents
        }
    }
}

private enum ModuleOrPath {
    case path(Path)
    case module(Module)

    var path: Path {
        switch self {
        case .path(let path): return path
        case .module(let module): return module.path
        }
    }

    var module: Module? {
        switch self {
        case .module(let module): return module
        case .path: return nil
        }
    }

    init(path: Path, module: Module?) {
        if let module = module {
            assert(path == module.path)
            self = .module(module)
        } else {
            self = .path(path)
        }
    }
}

private extension Module {
    convenience init?(directory: Path, name: String? = nil, deps: [Module] = []) throws {
        let files = try directory.ls().files(withExtension: "swift").sorted()
        if files.isEmpty {
            return nil
        }
        self.init(
            name: name ?? directory.basename(),
            directory: directory,
            dependencies: deps,
            files: files)
    }
}
