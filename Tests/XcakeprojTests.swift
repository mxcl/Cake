@testable import XcakeProject
import Foundation
import Modelizer
import XCTest
import Base

class XcakeprojTests: XCTestCase {
    func test() throws {

        struct Output: Decodable {
            let project: Project
            struct Project: Decodable {
                let targets: [String]
            }
        }

        let basename = "Floobles"

        try createFixture("Sources/Model/a.swift", "Sources/Model/b/b.swift", "Sources/Model/b/c/c.swift", "Sources/Model/b/d/d.swift") { root, paths in
            var opts = Options()
            opts.baseModuleName = basename
            try XcakeProject(prefix: root, platforms: [.macOS ~> 10.14], swift: .v4_2, options: opts).write()

            let task = Process()
            task.currentDirectoryPath = root.join(".cake").string
            task.launchPath = "/usr/bin/xcodebuild"
            task.arguments = ["-list", "-json"]
            let data = try task.runSync().stdout.data
            let json = try JSONDecoder().decode(Output.self, from: data)
            XCTAssertEqual(Set(json.project.targets), ["Batter·\(basename)", "Batter·b", "Batter·c", "Batter·d", "Cakefile", "Cakefile·Completion", "Batter", "Cake"])

            // or cannot delete fixture dir and test fails
            for entry in try root.join(".cake").ls() where entry.kind == .file && entry.path.extension == "swift" {
                try entry.path.unlock()
            }
        }
    }
}
