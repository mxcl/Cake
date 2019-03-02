import CakefileDescription
import Foundation
import Version
import Path

public enum E: Error {
    case noCakefile
    case executionFailed(String, args: [String], exit: Int32)
    case toolkit(required: Range<Version>, available: Version)
}

public typealias ProcessorError = E

struct Cakefile {
    let path: Path
    let mtime: Date?
    private let dump: CakefileDump

    var options: Options { return dump.options }
    var dependencies: [PackageSpecification] { return dump.dependencies }
    var platforms: Set<PlatformSpecification> { return dump.platforms }

    var cakeRequirement: Range<Version>? {
        if case .version(.range(let v))? = dump.cake {
            return v
        } else {
            return nil
        }
    }

    init(path: Path, L: Path, I: Path) throws {
        guard path.isFile else {
            throw E.noCakefile
        }
        self.path = path
        self.dump = try parse(cakefile: path, L: L, I: I)
        self.mtime = path.mtime
    }
}

public struct CakefileParseError: LocalizedError {
    public let errorDescription: String?
}

private func parse(cakefile path: Path, L: Path, I: Path) throws -> CakefileDump {
    //TODO use stdin to `swift -`
    
    var contents = try String(contentsOf: path)
    contents += """

        import Foundation
        let dump = CakefileDump(platforms: platforms, dependencies: dependencies, options: options)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(dump)
        let str = String(data: data, encoding: .utf8)!
        print(str)
        """

    let (stdout, stderr) = try Path.mktemp { tmpdir -> (Process.Output, Process.Output) in
        let tmpfile = tmpdir/"Cakefile.swift"
        try contents.write(to: tmpfile)
        let tmppath = tmpdir.join("Cakefile.swift").string
        let task = Process()
        task.launchPath = "/usr/bin/swift"
        task.arguments = [
            "-module-name", "CakefileScript",
            "-L", L.string,
            "-I", I.string,
            "-lCakefile",
            tmppath]
        do {
            return try task.runSync(tee: true)
        } catch let error as Process.ExecutionError {
            guard let str = error.stderr.string else { throw error }
            let mangledError: [Substring] = str.split(separator: "\n").map { line in
                if line.hasPrefix(tmpfile.string) {
                    return path.string + line.dropFirst(tmpfile.string.count)
                } else {
                    return line
                }
            }
            throw CakefileParseError(errorDescription: mangledError.joined(separator: "\n"))
        }
    }

    if !stderr.data.isEmpty, let string = stderr.string {
        fputs(string, Darwin.stderr)
    }

    try stdout.data.write(to: path.parent/".cake/Cakefile.json")

    return try JSONDecoder().decode(CakefileDump.self, from: stdout.data)
}
