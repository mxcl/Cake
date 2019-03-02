import ScriptingBridge
import Foundation
import Version
import Base
import Path

// NOTE if this class is NOT in this file, the AppleScript stops working… WTF?
public class Xcode {
    private let bridge: XcodeApplication

    public init(pid: pid_t) throws {
        guard let b = SBApplication(processIdentifier: pid) else {
            throw XcodeError.appleScriptBridgeFailed
        }
        bridge = b
    }

    /// only works if Xcode is *still* running
    public var version: Version? {
        guard bridge.isRunning else {
            return nil
        }
        return bridge.version.flatMap(Version.init(tolerant:))
    }

    public var isRunning: Bool {
        return bridge.isRunning
    }

    public var derivedData: Path {
        var `default`: Path { return Path.home/"Library/Developer/Xcode/DerivedData" }
        guard let defaults = UserDefaults(suiteName: "com.apple.dt.Xcode.plist") else {
            return `default`
        }
        if let customPath = defaults.string(forKey: "IDECustomDerivedDataLocation") {
            return Path.root/customPath
        } else {
            return `default`
        }
    }

    public func quit() throws {
        guard bridge.isRunning else { return }
        bridge.quitSaving?(.ask)
        if let err = bridge.lastError() {
            throw err
        }
    }

    public func open(documents: [Path] = []) {
        bridge.activate()
        _ = bridge.open?(documents.map(\.string))
    }

    public var documents: [Path] {
        guard bridge.isRunning else {
            // ^^ otherwise causes Xcode to open due to use of scripting bridge
            return []
        }
        // get() or risks crashing since array is “live”
        guard let docs = bridge.workspaceDocuments?().get() else {
            return []
        }
        return docs.compactMap {
            ($0 as? XcodeWorkspaceDocument)?.path
        }.compactMap(Path.init)
    }

    var workspaces: [Path] {
        return documents.filter {
            $0.extension == "xcodeproj"
        }
    }

    public var activeWorkspace: Path? {
        guard let doc = bridge.activeWorkspaceDocument else { return nil }
        return doc.path.flatMap(Path.init)
    }
}


//MARK: Generated
//NOTE: using sdef, sdp and https://github.com/tingraldi/SwiftScripting

@objc protocol SBObjectProtocol: NSObjectProtocol {
    func get() -> Any!
    func lastError() -> Error?
}

@objc protocol SBApplicationProtocol: SBObjectProtocol {
    func activate()
    var delegate: SBApplicationDelegate! { get set }
    var isRunning: Bool { get }
}

// MARK: XcodeSaveOptions
@objc enum XcodeSaveOptions : AEKeyword {
    case yes = 0x79657320 /* 'yes ' */
    case no = 0x6e6f2020 /* 'no  ' */
    case ask = 0x61736b20 /* 'ask ' */
}

// MARK: XcodeSchemeActionResultStatus
@objc enum XcodeSchemeActionResultStatus : AEKeyword {
    case notYetStarted = 0x7372736e /* 'srsn' */
    case running = 0x73727372 /* 'srsr' */
    case cancelled = 0x73727363 /* 'srsc' */
    case failed = 0x73727366 /* 'srsf' */
    case errorOccurred = 0x73727365 /* 'srse' */
    case succeeded = 0x73727373 /* 'srss' */
}

// MARK: XcodeGenericMethods
@objc protocol XcodeGenericMethods {
    @objc optional func closeSaving(_ saving: XcodeSaveOptions, savingIn: Any!) // Close a document.
    @objc optional func delete() // Delete an object.
    @objc optional func moveTo(_ to: Any!) // Move an object to a new location.
    @objc optional func build() -> XcodeSchemeActionResult // Invoke the "build" scheme action. This command should be sent to a workspace document. The build will be performed using the workspace document's current active scheme and active run destination. This command does not wait for the action to complete; its progress can be tracked with the returned scheme action result.
    @objc optional func clean() -> XcodeSchemeActionResult // Invoke the "clean" scheme action. This command should be sent to a workspace document. The clean will be performed using the workspace document's current active scheme and active run destination. This command does not wait for the action to complete; its progress can be tracked with the returned scheme action result.
    @objc optional func stop() // Stop the active scheme action, if one is running. This command should be sent to a workspace document. This command does not wait for the action to stop.
    @objc optional func runWithCommandLineArguments(_ withCommandLineArguments: Any!, withEnvironmentVariables: Any!) -> XcodeSchemeActionResult // Invoke the "run" scheme action. This command should be sent to a workspace document. The run action will be performed using the workspace document's current active scheme and active run destination. This command does not wait for the action to complete; its progress can be tracked with the returned scheme action result.
    @objc optional func testWithCommandLineArguments(_ withCommandLineArguments: Any!, withEnvironmentVariables: Any!) -> XcodeSchemeActionResult // Invoke the "test" scheme action. This command should be sent to a workspace document. The test action will be performed using the workspace document's current active scheme and active run destination. This command does not wait for the action to complete; its progress can be tracked with the returned scheme action result.
}

// MARK: XcodeApplication
@objc protocol XcodeApplication: SBApplicationProtocol {
    @objc optional func documents() -> SBElementArray
    @objc optional func windows() -> SBElementArray
    @objc optional var name: Int { get } // The name of the application.
    @objc optional var frontmost: Int { get } // Is this the active application?
    @objc optional var version: String { get } // The version number of the application.
    @objc optional func `open`(_ x: Any!) -> Any // Open a document.
    @objc optional func quitSaving(_ saving: XcodeSaveOptions) // Quit the application.
    @objc optional func exists(_ x: Any!) // Verify that an object exists.
    @objc optional func fileDocuments() -> SBElementArray
    @objc optional func sourceDocuments() -> SBElementArray
    @objc optional func workspaceDocuments() -> SBElementArray
    @objc optional var activeWorkspaceDocument: XcodeWorkspaceDocument { get } // The active workspace document in Xcode.
    @objc optional func setActiveWorkspaceDocument(_ activeWorkspaceDocument: XcodeWorkspaceDocument!) // The active workspace document in Xcode.
}
extension SBApplication: XcodeApplication {}

// MARK: XcodeDocument
@objc protocol XcodeDocument: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: Int { get } // Its name.
    @objc optional var modified: Int { get } // Has it been modified since the last save?
    @objc optional var file: Int { get } // Its location on disk, if it has one.
    @objc optional var path: String { get } // The document's path.
    @objc optional func setPath(_ path: Int) // The document's path.
}
extension SBObject: XcodeDocument {}

// MARK: XcodeWindow
@objc protocol XcodeWindow: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: Int { get } // The title of the window.
    @objc optional func id() // The unique identifier of the window.
    @objc optional var index: Int { get } // The index of the window, ordered front to back.
    @objc optional var bounds: Int { get } // The bounding rectangle of the window.
    @objc optional var closeable: Int { get } // Does the window have a close button?
    @objc optional var miniaturizable: Int { get } // Does the window have a minimize button?
    @objc optional var miniaturized: Int { get } // Is the window minimized right now?
    @objc optional var resizable: Int { get } // Can the window be resized?
    @objc optional var visible: Int { get } // Is the window visible right now?
    @objc optional var zoomable: Int { get } // Does the window have a zoom button?
    @objc optional var zoomed: Int { get } // Is the window zoomed right now?
    @objc optional var document: XcodeDocument { get } // The document whose contents are displayed in the window.
    @objc optional func setIndex(_ index: Int) // The index of the window, ordered front to back.
    @objc optional func setBounds(_ bounds: Int) // The bounding rectangle of the window.
    @objc optional func setMiniaturized(_ miniaturized: Int) // Is the window minimized right now?
    @objc optional func setVisible(_ visible: Int) // Is the window visible right now?
    @objc optional func setZoomed(_ zoomed: Int) // Is the window zoomed right now?
}
extension SBObject: XcodeWindow {}

// MARK: XcodeFileDocument
@objc protocol XcodeFileDocument: XcodeDocument {
}
extension SBObject: XcodeFileDocument {}

// MARK: XcodeTextDocument
@objc protocol XcodeTextDocument: XcodeFileDocument {
    @objc optional var text: Int { get } // The text of the text file referenced.
    @objc optional var notifiesWhenClosing: Int { get } // Should Xcode notify other apps when this document is closed?
    @objc optional func setText(_ text: Int) // The text of the text file referenced.
    @objc optional func setNotifiesWhenClosing(_ notifiesWhenClosing: Int) // Should Xcode notify other apps when this document is closed?
}
extension SBObject: XcodeTextDocument {}

// MARK: XcodeSourceDocument
@objc protocol XcodeSourceDocument: XcodeTextDocument {
}
extension SBObject: XcodeSourceDocument {}

// MARK: XcodeWorkspaceDocument
@objc protocol XcodeWorkspaceDocument: XcodeDocument {
    @objc optional func breakpoints() -> SBElementArray
    @objc optional func projects()
    @objc optional func schemes()
    @objc optional func runDestinations()
    @objc optional var loaded: Int { get } // Whether the workspace document has finsished loading after being opened. Messages sent to a workspace document before it has loaded will result in errors.
    @objc optional var activeScheme: XcodeScheme { get } // The workspace's scheme that will be used for scheme actions.
    @objc optional var activeRunDestination: XcodeRunDestination { get } // The workspace's run destination that will be used for scheme actions.
    @objc optional var lastSchemeActionResult: XcodeSchemeActionResult { get } // The scheme action result for the last scheme action command issued to the workspace document.
    @objc optional var file: Int { get } // The workspace document's location on disk, if it has one.
    @objc optional func setLoaded(_ loaded: Int) // Whether the workspace document has finsished loading after being opened. Messages sent to a workspace document before it has loaded will result in errors.
    @objc optional func setActiveScheme(_ activeScheme: XcodeScheme!) // The workspace's scheme that will be used for scheme actions.
    @objc optional func setActiveRunDestination(_ activeRunDestination: XcodeRunDestination!) // The workspace's run destination that will be used for scheme actions.
    @objc optional func setLastSchemeActionResult(_ lastSchemeActionResult: XcodeSchemeActionResult!) // The scheme action result for the last scheme action command issued to the workspace document.
}
extension SBObject: XcodeWorkspaceDocument {}

// MARK: XcodeSchemeActionResult
@objc protocol XcodeSchemeActionResult: SBObjectProtocol, XcodeGenericMethods {
    @objc optional func buildErrors()
    @objc optional func buildWarnings()
    @objc optional func analyzerIssues()
    @objc optional func testFailures()
    @objc optional func id() // The unique identifier for the scheme.
    @objc optional var completed: Int { get } // Whether this scheme action has completed (sucessfully or otherwise) or not.
    @objc optional var status: XcodeSchemeActionResultStatus { get } // Indicates the status of the scheme action.
    @objc optional var errorMessage: Int { get } // If the result's status is "error occurred", this will be the error message; otherwise, this will be "missing value".
    @objc optional var buildLog: Int { get } // If this scheme action performed a build, this will be the text of the build log.
    @objc optional func setStatus(_ status: XcodeSchemeActionResultStatus) // Indicates the status of the scheme action.
    @objc optional func setErrorMessage(_ errorMessage: Int) // If the result's status is "error occurred", this will be the error message; otherwise, this will be "missing value".
    @objc optional func setBuildLog(_ buildLog: Int) // If this scheme action performed a build, this will be the text of the build log.
}
extension SBObject: XcodeSchemeActionResult {}

// MARK: XcodeSchemeActionIssue
@objc protocol XcodeSchemeActionIssue: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var message: Int { get } // The text of the issue.
    @objc optional var filePath: Int { get } // The file path where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional var startingLineNumber: Int { get } // The starting line number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional var endingLineNumber: Int { get } // The ending line number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional var startingColumnNumber: Int { get } // The starting column number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional var endingColumnNumber: Int { get } // The ending column number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional func setMessage(_ message: Int) // The text of the issue.
    @objc optional func setFilePath(_ filePath: Int) // The file path where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional func setStartingLineNumber(_ startingLineNumber: Int) // The starting line number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional func setEndingLineNumber(_ endingLineNumber: Int) // The ending line number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional func setStartingColumnNumber(_ startingColumnNumber: Int) // The starting column number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
    @objc optional func setEndingColumnNumber(_ endingColumnNumber: Int) // The ending column number in the file where the issue occurred. This may be 'missing value' if the issue is not associated with a specific source file.
}
extension SBObject: XcodeSchemeActionIssue {}

// MARK: XcodeBuildError
@objc protocol XcodeBuildError: XcodeSchemeActionIssue {
}
extension SBObject: XcodeBuildError {}

// MARK: XcodeBuildWarning
@objc protocol XcodeBuildWarning: XcodeSchemeActionIssue {
}
extension SBObject: XcodeBuildWarning {}

// MARK: XcodeAnalyzerIssue
@objc protocol XcodeAnalyzerIssue: XcodeSchemeActionIssue {
}
extension SBObject: XcodeAnalyzerIssue {}

// MARK: XcodeTestFailure
@objc protocol XcodeTestFailure: XcodeSchemeActionIssue {
}
extension SBObject: XcodeTestFailure {}

// MARK: XcodeScheme
@objc protocol XcodeScheme: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: Int { get } // The name of the scheme.
    @objc optional func id() // The unique identifier for the scheme.
}
extension SBObject: XcodeScheme {}

// MARK: XcodeRunDestination
@objc protocol XcodeRunDestination: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: Int { get } // The name of the run destination, as displayed in Xcode's interface.
    @objc optional var architecture: Int { get } // The architecture for which this run destination results in execution.
    @objc optional var platform: Int { get } // The identifier of the platform which this run destination targets, such as "macosx", "iphoneos", "iphonesimulator", etc .
    @objc optional var device: XcodeDevice { get } // The physical or virtual device which this run destination targets.
    @objc optional var companionDevice: XcodeDevice { get } // If the run destination's device has a companion (e.g. a paired watch for a phone) which it will use, this is that device.
}
extension SBObject: XcodeRunDestination {}

// MARK: XcodeDevice
@objc protocol XcodeDevice: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: Int { get } // The name of the device.
    @objc optional var deviceIdentifier: Int { get } // A stable identifier for the device, as shown in Xcode's "Devices" window.
    @objc optional var operatingSystemVersion: Int { get } // The version of the operating system installed on the device which this run destination targets.
    @objc optional var deviceModel: Int { get } // The model of device (e.g. "iPad Air") which this run destination targets.
    @objc optional var generic: Int { get } // Whether this run destination is generic instead of representing a specific device. Most destinations are not generic, but a generic destination (such as "Generic iOS Device") will be available for some platforms if no physical devices are connected.
}
extension SBObject: XcodeDevice {}

// MARK: XcodeBuildConfiguration
@objc protocol XcodeBuildConfiguration: SBObjectProtocol, XcodeGenericMethods {
    @objc optional func buildSettings()
    @objc optional func resolvedBuildSettings()
    @objc optional func id() // The unique identifier for the build configuration.
    @objc optional var name: Int { get } // The name of the build configuration.
}
extension SBObject: XcodeBuildConfiguration {}

// MARK: XcodeProject
@objc protocol XcodeProject: SBObjectProtocol, XcodeGenericMethods {
    @objc optional func buildConfigurations()
    @objc optional func targets()
    @objc optional var name: Int { get } // The name of the project
    @objc optional func id() // The unique identifier for the project.
}
extension SBObject: XcodeProject {}

// MARK: XcodeBuildSetting
@objc protocol XcodeBuildSetting: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: Int { get } // The unlocalized build setting name (e.g. DSTROOT).
    @objc optional var value: Int { get } // A string value for the build setting.
    @objc optional func setName(_ name: Int) // The unlocalized build setting name (e.g. DSTROOT).
    @objc optional func setValue(_ value: Int) // A string value for the build setting.
}
extension SBObject: XcodeBuildSetting {}

// MARK: XcodeResolvedBuildSetting
@objc protocol XcodeResolvedBuildSetting: SBObjectProtocol, XcodeGenericMethods {
    @objc optional var name: Int { get } // The unlocalized build setting name (e.g. DSTROOT).
    @objc optional var value: Int { get } // A string value for the build setting.
    @objc optional func setName(_ name: Int) // The unlocalized build setting name (e.g. DSTROOT).
    @objc optional func setValue(_ value: Int) // A string value for the build setting.
}
extension SBObject: XcodeResolvedBuildSetting {}

// MARK: XcodeTarget
@objc protocol XcodeTarget: SBObjectProtocol, XcodeGenericMethods {
    @objc optional func buildConfigurations()
    @objc optional var name: Int { get } // The name of this target.
    @objc optional func id() // The unique identifier for the target.
    @objc optional var project: XcodeProject { get } // The project that contains this target
    @objc optional func setName(_ name: Int) // The name of this target.
}
extension SBObject: XcodeTarget {}


enum XcodeScripting: String {
    case analyzerIssue = "analyzer issue"
    case application = "application"
    case buildConfiguration = "build configuration"
    case buildError = "build error"
    case buildSetting = "build setting"
    case buildWarning = "build warning"
    case device = "device"
    case document = "document"
    case fileDocument = "file document"
    case project = "project"
    case resolvedBuildSetting = "resolved build setting"
    case runDestination = "run destination"
    case schemeActionIssue = "scheme action issue"
    case schemeActionResult = "scheme action result"
    case scheme = "scheme"
    case sourceDocument = "source document"
    case target = "target"
    case testFailure = "test failure"
    case textDocument = "text document"
    case window = "window"
    case workspaceDocument = "workspace document"
}
