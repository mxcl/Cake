import xcodeproj
import Path

public extension XcodeProject {
    struct Group {
        let owner: XcodeProject
        let parentPath: Path
        let underlyingGroup: PBXGroup

        var path: Path {
            return parentPath/(underlyingGroup.path ?? "")
        }
    }
}

public extension XcodeProject.Group {

    enum Position {
        case top, bottom
    }

    var name: String {
        return underlyingGroup.name ?? path.basename()
    }

    var subgroups: [XcodeProject.Group] {
        return underlyingGroup.children.compactMap{ $0 as? PBXGroup }.map {
            .init(owner: owner, parentPath: path, underlyingGroup: $0)
        }
    }

    private func smartAppend(_ ref: PBXFileElement) {
        // insert before the Products Group if applicable
        if underlyingGroup === owner.mainGroup.underlyingGroup, let index = underlyingGroup.children.firstIndex(where: { $0 === owner.productsGroup }) {
            underlyingGroup.children.insert(ref, at: index)
        } else {
            underlyingGroup.children.append(ref)
        }
    }

    @discardableResult
    func add(file: Path, name: XcodeProject.Name = .inferred, type: XcodeProject.FileType? = nil, at position: Position = .bottom) -> PBXFileReference {
        let ref = PBXFileReference(sourceTree: .group, name: name.string(path: file), lastKnownFileType: type?.rawValue, path: file.relative(to: path))
        owner.add(ref)
        switch position {
        case .bottom:
            smartAppend(ref)
        case .top:
            underlyingGroup.children.insert(ref, at: 0)
        }
        return ref
    }

    func add(group groupPath: Path, name: XcodeProject.Name = .inferred) throws -> XcodeProject.Group {
        let group = PBXGroup(sourceTree: .group, name: name.string(path: groupPath), path: groupPath.relative(to: path))
        smartAppend(group)
        owner.add(group)
        return .init(owner: owner, parentPath: self.path, underlyingGroup: group)
    }

    // adds a group without a path
    func addGroup(name: String) -> XcodeProject.Group {
        let group = PBXGroup(sourceTree: .group, name: name)
        smartAppend(group)
        owner.add(group)
        return .init(owner: owner, parentPath: path, underlyingGroup: group)
    }
}
