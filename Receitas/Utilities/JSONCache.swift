import Foundation
import Synchronization

/// Descodifica os campos guardados em JSON (ingredientes, passos, porções) uma só vez por conteúdo.
///
/// As vistas leem estes campos várias vezes em cada redesenho; sem cache, o JSON era
/// descodificado de cada vez. A chave é o próprio conteúdo (`Data`), por isso nunca devolve
/// valores desatualizados: se o JSON muda, a chave também muda.
/// Os modelos do SwiftData não estão isolados no MainActor, por isso a cache é protegida por um `Mutex`.
nonisolated enum JSONCache {
    private struct Key: Hashable, Sendable {
        let type: ObjectIdentifier
        let data: Data
    }

    private static let storage = Mutex<[Key: any Sendable]>([:])
    private static let limit = 600

    static func decode<T: Decodable & Sendable>(_ type: [T].Type, from data: Data) -> [T] {
        guard !data.isEmpty else { return [] }
        let key = Key(type: ObjectIdentifier(type), data: data)
        if let cached = storage.withLock({ $0[key] }) as? [T] {
            return cached
        }
        let value = (try? JSONDecoder().decode(type, from: data)) ?? []
        storage.withLock { cache in
            if cache.count >= limit {
                cache.removeAll(keepingCapacity: true)
            }
            cache[key] = value
        }
        return value
    }

    static func encode<T: Encodable>(_ value: [T]) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    /// Só para testes.
    static var count: Int { storage.withLock { $0.count } }
    static func reset() { storage.withLock { $0.removeAll() } }
}
