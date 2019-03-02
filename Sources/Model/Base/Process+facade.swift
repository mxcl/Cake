import Foundation

public extension Process {

    class Output {
        public let data: Data
        public lazy var string = { [unowned self] () -> String? in
            guard var str = String(data: self.data, encoding: .utf8) else { return nil }
            str = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return str.isEmpty ? nil : str
        }()

        fileprivate init(_ data: Data) {
            self.data = data
        }
    }

    struct ExecutionError: Error {
        public let stdout: Output
        public let stderr: Output
        public let status: Int32
        public let arg0: String
        public let args: [String]
    }

    func runSync(tee: Bool = false) throws -> (stdout: Output, stderr: Output) {
        let q = DispatchQueue(label: "output-queue")

        var out = Data()
        var err = Data()

        let outpipe = Pipe()
        standardOutput = outpipe

        let errpipe = Pipe()
        standardError = errpipe

        outpipe.fileHandleForReading.readabilityHandler = { handler in
            q.async {
                out.append(handler.availableData)
            }
        }

        errpipe.fileHandleForReading.readabilityHandler = { handler in
            q.async {
                let data = handler.availableData
                err.append(data)
                if tee, let str = String(data: data, encoding: .utf8) {
                    Darwin.fputs(str, stderr)
                }
            }
        }

        try run()
        waitUntilExit()

        outpipe.fileHandleForReading.readabilityHandler = nil
        errpipe.fileHandleForReading.readabilityHandler = nil

        return try q.sync {
            guard terminationStatus == 0, terminationReason == .exit else {
                throw ExecutionError(stdout: .init(out), stderr: .init(err), status: terminationStatus, arg0: launchPath!, args: arguments ?? [])
            }
            return (stdout: Output(out), stderr: Output(err))
        }
    }

    static func system(_ arg0: String, args: String...) throws {
        let task = Process()
        task.launchPath = arg0
        task.arguments = args
        try task.run()
        task.waitUntilExit()

        guard task.terminationReason == .exit, task.terminationStatus == 0 else {
            let output = Output(Data())
            throw ExecutionError(stdout: output, stderr: output, status: task.terminationStatus, arg0: arg0, args: args)
        }
    }
}

extension Process.Output: CustomStringConvertible {
    public var description: String {
        return string ?? ""
    }
}
