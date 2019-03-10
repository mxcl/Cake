/**
 tuist/xcodeproj is a very literal implementation of the PBXProject file-format.

 This makes using it error-prone and unreadable, this is a facade pattern for
 tuist/xcodeproj. However we only implemented what we needed so don’t expect
 it to be everything *you* might need in your own projects!
 */

import enum Base.SwiftVersion
import CakefileDescription
import xcodeproj
import Path

open class XcodeProject {
    let proj: XcodeProj
    var projectReferences: [XcodeProject: (PBXFileReference, PBXGroup)] = [:]

    public let parentDirectory: Path

    /// pass the path to the .xcodeproj *directory*
    public init(existing: Path) throws {

        if existing.extension == "xcworkspace" {
            let wsp = try XCWorkspace(pathString: existing.string)
            let prj: [String] = wsp.data.children.compactMap {
                switch $0 {
                case .file(let ref) where ref.location.path == "Pods/Pods.xcodeproj":
                    return nil
                case .file(let ref):
                    return ref.location.path
                default:
                    return nil
                }
            }
            guard prj.count == 1 else {
                throw E.workspaceHasTooManyProjects
            }
            proj = try XcodeProj(pathString: existing.parent.join(prj[0]).string)
        } else {
            proj = try XcodeProj(pathString: existing.string)
        }

        parentDirectory = existing.parent

        guard proj.pbxproj.rootObject != nil else {
            throw E.readNoRootObject
        }
        guard proj.pbxproj.rootObject!.mainGroup != nil else {
            throw E.readNoMainGroup
        }
        guard proj.pbxproj.rootObject!.productsGroup != nil else {
            throw E.readNoProductsGroup
        }
    }

    /// for a _not_yet_existing_ project, however parentDirectory must exist
    public init(name: String, parentDirectory: Path, for platforms: Set<PlatformSpecification>, swift swiftVersion: SwiftVersion) {
        let common = [String: Any].commonBuildSettings(for: platforms, swift: swiftVersion)
        let debug = XCBuildConfiguration(name: "Debug", buildSettings: common.merging(.debugBuildSettings){ $1 })
        let release = XCBuildConfiguration(name: "Release", buildSettings: common.merging(.releaseBuildSettings){ $1 })
        let confs = XCConfigurationList(buildConfigurations: [debug, release], defaultConfigurationName: "Release")

        let mainGroup = PBXGroup(sourceTree: .sourceRoot, path: "")
        let rootObject = PBXProject(
            name: name,
            buildConfigurationList: confs,
            compatibilityVersion: "Xcode 9.3",
            mainGroup: mainGroup
        )

        let pbxProj = PBXProj(rootObject: rootObject)

        let productsGroup = PBXGroup(sourceTree: .group, name: "Products")
        rootObject.productsGroup = productsGroup
        mainGroup.children.append(productsGroup)

        pbxProj.add(object: mainGroup)
        pbxProj.add(object: rootObject)
        pbxProj.add(object: productsGroup)
        pbxProj.add(object: confs)
        pbxProj.add(object: debug)
        pbxProj.add(object: release)

        self.proj = XcodeProj(workspace: XCWorkspace(), pbxproj: pbxProj)
        self.parentDirectory = parentDirectory
    }

    open func write() throws {
        try proj.write(path: PathKitPath(path))

        // we don’t want this, but tuist/xcodeproj cannot *not* create it
        try path.join("project.xcworkspace/contents.xcworkspacedata").delete()

        try """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>IDEWorkspaceSharedSettings_AutocreateContextsIfNeeded</key>
                <false/>
            </dict>
            </plist>
            """.write(to: path.join("project.xcworkspace/xcshareddata").mkdir(.p).join("WorkspaceSettings.xcsettings"))

        if let target = xcschememanagementPlistTarget {
            let d = path/"xcshareddata/xcschemes"
            try d.mkdir(.p)
            try """
                <?xml version="1.0" encoding="UTF-8"?>
                <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                <plist version="1.0">
                <dict>
                    <key>SchemeUserState</key>
                    <dict>
                        <key>\(target.name).xcscheme_^#shared#^_</key>
                        <dict>
                            <key>orderHint</key>
                            <integer>0</integer>
                        </dict>
                    </dict>
                    <key>SuppressBuildableAutocreation</key>
                    <dict>
                        <key>\(target.uuid)</key>
                        <dict>
                            <key>primary</key>
                            <true/>
                        </dict>
                    </dict>
                </dict>
                </plist>
                """.write(to: d/"xcschememanagement.plist")
        }
    }

    private var xcschememanagementPlistTarget: PBXTarget?

    /// configures project to have a single scheme for the specified target
    public func schemify(target: NativeTarget) {
        let scheme = XCScheme(name: name, lastUpgradeVersion: nil, version: nil)
        scheme.buildAction = XCScheme.BuildAction()
        scheme.buildAction!.parallelizeBuild = true
        scheme.buildAction!.buildImplicitDependencies = false

        let ref = XCScheme.BuildableReference(
            referencedContainer: "container:\(name).xcodeproj",
            blueprint: target.underlyingTarget,
            buildableName: "\(target.name).app",
            blueprintName: target.name)

        scheme.buildAction!.buildActionEntries = [
            XCScheme.BuildAction.Entry(buildableReference: ref, buildFor: XCScheme.BuildAction.Entry.BuildFor.default)
        ]

        let runnable = XCScheme.BuildableProductRunnable(buildableReference: ref)

        scheme.launchAction = XCScheme.LaunchAction(buildableProductRunnable: runnable, buildConfiguration: "Debug")
        scheme.launchAction!.environmentVariables = [
            // prevents the log filling with junk and garbage
            XCScheme.EnvironmentVariable(variable: "OS_ACTIVITY_MODE", value: "disable", enabled: true)
        ]

        proj.sharedData = XCSharedData(schemes: [scheme])

        xcschememanagementPlistTarget = target.underlyingTarget
    }
}

public extension XcodeProject {
    var name: String {
        return proj.pbxproj.rootObject!.name
    }

    var path: Path {
        return parentDirectory/"\(name).xcodeproj"
    }

    var mainGroup: Group {
        return Group(owner: self, parentPath: parentDirectory, underlyingGroup: proj.pbxproj.rootObject!.mainGroup!)
    }

    var nativeTargets: [NativeTarget] {
        return proj.pbxproj.nativeTargets.map {
            NativeTarget(owner: self, underlyingTarget: $0)
        }
    }

    enum E: Error {
        case readNoRootObject
        case readNoMainGroup
        case cannotReferenceSelf
        case nativeTargetHasNoProductReference
        case readNoProductsGroup
        case groupHasNoPath
        case invalidBuildConfigurations
        case workspaceHasTooManyProjects
    }

    enum Name {
        case inferred
        case basename
        case custom(String)

        func string(path: Path) -> String? {
            switch self {
            case .basename:
                return path.basename()
            case .inferred:
                return nil
            case .custom(let name):
                return name
            }
        }
    }

    enum FileType: String {
        case project = "wrapper.pb-project"
        case folder = "folder"
    }

    var baseConfiguration: PBXFileReference {
        set {
            guard let confs = pbxproj.rootObject?.buildConfigurationList?.buildConfigurations else {
                fatalError()
            }
            for conf in confs {
                conf.baseConfiguration = newValue
            }
        }
        get {
            fatalError()
        }
    }
}

internal extension XcodeProject {
    var pbxproj: PBXProj {
        return proj.pbxproj
    }

    var productsGroup: PBXGroup {
        return pbxproj.rootObject!.productsGroup!
    }
}

extension XcodeProject: Equatable, Hashable {
    public static func ==(lhs: XcodeProject, rhs: XcodeProject) -> Bool {
        return lhs.name == rhs.name && lhs.parentDirectory == rhs.parentDirectory
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(parentDirectory)
    }
}
