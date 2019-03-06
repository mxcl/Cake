import Version
import Cocoa
import Base
import Path

//TODO we're hiding errors when Xcode objects cannot be made etc.

public enum RunStatus {
    case notRunning
    case running([Version])
}

public enum XcodeError: Error {
    case unknownVersion
    case appleScriptBridgeFailed
}

public protocol XcodeObserverDelegate: class {
    func xcode(runStatus: RunStatus)
    func xcode(workspaceDiff: Diff<Path>)
    func xcode(error: Error)
}

public class XcodeObserver: NSObject {

    public override init() {
        runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dt.Xcode")
        openWorkspaces = Set(runningApplications.compactMap(\.xcode).flatMap(\.workspaces))

        super.init()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onApplicationDidLaunch), name: NSWorkspace.didLaunchApplicationNotification, object: nil)

        let rawNames = [
             "com.apple.dt.Xcode.notification.IDEActivityReportDistributedDidCompleteNotification",
             "com.apple.dt.Xcode.notification.IDEEditorCoordinatorDistributedDidCompleteNotification",
             "IDESchemeRunDestinationsDidUpdateNotification",
             "com.apple.sharedfilelist.change"  //happens when workspaces close for some reason
        ]

        for rawName in rawNames {
            let name = Notification.Name(rawName)
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(onDistributedNotification), name: name, object: nil)
        }
    }

    public private(set) var openWorkspaces: Set<Path> {
        didSet {
            if let diff = Diff(old: oldValue, new: openWorkspaces) {
                delegate?.xcode(workspaceDiff: diff)
            }
        }
    }

    public var isRunning: Bool {
        return runningApplications.first(where: { !$0.isTerminated }) != nil
    }

    var xcodes: [Xcode] {
        return runningApplications.compactMap(\.xcode)
    }

    func runStatus() throws -> RunStatus {
        if !isRunning {
            return .notRunning
        } else {
            return .running(xcodes.map{ $0.version ?? .null })
        }
    }

    public weak var delegate: XcodeObserverDelegate? {
        didSet {
            do {
                delegate?.xcode(runStatus: try runStatus())
                delegate?.xcode(workspaceDiff: Diff(added: openWorkspaces, removed: [], newValue: openWorkspaces))
            } catch {
                delegate?.xcode(error: error)
            }
        }
    }

    private var kvoRefs: [NSKeyValueObservation] = []

    private var runningApplications: [NSRunningApplication] = [] {
        didSet {
            do {
                delegate?.xcode(runStatus: try runStatus())
                kvoRefs = runningApplications.map{
                    $0.observe(\.isTerminated) { [unowned self] app, _ in
                        self.delegate?.xcode(runStatus: .notRunning)
                        self.openWorkspaces = []
                    }
                }
            } catch {
                delegate?.xcode(error: error)
                kvoRefs = []
            }
        }
    }

    @objc func onApplicationDidLaunch(_ note: Notification) {
        guard let userInfo = note.userInfo else { return }
        guard userInfo["NSApplicationBundleIdentifier"] as? String == "com.apple.dt.Xcode" else { return }

        if let app = userInfo["NSWorkspaceApplicationKey"] as? NSRunningApplication {
            runningApplications.append(app)
        }

        delegate?.xcode(workspaceDiff: Diff(added: [], removed: [], newValue: []))
    }

    @objc func onDistributedNotification(_ note: Notification) {
        //NOTE the distributed notifications we subscribe to all undocumented and coincidental
        // and thus may be removed at any given Xcode or not behave as we expect at any given
        // moment. Therefore, this code should be changed!

        openWorkspaces = Set(xcodes.flatMap(\.workspaces))
    }

    public var activeWorkspace: Path? {
        guard let xcode = xcodes.first else { return nil }
        return xcode.activeWorkspace
    }

    public var paths: [Path] {
        return runningApplications.compactMap(\.bundleURL).compactMap(Path.init)
    }
}

private extension NSRunningApplication {
    var xcode: Xcode? {
        return try? Xcode(pid: processIdentifier)
    }
}
