import xcodeproj
import Base

public extension XcodeProject {
    class Target {
        let owner: XcodeProject
        let underlyingTarget: PBXTarget

        init(owner: XcodeProject, underlyingTarget: PBXTarget) {
            self.owner = owner
            self.underlyingTarget = underlyingTarget
        }
    }

    class NativeTarget: Target {

    }
}

public extension XcodeProject.Target {
    var name: String {
        return underlyingTarget.name
    }

    var type: PBXProductType? {
        return underlyingTarget.productType
    }

    var hasDependencies: Bool {
        return !underlyingTarget.dependencies.isEmpty
    }

    func add(script: String) -> PBXShellScriptBuildPhase {
        let phase = PBXShellScriptBuildPhase(shellScript: script, showEnvVarsInLog: false)
        underlyingTarget.buildPhases.append(phase)
        owner.add(phase)
        return phase
    }
}

public extension  XcodeProject.NativeTarget {

    func link(to target: XcodeProject.NativeTarget) throws {
        guard let productRef = target.underlyingTarget.product else {
            throw XcodeProject.E.nativeTargetHasNoProductReference
        }
        if target.owner == owner {
            _ = try linkPhase.add(file: productRef)
        } else {
            let (containerPortal, productsGroup) = try owner._addProjectReference(to: target.owner)
            let remote = PBXContainerItemProxy(containerPortal: containerPortal, remoteGlobalID: productRef, proxyType: .reference, remoteInfo: target.name)
            let refProxy = PBXReferenceProxy(fileType: productRef.explicitFileType, path: productRef.path, name: target.name, remote: remote, sourceTree: .buildProductsDir)
            _ = try linkPhase.add(file: refProxy)
            owner.add(remote)
            owner.add(refProxy)
            productsGroup.children.append(refProxy)
        }
    }

    func build(source: PBXFileReference) throws {
        _ = try sourcesPhase.add(file: source)
    }

    func build(resource: PBXFileReference) throws {
        _ = try resourcesPhase.add(file: resource)
    }

    func depend(on target: XcodeProject.Target) throws {
        if target.owner == owner {
            _ = try (underlyingTarget as! PBXNativeTarget).addDependency(target: target.underlyingTarget)
        } else {
            let (containerPortal, _) = try owner._addProjectReference(to: target.owner)
            let proxy = PBXContainerItemProxy(containerPortal: containerPortal, remoteGlobalID: target.underlyingTarget, proxyType: .nativeTarget, remoteInfo: target.name)
            let dep = PBXTargetDependency(name: target.name, target: target.underlyingTarget, targetProxy: proxy)
            underlyingTarget.dependencies.append(dep)
            owner.add(proxy)
            owner.add(dep)
        }
    }

    func purge(_ dependency: XcodeProject.NativeTarget) {
        if dependency.owner == owner {
            fatalError()
        } else {
            for dep in owner.pbxproj.targetDependencies where dep.target == dependency.underlyingTarget {
                owner.remove(dep.targetProxy)
                owner.remove(dep)
                if let index = underlyingTarget.dependencies.firstIndex(of: dep) {
                    underlyingTarget.dependencies.remove(at: index)
                }
            }
            //FIXME will create the linkPhase if doesn't exist yet!
            let linkPhase = self.linkPhase
            //FIXME needs to compare containerPortal
            for case let (index, file) in linkPhase.files.reversed().enumerated() {
                if let ref = file.file, ref.name == dependency.name {
                    linkPhase.files.remove(at: index)
                    owner.remove(ref)
                }
            }
        }
    }
}
