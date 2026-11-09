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

    /// Identifies one particular entry, so a caller can withdraw the entry it made without
    /// touching an identical one made since. Entries are keyed by content, so the key alone
    /// cannot tell two of them apart.
    struct Entry {
        fileprivate let key: String
        fileprivate let id: UInt64
    }

    private final class Node {
        let key: String
        let id: UInt64
        /// Weak, or two neighbours would hold each other alive: `a.next` points at `b` while
        /// `b.prev` points back at `a`. The dictionary below owns every node, so releasing the
        /// cache drops those owning references and the chain then unwinds from the head.
        weak var prev: Node?
        var next: Node?
        init(key: String, id: UInt64) {
            self.key = key
            self.id = id
        }
    }

    private var nodes: [String: Node] = [:]
    private var nextId: UInt64 = 0
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

    /// Records `key`, returning the entry it created, or nil when the key had been seen recently.
    /// A hit becomes the newest entry, so a flag that keeps being evaluated never ages out while it
    /// is still in use.
    func admit(_ key: String) -> Entry? {
        guard capacity > 0 else { return Entry(key: key, id: 0) }

        if let existing = nodes[key] {
            moveToTail(existing)
            return nil
        }

        nextId += 1
        let node = Node(key: key, id: nextId)
        nodes[key] = node
        appendToTail(node)

        if nodes.count > capacity, let oldest = head {
            detach(oldest)
            nodes.removeValue(forKey: oldest.key)
        }
        return Entry(key: key, id: nextId)
    }

    /// Withdraws `entry`, so the next identical event is reported rather than suppressed. Used when
    /// a batch fails to send: the events it carried were never delivered, so nothing has been said
    /// about them yet.
    ///
    /// Only the entry this caller made is withdrawn. Requests can finish out of order, so by the
    /// time an old batch fails its key may have been evicted and re-admitted by a newer batch that
    /// succeeded; removing by key alone would forget that delivery and send it all over again.
    func withdraw(_ entry: Entry) {
        guard let node = nodes[entry.key], node.id == entry.id else { return }
        nodes.removeValue(forKey: entry.key)
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
