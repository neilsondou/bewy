import Foundation

protocol Cacheable {
    associatedtype Key: Hashable
    associatedtype Value
    func get(_ key: Key) -> Value?
    mutating func set(_ key: Key, value: Value)
}

struct LRUCache<K: Hashable, V>: Cacheable {
    typealias Key = K
    typealias Value = V

    private var cache: [K: V] = [:]
    private var order: [K] = []
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    func get(_ key: K) -> V? {
        return cache[key]
    }

    mutating func set(_ key: K, value: V) {
        if cache[key] != nil {
            order.removeAll { $0 == key }
        } else if order.count >= capacity {
            let evicted = order.removeFirst()
            cache.removeValue(forKey: evicted)
        }
        cache[key] = value
        order.append(key)
    }

    var count: Int { cache.count }
}

enum Result<T> {
    case success(T)
    case failure(Error)

    func map<U>(_ transform: (T) -> U) -> Result<U> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
}

// Usage
var cache = LRUCache<String, Int>(capacity: 3)
cache.set("a", value: 1)
cache.set("b", value: 2)
cache.set("c", value: 3)
cache.set("d", value: 4) // evicts "a"
print("b = \(cache.get("b") ?? -1)")
print("a = \(cache.get("a") ?? -1)") // nil since evicted
