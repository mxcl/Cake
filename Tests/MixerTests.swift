import Modelizer
import XCTest
import Path

class MixerTests: XCTestCase {
    var tmpdir: TemporaryDirectory!

    override func setUp() {
        tmpdir = try! TemporaryDirectory()
        FileManager.default.changeCurrentDirectoryPath(tmpdir.string)
    }

    override func tearDown() {
        tmpdir = nil
        FileManager.default.changeCurrentDirectoryPath("/")
    }

    func testCanFindBinary() {
        XCTAssertTrue(Path.mixer.isExecutable)
        XCTAssertTrue(Path.mixer.isFile)
    }

    func testOutput() throws {
        let deps = try tmpdir.path.join(".cake").mkdir()
        try """
            // swift-tools-version:4.2
            import PackageDescription

            let pkg = Package(name: "Dependencies", dependencies: [
                .package(url: "https://github.com/Weebly/OrderedSet.git", .exact("3.1.0")),
            ])
            """.write(to: deps/"Package.swift")

        let task = Process()
        task.launchPath = Path.mixer.string
        task.arguments = [tmpdir.string]
        let stdout = try task.runSync(tee: true).stdout

        let decoder = JSONDecoder()
        decoder.userInfo[.relativePath] = tmpdir.path/"Dependencies"
        let output = try decoder.decode(DependenciesJSON.self, from: stdout.data)

        XCTAssertEqual(output.imports, ["OrderedSet"])
        XCTAssertEqual(output.modules.count, 1)
        XCTAssertEqual(output.modules.first?.name, "OrderedSet")
        XCTAssertEqual(output.modules.first?.files.count, 1)
        XCTAssertEqual(output.modules.first?.dependencies.count, 0)
        XCTAssertEqual(output.modules.first?.path, tmpdir.path/"Dependencies")
    }
}

private extension Path {
    static var mixer: Path {
        return Bundle(for: MixerTests.self).path.parent/"Cake.app/Contents/MacOS/mixer"
    }
}
