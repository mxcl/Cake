import struct Modelizer.DependenciesJSON
import CakefileDescription
import Foundation
import Path

class Dependencies {
    let cakefileRepresentation: [PackageSpecification]
    let json: DependenciesJSON

    init(deps: [PackageSpecification], prefix: Path, bindir: Path, libpmdir: Path, DEVELOPER_DIR: Path) throws {
        cakefileRepresentation = deps

        guard !deps.isEmpty else {
            // no need to do all the heavy SwiftPM lifting
            json = .init()
            return
        }

        var manifest = """
        // swift-tools-version:5.0
        import PackageDescription

        let pkg = Package(name: "Dependencies", dependencies: [

        """

        for dep in deps {
            manifest += "    \(dep),\n"
        }
        manifest += "])\n"

        try manifest.write(to: prefix/".cake/Package.swift")

        let decoder = JSONDecoder()
        decoder.userInfo[.relativePath] = prefix/"Dependencies"

        let task = Process()
        task.launchPath = bindir.join("mixer").string
        task.arguments = [prefix.string, libpmdir.string]
        task.environment = ProcessInfo.processInfo.environment
        task.environment!["DEVELOPER_DIR"] = DEVELOPER_DIR.string
        let (stdout, _) = try task.runSync(tee: true)

        json = try decoder.decode(DependenciesJSON.self, from: stdout.data)
    }
}

extension PackageSpecification: CustomStringConvertible {
    public var description: String {
        switch constraint {
        case .version(.range(let range)):
            let v1 = range.lowerBound
            let v2 = range.upperBound
            if v2.major == v1.major + 1, v2.minor == 0, v2.patch == 0 {
                return """
                .package(url: "\(url)", from: "\(v1)")
                """
            } else {
                return """
                .package(url: "\(url)", Version(\(v1.major),\(v1.minor),\(v1.patch))..<Version(\(v2.major),\(v2.minor),\(v2.patch)))
                """
            }
        case .version(.exact(let v)):
            return """
            .package(url: "\(url)", .exact(Version(\(v.major),\(v.minor),\(v.patch)))
            """
        case .ref(.branch(let branch)), .ref(.tag(let branch)):
            return """
            .package(url: "\(url)", .branch("\(branch)"))
            """
        case .ref(.revision(let SHA)):
            return """
            .package(url: "\(url)", .revision("\(SHA)"))
            """
        }
    }
}
