import Foundation

/// Insertion-ordered LRU of the event keys sent recently.
///
/// A plain `Set` will not do. The cache has to evict the *oldest* key when it is full, and a
/// duplicate has to move back to the newest position — both on what is the hot path, since a
/// duplicate hit is the common case once an app settles and keeps re-evaluating the same flags.
/// Scanning an array for the key would make every one of those hits cost a walk of the whole
/// cache, so the order is kept as an intrusive linked list and lookups go through the dictionary.
///
/// Not thread-safe: the tracking plugin touches it only from its own serial queue.
final class DedupeCache {

    private final class Node {
        let key: String
        /// Weak, or two neighbours would hold each other alive: `a.next` points at `b` while
        /// `b.prev` points back at `a`. The dictionary below owns every node, so releasing the
        /// cache drops those owning references and the chain then unwinds from the head.
        weak var prev: Node?
        var next: Node?
        init(key: String) { self.key = key }
    }

    private var nodes: [String: Node] = [:]
    /// Least recently used — the next to be evicted.
    private var head: Node?
    /// Most recently used.
    private var tail: Node?

    private let capacity: Int

    /// A capacity of zero disables deduping entirely rather than dropping every event.
    init(capacity: Int) {
        self.capacity = max(0, capacity)
    }

    var count: Int { nodes.count }

    /// Records `key` and reports whether it had been seen recently. A hit becomes the newest entry,
    /// so a flag that keeps being evaluated never ages out while it is still in use.
    func insertAndReportDuplicate(_ key: String) -> Bool {
        guard capacity > 0 else { return false }

        if let existing = nodes[key] {
            moveToTail(existing)
            return true
        }

        let node = Node(key: key)
        nodes[key] = node
        appendToTail(node)

        if nodes.count > capacity, let oldest = head {
            detach(oldest)
            nodes.removeValue(forKey: oldest.key)
        }
        return false
    }

    /// Forgets `key`, so the next identical event is reported rather than suppressed. Used when a
    /// batch fails to send: the events it carried were never delivered, so nothing has been said
    /// about them yet.
    func remove(_ key: String) {
        guard let node = nodes.removeValue(forKey: key) else { return }
        detach(node)
    }

    // MARK: - List plumbing

    private func appendToTail(_ node: Node) {
        node.prev = tail
        node.next = nil
        tail?.next = node
        tail = node
        if head == nil { head = node }
    }

    private func moveToTail(_ node: Node) {
        guard tail !== node else { return }
        detach(node)
        appendToTail(node)
    }

    private func detach(_ node: Node) {
        let previous = node.prev
        let following = node.next
        previous?.next = following
        following?.prev = previous
        if head === node { head = following }
        if tail === node { tail = previous }
        node.prev = nil
        node.next = nil
    }
}
