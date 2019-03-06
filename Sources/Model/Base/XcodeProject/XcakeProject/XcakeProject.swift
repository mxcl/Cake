import class Foundation.Bundle
import enum Base.SwiftVersion
import CakefileDescription
import XcodeProject
import Modelizer
import Path

public class XcakeProject: XcodeProject {
    let tips: [Module]
    let dependencies: DependenciesJSON

    var caked: Path { return parentDirectory }
    var prefix: Path { return caked.parent }
    var modelPrefix: Path { return prefix/"Sources/Model" }

    var cakeTarget: NativeTarget!

    enum E: Error {
        case modulePathNotInPrefix(Path)
        case programmerError
        case pathRelationError
        case noModules
        case invalidModuleHeirarchy

        /// we can support different structures, open a PR without code for discussion
        case unsupportedDirectoryHierarchy

        case noPlatforms
    }

    /// - Note: Tips and dependencies are **not** accurate
    override public init(existing: Path) throws {
        tips = []
        dependencies = .init()
        try super.init(existing: existing)
        cakeTarget = nativeTargets.first(where: { $0.name == "Cake" })
    }

    /// Creates a cake project without any dependencies determining modules itself
    /// - Parameter prefix: the directory that contains the `.cake` directory
    public convenience init(prefix: Path, platforms: Set<PlatformSpecification>, swift swiftVersion: SwiftVersion, options: CakefileDescription.Options) throws {
        guard !platforms.isEmpty else { throw E.noPlatforms }
        let model = prefix/"Sources/Model"
        let modules = try modelize(root: model, basename: options.baseModuleName)
        try self.init(tips: modules, dependencies: .init(), prefix: prefix, platforms: platforms, swift: swiftVersion, suppressDependencyWarnings: options.suppressDependencyWarnings)
    }

    /// Creates a cake project for the specified modules and dependencies
    /// - Parameter prefix: the directory that contains the `.cake` directory
    public init(tips: [Module], dependencies: DependenciesJSON, prefix: Path, platforms: Set<PlatformSpecification>, swift swiftVersion: SwiftVersion, suppressDependencyWarnings: Bool) throws {

        self.tips = tips
        self.dependencies = dependencies

        super.init(name: "Cake", parentDirectory: prefix/".cake", for: platforms, swift: swiftVersion)

        let cakefileTarget = addAggregateTarget(name: "Cakefile")
        cakefileTarget["SDKROOT"] = "macosx"
        cakefileTarget["SUPPORTED_PLATFORMS"] = ["macosx"]
        let script = cakefileTarget.add(script: .cakefileScript)
        script.name = "Regenerate Cake.xcodeproj"
        script.shellPath = "$(DT_TOOLCHAIN_DIR)/usr/bin/swift"
        script.inputPaths = ["$(PROJECT_DIR)/../Cakefile.swift"]
        script.outputPaths = [
            "$(PROJECT_DIR)/Cakefile.json",
            "$(PROJECT_DIR)/Dependencies.json"]

        let libdir = "$(HOME)/Library/Developer/Cake/DerivedData/$(XCODE_PRODUCT_BUILD_VERSION)/lib"

        let cakefileCompletionTarget = addNativeTarget(name: "Cakefile·Completion", type: .commandLineTool)
        try cakefileCompletionTarget.build(source: mainGroup.add(file: prefix/"Cakefile.swift", name: .basename))
        cakefileCompletionTarget["SDKROOT"] = "macosx"
        cakefileCompletionTarget["SUPPORTED_PLATFORMS"] = ["macosx"]
        cakefileCompletionTarget["LD"] = "/usr/bin/true"  // prevents link failure
        cakefileCompletionTarget["OTHER_SWIFT_FLAGS"] = ["-I", libdir, "-L", libdir]
        cakefileCompletionTarget["PRODUCT_NAME"] = "CakefileScript"
        cakefileCompletionTarget["PRODUCT_MODULE_NAME"] = "Script"

      //// third party dependencies
        let thirdPartyTarget: XcodeProject.NativeTarget?, thirdPartyTargets: [XcodeProject.NativeTarget]
        if !dependencies.isEmpty {
            let thirdPartyDepsGroup = try mainGroup.add(group: prefix/"Dependencies", name: .basename)

            let tips: [XcodeProject.NativeTarget]
            (tips, thirdPartyTargets) = try add(modules: dependencies.modules, to: { module in
                try dependencies.group(for: module, root: thirdPartyDepsGroup)
            }, prefix: "Deps·")

            for target in thirdPartyTargets {
                if !target.hasDependencies {
                    try target.depend(on: cakefileTarget)
                }
                target["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = ["$(inherited)", "SWIFT_PACKAGE"]
                if suppressDependencyWarnings {
                    // we don’t set for false since that is our project default
                    target["SWIFT_SUPPRESS_WARNINGS"] = true
                }
            }

            thirdPartyTarget = addNativeTarget(name: "Dependencies", type: .staticLibrary)
            for target in tips {
                try thirdPartyTarget!.depend(on: target)
            }

            for target in thirdPartyTargets {
                try thirdPartyTarget!.link(to: target)
            }

            preventSwiftMigration(for: thirdPartyTargets)

        } else {
            thirdPartyTarget = nil
            thirdPartyTargets = []
        }

      //// Model refs & targets
        let batterTarget: NativeTarget, batterTargets: [NativeTarget]
        do {
            let group = try mainGroup.add(group: modelPrefix, name: .custom("Batter"))
            let batterTips: [NativeTarget]
            (batterTips, batterTargets) = try add(modules: tips, to: group, prefix: "Batter·")

            if let thirdPartyTarget = thirdPartyTarget {
                for target in batterTargets where !target.hasDependencies {
                    try target.depend(on: thirdPartyTarget)
                }
            }

          //// batter target is an aggregate static archive of all modules
            batterTarget = addNativeTarget(name: "Batter", type: .staticLibrary)
            for target in batterTips {
                try batterTarget.depend(on: target)
            }
            for target in batterTargets {
                try batterTarget.link(to: target)
            }

          //// we may need to depend on Cakefile
            if thirdPartyTarget == nil {
                for target in batterTargets where !target.hasDependencies {
                    try target.depend(on: cakefileTarget)
                }
            }
        }

    ////// Kitchenware group
        let kitchenware = try mainGroup.add(group: caked, name: .custom("Kitchenware"))

        try batterTarget.build(source: kitchenware.add(file: caked/"Batter.swift"))
        try thirdPartyTarget?.build(source: kitchenware.add(file: caked/"Dependencies.swift"))

    ////// Versionator
        let versionator = addAggregateTarget(name: "Versionator")
        let vscript = versionator.add(script: """
            v=$(git describe --tags --always --abbrev=0)
            n=$(git rev-list HEAD --count)

            if [[ -z $v ]]; then v="0.0.0"; fi
            if [[ -z $n ]]; then n="0"; fi

            echo "CURRENT_PROJECT_VERSION = $n" > Version.xcconfig
            echo "SEMANTIC_PROJECT_VERSION = $v" >> Version.xcconfig
            echo "SEMANTIC_PROJECT_VERSION[config=Debug] = $v-debug" >> Version.xcconfig

            """)
        vscript.name = "Determine Version"
        vscript.outputPaths = ["Version.xcconfig"]
        //TODO input paths into git some file

    ////// Cake.a
        cakeTarget = addNativeTarget(name: "Cake", type: .staticLibrary)
        try cakeTarget.build(source: kitchenware.add(file: caked/"Cake.swift"))
        try cakeTarget.depend(on: batterTarget)
        try cakeTarget.depend(on: versionator)
        try cakeTarget.link(to: batterTarget)
        if let thirdPartyTarget = thirdPartyTarget {
            try cakeTarget.depend(on: thirdPartyTarget)
            try cakeTarget.link(to: thirdPartyTarget)
        }
    }

    private func add(modules tips: [Module], to parent: Group, prefix: String) throws -> (tips: [NativeTarget], all: [NativeTarget]) {
        return try add(modules: tips, to: { module in
            try parent.add(group: module.path, name: .custom(module.name))
        }, prefix: prefix)
    }

    private func add(modules tips: [Module], to groupFor: (Module) throws -> Group, prefix: String) throws -> (tips: [NativeTarget], all: [NativeTarget]) {
        var targets = [Module: NativeTarget]()
        let modules = tips.flattened

        for module in modules {
            let group = try groupFor(module)
            let target = addNativeTarget(name: "\(prefix)\(module.name)", type: .staticLibrary, productName: module.name)
            if let v = module.swiftVersion {
                target["SWIFT_VERSION"] = v.rawValue
            }
            for file in module.files {
                try target.build(source: group.add(file: file))
            }
            targets[module] = target
        }

        for module in modules {
            for dep in module.dependencies {
                guard let dep = targets[dep] else { throw E.programmerError }
                try targets[module]!.depend(on: dep)
            }
        }

        // return in order we received them to prevent the pbxproj
        // diff changing every time we generate
        return (tips.map{ targets[$0]! }, modules.map{ targets[$0]! })
    }

    override open func write() throws {
        try super.write()
        try generateBatterDotSwift(tips: tips)

        if !dependencies.isEmpty {
            try generateDependenciesDotSwift(importNames: dependencies.imports)
        } else {
            // no deps, so delete generated files (if any)
            func rm(root: Path, prefix: String, extnames: [String]) throws {
                for extname in extnames {
                    let path = root/"\(prefix).\(extname)"
                    if path.exists {
                        try path.delete()
                    }
                }
            }
            try rm(root: caked, prefix: "Dependencies", extnames: ["swift", "json"])
            try rm(root: caked, prefix: "Package", extnames: ["swift", "resolved"])
        }

        try generateDependenciesDotSwift(importNames: dependencies.imports)
    }
}

private extension DependenciesJSON {
    func group(for module: Module, root: XcodeProject.Group) throws -> XcodeProject.Group {
        func findOrCreate(_ package: Package, _ module: Module) throws -> XcodeProject.Group {
            for packageGroup in root.subgroups where packageGroup.name == package.displayName {
                return try packageGroup.add(group: module.path, name: .custom(module.name))
            }
            if package.moduleNames.count <= 1 {
                if module.files.count <= 1 {
                    return root
                } else {
                    return try root.add(group: module.path, name: .custom(package.displayName))
                }
            } else {
                return try root
                    .add(group: package.path, name: .custom(package.displayName))
                    .add(group: module.path, name: .custom(module.name))
            }
        }
        for package in packages where package.moduleNames.contains(module.name) {
            return try findOrCreate(package, module)
        }
        fatalError("FIXME: throw")
    }
}

private extension DependenciesJSON.Package {
    var displayName: String {
        if let version = version {
            return "\(name)-\(version)"
        } else {
            return name
        }
    }
}
