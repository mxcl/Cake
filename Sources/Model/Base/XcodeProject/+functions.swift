import xcodeproj

extension XcodeProject {
    public func preventSwiftMigration(for targets: [NativeTarget]) {
        let dict = [
            "LastSwiftMigration": "9999"
        ]
        for target in targets {
            proj.pbxproj.rootObject!.setTargetAttributes(dict, target: target.underlyingTarget)
        }
    }

    public func addNativeTarget(name: String, type: PBXProductType, productName: String? = nil) -> NativeTarget {
        var displayName: String {
            let name = productName ?? name
            switch type {
            case .dynamicLibrary:
                return "\(name).dylib"
            case .staticLibrary:
                return "\(name).a"
            default:
                return name
            }
        }
        let productRef = PBXFileReference(sourceTree: .group, path: displayName)
        add(productRef)
        productsGroup.children.append(productRef)
        let target = PBXNativeTarget(name: name, buildConfigurationList: nil, buildPhases: [], buildRules: [], dependencies: [], productInstallPath: nil, productName: productName, product: productRef, productType: type)
        target.product = productRef
        add(target)
        pbxproj.rootObject!.targets.append(target)
        let nativeTarget = NativeTarget(owner: self, underlyingTarget: target)
        if let productName = productName {
            nativeTarget["PRODUCT_NAME"] = productName
        }
        if type == .dynamicLibrary {
            nativeTarget["EXECUTABLE_PREFIX"] = "lib"
        }
        return nativeTarget
    }

    public func addAggregateTarget(name: String) -> Target {
        let target = PBXAggregateTarget(name: name)
        add(target)
        pbxproj.rootObject!.targets.append(target)
        return Target(owner: self, underlyingTarget: target)
    }

    public func addProjectReference(to other: XcodeProject) throws {
        _ = try _addProjectReference(to: other)
    }

    func _addProjectReference(to other: XcodeProject) throws -> (PBXFileReference, PBXGroup) {
        if let foo = projectReferences[other] {
            return foo
        }

        guard other != self else { throw E.cannotReferenceSelf }

        let projectfileRef = mainGroup.add(file: other.path, name: .basename, type: .project)
        projectfileRef.explicitFileType = FileType.project.rawValue

        let hiddenProductGroup = PBXGroup(name: "Products")
        add(hiddenProductGroup)
        add(projectfileRef)

        // https://github.com/tuist/xcodeproj/issues/352
        proj.pbxproj.rootObject!.projects.append([
            "ProjectRef": projectfileRef,
            "ProductGroup": hiddenProductGroup
        ])

        projectReferences[other] = (projectfileRef, hiddenProductGroup)

        return (projectfileRef, hiddenProductGroup)
    }

    public func removeProjectReference(_ proj: XcodeProject) {

        func isProj(_ ref: PBXFileReference) -> Bool {
            return ref.lastKnownFileType == FileType.project.rawValue || ref.explicitFileType == FileType.project.rawValue
        }

        //FIXME not specific enough
        //FIXME doesn't remove all necessary objects
        for (index, dict) in proj.pbxproj.rootObject!.projects.reversed().enumerated() {
            if let ref = dict["ProjectRef"] as? PBXFileReference, isProj(ref), ref.name == proj.path.basename() {
                proj.pbxproj.rootObject!.projects.remove(at: index)
            }
        }
    }

    func add(_ object: PBXObject) {
        pbxproj.add(object: object)
    }

    func remove(_ object: PBXObject?) {
        if let object = object {
            pbxproj.delete(object: object)
        }
    }
}
