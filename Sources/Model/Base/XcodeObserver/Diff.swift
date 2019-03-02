public struct Diff<T: Hashable> {
    public let added: Set<T>
    public let removed: Set<T>
    public let newValue: Set<T>
}

extension Diff {
    init?(old: Set<T>, new: Set<T>) {
        if old.isEmpty, new.isEmpty {
            return nil
        } else if old.isEmpty {
            added = Set(new)
            removed = Set()
        } else if new.isEmpty {
            added = Set()
            removed = Set(old)
        } else {
            added = Set(new.filter{ !old.contains($0) })
            removed = Set(old.filter{ !new.contains($0) })

            if added.isEmpty, removed.isEmpty {
                return nil
            }
        }

        newValue = new
    }
}
