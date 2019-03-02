import OrderedSet

extension Array where Element: Hashable, Element: Comparable {
    public func topologicallySorted(successors: (Element) -> [Element]) -> [Element] {
        // Implements a topological sort via recursion and reverse postorder DFS.
        func visit(_ node: Element,
                   _ stack: inout OrderedSet<Element>, _ visited: inout Set<Element>, _ result: inout [Element],
                   _ successors: (Element) -> [Element]) {
            // Mark this node as visited -- we are done if it already was.
            if !visited.insert(node).inserted {
                return
            }

            // Otherwise, visit each adjacent node.
            for succ in successors(node).sorted() {
                assert(stack.index(of: succ) == nil)
                stack.append(succ)
                visit(succ, &stack, &visited, &result, successors)
                stack.removeLast()
            }

            // Add to the result.
            result.append(node)
        }

        var visited = Set<Element>()
        var result = [Element]()
        var stack = OrderedSet<Element>()
        for node in sorted() {
            precondition(stack.isEmpty)
            stack.append(node)
            visit(node, &stack, &visited, &result, successors)
            stack.removeLast()
        }

        return result.reversed()
    }
}

private extension OrderedSet {
    func removeLast() {
        remove(last!)  // is efficient in implementation
    }
}
