import Path

public extension Path {
    func inreplace(_ target: String, with replacement: String) throws {
        //TODO could replace more efficiently if we did it with FileHandle

        try StreamReader(path: self).map {
            $0.replacingOccurrences(of: target, with: replacement)
        }.joined(separator: "\n").write(to: self, atomically: true)
    }
}
