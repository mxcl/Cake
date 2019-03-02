import enum Base.SwiftVersion
import CakefileDescription
import XcodeProject
import Foundation
import Version
import Path

private enum E: Error {
    case directoryExists(Path)
}

public enum ScaffoldingOption {
    case new(name: String, Path, PlatformSpecification)
    case existing(XcodeProject)
}

public func scaffold(_ option: ScaffoldingOption, cakeVersion: Version) throws -> (XcodeProject, XcakeProject) {

    if case .new(_, let prefix, _) = option, prefix.exists {
        throw E.directoryExists(prefix)
    }

    let mainProject: XcodeProject
    let platforms: Set<PlatformSpecification>
    let targets: [XcodeProject.NativeTarget]
    let swiftVersion: SwiftVersion
    let detritus: XcodeProject.Group?

    switch option {
    case .existing(let proj):
        mainProject = proj
        swiftVersion = mainProject.swiftVersion
        platforms = mainProject.platforms
        targets = mainProject.nativeTargets.filter{ $0.type == .application }

        //TODO read gitignore and ensure we don’t add duplicates
        try """
            /.cake/swift-pm
            /.cake/*.json
            /.cake/Package.swift
            /.cake/Version.xcconfig
            """.concatenate(to: mainProject.parentDirectory/".gitignore")

        detritus = nil

    case .new(let name, let prefix, let platspec):
        swiftVersion = .default
        platforms = [platspec]
        mainProject = XcodeProject(name: name, parentDirectory: prefix, for: platforms, swift: swiftVersion)
        let os = platspec.platform
        let srcdir = try prefix.Sources.App.mkdir(.p)

        try """
            xcuserdata
            *.xcscmblueprint
            .DS_Store
            # In case you are using Carthage too
            /Carthage
            # In case you are using CocoaPods too
            /Pods
            # In case you have a root SwiftPM manifest too
            /.build
            # SwiftPM metadata when resolving dependencies
            /.cake/swift-pm
            # intermediary files for Cake.xcodeproj
            /.cake/*.json
            /.cake/Package.swift
            /.cake/Version.xcconfig
            """.write(to: prefix/".gitignore")

        try prefix.join("Documents").mkdir(.p)
        try prefix.join("Tests").mkdir(.p)

        try mainProject.path.mkdir(.p)

        let sources = try mainProject.mainGroup.add(group: srcdir, name: .custom("Sources·App"))

        detritus = try mainProject.mainGroup.add(group: srcdir, name: .custom("Detritus"))
        detritus!.add(file: try os.infoPlist.write(to: srcdir/"Info.plist"))

        let storyboard = try os.storyboard.copy(to: srcdir/os.storyboardName)
        let target = mainProject.addNativeTarget(name: name, type: .application)
        try target.build(source: sources.add(file: os.appDelegate.write(to: srcdir/"AppDelegate.swift")))
        try target.build(resource: detritus!.add(file: storyboard))

        if os == .macOS {
            try storyboard.inreplace("___PACKAGENAMEASXML___", with: name)
        }
        target["INFOPLIST_FILE"] = "Sources/App/Info.plist"
        target["ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES"] = "YES"
        target["SKIP_INSTALL"] = "NO"
        target["PRODUCT_MODULE_NAME"] = "App"
        target["LD_RUNPATH_SEARCH_PATHS"] = ["$(inherited)", "@executable_path/\(os.rpath)"]

        var bids = ["dev"]
        bids += NSUserName().domainSafed.reversed().map{ $0.lowercased() }
        bids += [name.domainSafed.joined(separator: "-")]
        target["PRODUCT_BUNDLE_IDENTIFIER"] = bids.joined(separator: ".")

        targets = [target]

        // this prevents autocreation of schemes
        // this prevents listing Cakeproj’s schemes in the scheme selector
        mainProject.schemify(target: target)
    }

    try """
        import Cakefile

        dependencies = [
            // add your dependencies here, for example:
            //.github("mxcl/PromiseKit" ~> 6.7),

            // dependencies must be Swift packages, we will add support for
            // CocoaPods and Carthage provided our donation goals are met:
            // https://patreon.com/mxcl

            // this is optional, but you should leave it ∵ if you work in a team,
            // you should all be using the same version of Cake.
            .cake(~>\(cakeVersion.constraintStringValue))
        ]

        // specify your platforms and deployment targets here
        platforms = [\(platforms.map(\.description).joined(separator: ", "))]

        // uncomment if you want to change the base-module-name
        // options.baseModuleName = "Bakeware"

        """.write(to: mainProject.parentDirectory/"Cakefile.swift")

    let models = try mainProject.parentDirectory.Sources.Model.mkdir(.p)

    try """
        #if canImport(Dependencies)
            // to add 3rd-party dependencies, edit `Cakefile.swift` (in the project’s root directory)
            import Dependencies
        #endif

        /// Base model module

        """.write(to: models/"Base.swift")

    let cakeProject = try XcakeProject(prefix: mainProject.parentDirectory, platforms: platforms, swift: swiftVersion, options: Options())
    try cakeProject.path.mkdir(.p)
    try cakeProject.write()

    try """
        @_exported import Batter

        #if canImport(Dependencies)
            // to add 3rd-party dependencies, edit `Cakefile.swift` (in the project’s root directory)
            @_exported import Dependencies
        #endif

        """.write(to: cakeProject.parentDirectory/"Cake.swift").chmod(0o444)

    let cakeXCConfig = cakeProject.caked/"Cake.xcconfig"
    try """
        #include? "Version.xcconfig"

        """.write(to: cakeXCConfig)
    if let detritus = detritus {
        mainProject.baseConfiguration = detritus.add(file: cakeXCConfig, name: .basename)
    }

    mainProject.mainGroup.add(file: models, name: .custom("Sources·Model"), type: .folder, at: .top)

    if case .new(let name, let prefix, _) = option {
        //TODO describe each directory in the generated project
        try mainProject.mainGroup.add(file: """
            # \(name)

            This project is “Made with Cake”. Cake is a delicious, quality‑of‑life
            supplement for your app‑development toolbox.

            You do not need to install Cake.app to work with this project, but there are
            numerous advantages if you do so.

            https://github.com/mxcl/cake

            """.write(to: prefix/"README.md"), at: .top)
    }

    for target in targets {
        try target.depend(on: cakeProject.cakeTarget)
        try target.link(to: cakeProject.cakeTarget)
    }

    try mainProject.write()

    return (mainProject, cakeProject)
}

private extension Version {
    var constraintStringValue: String {
        if prereleaseIdentifiers.isEmpty {
            return "\(major).\(minor)"
        } else {
            let pi = prereleaseIdentifiers.map{ "\"\($0)\"" }.joined(separator: ", ")
            return "Version(\(major),\(minor),\(patch), prereleaseIdentifiers: [\(pi)])"
        }
    }
}

private extension String {
    // justified due to `String` having `write(to:)`
    func concatenate(to path: Path, encoding: String.Encoding = .utf8) throws {

        // we need to know if end of file is a newline or not, but I couldn't figure out
        // how to do that efficiently, so we wrap the input in newlines
        let str = "\n\(self)\n"

        guard let data = str.data(using: .utf8) else {
            throw CocoaError.error(.fileReadInapplicableStringEncoding)
        }
        if let fileHandle = try? FileHandle(forWritingTo: path.url) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } else {
            try data.write(to: path)
        }
    }

    var domainSafed: [String] {
        return folding(options: .diacriticInsensitive, locale: .init(identifier: "en_US"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
    }
}
