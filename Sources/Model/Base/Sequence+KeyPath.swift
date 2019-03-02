public extension Sequence {
    @inlinable
    func map<T>(_ keyPath: KeyPath<Element, T>) -> [T] {
        return map {
            $0[keyPath: keyPath]
        }
    }

    @inlinable
    func compactMap<T>(_ keyPath: KeyPath<Element, T?>) -> [T] {
        return compactMap {
            $0[keyPath: keyPath]
        }
    }

    @inlinable
    func flatMap<T>(_ keyPath: KeyPath<Element, [T]>) -> [T] {
        return flatMap {
            $0[keyPath: keyPath]
        }
    }
}
