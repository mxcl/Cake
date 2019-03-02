@testable import Modelizer
import XCTest
import Base
import Path

class ModelizerTests: XCTestCase {
    func testOneModule() throws {
        try createFixture("a.swift") { root, paths in
            let modules = try modelize(root: root)
            XCTAssertEqual(modules.count, 1)
            XCTAssertEqual(modules.flattened.count, 1)
            XCTAssertEqual(modules.bases, modules)
            let base = try modules.get("Base")
            XCTAssertEqual(base.relativeFiles, ["a.swift"])
            XCTAssertEqual(base.dependencies.count, 0)
        }
    }

    func testOneModuleButGapped() throws {
        try createFixture("a/b/c.swift") { root, paths in
            let modules = try modelize(root: root)
            XCTAssertEqual(modules.count, 1)
            XCTAssertEqual(modules.flattened.count, 1)
            let b = try modules.get("b")
            XCTAssertEqual(b.path, root/"a/b")
            XCTAssertEqual(b.relativeFiles, ["c.swift"])
            XCTAssertEqual(b.dependencies.count, 0)
        }
    }

    func testOneModuleButGappedWithRedHerrings() throws {
        try createFixture("gap/b/c.swift", "d/e/foo", "a/f/goo") { root, paths in
            let modules = try modelize(root: root)
            XCTAssertEqual(modules.count, 1)
            XCTAssertEqual(modules.flattened.count, 1)
            let b = try modules.get("b")
            XCTAssertEqual(b.relativeFiles, ["c.swift"])
            XCTAssertEqual(b.dependencies.count, 0)
        }
    }

    func testTwoNestedModules() throws {
        try createFixture("a.swift", "b/b.swift") { root, paths in
            let modules = try modelize(root: root)
            XCTAssertEqual(modules.count, 1)
            XCTAssertEqual(modules.flattened.count, 2)
            let b = try modules.get("b")
            XCTAssertEqual(b.path, root/"b")
            XCTAssertEqual(b.relativeFiles, ["b.swift"])
            XCTAssertEqual(b.dependencies.count, 1)
            let base = try b.dep("Base")
            XCTAssertEqual(base.path, root)
            XCTAssertEqual(base.relativeFiles, ["a.swift"])
            XCTAssertEqual(base.dependencies.count, 0)
        }
    }

    func testTwoNestedModulesWithAGap() throws {
        try createFixture("a.swift", "gap/c/c.swift") { root, paths in
            let modules = try modelize(root: root)
            XCTAssertEqual(modules.count, 1)
            XCTAssertEqual(modules.flattened.count, 2)
            let c = try modules.get("c")
            XCTAssertEqual(c.dependencies.count, 1)
            let base = try c.dep("Base")
            XCTAssertEqual(base.relativeFiles, ["a.swift"])
        }
    }

    func testThreeNestedModulesWithAGap_IgnoredRule() throws {
        //NOTE disabled for now, maybe this isn’t a good idea?

        // describe: c should not depend on b

        try createFixture("a.swift", "gap/c/c.swift", "b/b.swift") { root, paths in
            let modules = try modelize(root: root)
            XCTAssertEqual(modules.count, 2)
            XCTAssertEqual(modules.flattened.count, 3)
            let c = try modules.get("c")
            XCTAssertEqual(c.dependencies.count, 1)
            let b = try modules.get("b")
            XCTAssertEqual(b.dependencies.count, 1)
            let base1 = try c.dep("Base")
            let base2 = try b.dep("Base")
            XCTAssertEqual(base1.relativeFiles, ["a.swift"])
            XCTAssertEqual(base2.relativeFiles, base1.relativeFiles)
            XCTAssertEqual(base1, base2)
        }
    }


    func testRegression1() throws {
        try createFixture("a/a.swift", "b/b.swift", "b/c/d/d.swift") { root, paths in
            let modules = try modelize(root: root)
            XCTAssertEqual(modules.count, 2)
            XCTAssertEqual(modules.flattened.count, 3)
            let d = try modules.get("d")
            let a = try modules.get("a")
            let b = try d.dep("b")
            XCTAssertEqual(d.dependencies, [a, b])
        }
    }

    func testRegression2() throws {
        try createFixture("a/a.swift", "b/b.swift", "b/c/c.swift", "b/d/d.swift", "b/d/e/e.swift") { root, paths in
            let modules = try modelize(root: root)
            XCTAssertEqual(modules.count, 3)
            let a = try modules.get("a")
            XCTAssertEqual(a.relativeFiles, ["a.swift"])
            XCTAssertEqual(a.path, root/"a")
            let e = try modules.get("e")
            XCTAssertEqual(e.relativeFiles, ["e.swift"])
            XCTAssertEqual(e.path, root/"b/d/e")
            let c = try modules.get("c")
            XCTAssertEqual(c.relativeFiles, ["c.swift"])
            XCTAssertEqual(c.path, root/"b/c")
            let b = try c.dep("b")
            let d = try e.dep("d")
            XCTAssertEqual(d.dependencies, [a, b])
            XCTAssertEqual(c.dependencies, [a, b])
        }
    }

    func testThreeNestedModules() throws {
        try createFixture("a.swift", "b/b.swift", "b/c/c.swift") { root, paths in
            let modules = try modelize(root: root)
            XCTAssertEqual(modules.count, 1)
            XCTAssertEqual(modules.flattened.count, 3)
            let c = try modules.get("c")
            XCTAssertEqual(c.path, root/"b/c")
            XCTAssertEqual(c.relativeFiles, ["c.swift"])
            XCTAssertEqual(c.dependencies.count, 1)
            let b = try c.dep("b")
            XCTAssertEqual(b.path, root/"b")
            XCTAssertEqual(b.relativeFiles, ["b.swift"])
            XCTAssertEqual(b.dependencies.count, 1)
            let base = try b.dep("Base")
            XCTAssertEqual(base.path, root)
            XCTAssertEqual(base.relativeFiles, ["a.swift"])
            XCTAssertEqual(base.dependencies.count, 0)
        }
    }

    func testFiveModulesSplitOverTwoLevels() throws {
        try createFixture("a.swift", "b/b.swift", "c/c.swift", "b/d/d.swift") { root, paths in
            let modules = try modelize(root: root)
            XCTAssertEqual(modules.count, 2)
            XCTAssertEqual(modules.flattened.count, 4)

            let c = try modules.get("c")
            XCTAssertEqual(c.path, root/"c")
            XCTAssertEqual(c.relativeFiles, ["c.swift"])
            XCTAssertEqual(c.dependencies.count, 1)
            let base = try c.dep("Base")
            XCTAssertEqual(base.path, root)
            XCTAssertEqual(base.relativeFiles, ["a.swift"])
            XCTAssertEqual(base.dependencies.count, 0)
            let d = try modules.get("d")
            XCTAssertEqual(d.path, root/"b/d")
            XCTAssertEqual(d.relativeFiles, ["d.swift"])
            XCTAssertEqual(d.dependencies.count, 2)
            let b = try d.dep("b")
            XCTAssertEqual(b.path, root/"b")
            XCTAssertEqual(b.relativeFiles, ["b.swift"])

            XCTAssertTrue(d.dependencies.contains(c))
            XCTAssertTrue(d.dependencies.contains(b))
        }
    }

    func testOneModuleWithNestedRedHerring() throws {
        try createFixture("a.swift", "b/b.foo") { root, paths in
            var modules: [Module]!
            XCTAssertNoThrow(modules = try modelize(root: root))
            XCTAssertEqual(modules.count, 1)
            XCTAssertEqual(modules.flattened.count, 1)
            let base = try modules.get("Base")
            XCTAssertEqual(base.path, root)
            XCTAssertEqual(base.relativeFiles, ["a.swift"])
            XCTAssertEqual(base.dependencies.count, 0)

        }
    }

    func testThrowsIfNoModules() throws {
        for fixture in [["foo"], ["a/b/c/d/foo"], ["a/b/c/d/foo", "e/f/goo"]] {
            try createFixture(files: fixture) { root, paths in
                XCTAssertThrowsError(try modelize(root: root)) { error in
                    do {
                        throw error
                    } catch ModelizerError.noSwiftFiles(let path) {
                        XCTAssertEqual(root, path)
                    } catch {
                        XCTFail()
                    }
                }
            }
        }
    }
}

private enum E: LocalizedError {
    case moduleNotFound(desired: String, searching: [String])
    case dependencyNotFound(desired: String, module: String)

    var errorDescription: String? {
        switch self {
        case .moduleNotFound(let desired, let searching):
            return "Could not find `\(desired)` in \(searching)"
        case .dependencyNotFound(let desired, let module):
            return "Dependency `\(desired)` not found in `\(module)`"
        }
    }
}

private extension Array where Element == Module {
    var mapped: [String: Module] {
        return Dictionary(uniqueKeysWithValues: map{ ($0.name, $0) })
    }

    func get(_ name: String) throws -> Module {
        guard let module = first(where: { $0.name == name}) else {
            throw E.moduleNotFound(desired: name, searching: map(\.name))
        }
        return module
    }
}

private extension Module {
    func dep(_ name: String) throws -> Module {
        do {
            return try dependencies.get(name)
        } catch E.moduleNotFound(let name, _) {
            throw E.dependencyNotFound(desired: name, module: self.name)
        }
    }
}

private func modelize(root: Path) throws -> [Module] {
    return try modelize(root: root, basename: "Base")
}
