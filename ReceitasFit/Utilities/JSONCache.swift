import Foundation

/// Descodifica os campos guardados em JSON (ingredientes, passos, porções) uma só vez por conteúdo.
///
/// As vistas leem estes campos várias vezes em cada redesenho; sem cache, o JSON era
/// descodificado de cada vez. A chave é o próprio conteúdo (`Data`), por isso nunca devolve
/// valores desatualizados: se o JSON muda, a chave também muda.
enum JSONCache {
    private static var cache: [Key: Any] = [:]
    private static let limit = 600

    private struct Key: Hashable {
        let type: ObjectIdentifier
        let data: Data
    }

    static func decode<T: Decodable>(_ type: [T].Type, from data: Data) -> [T] {
        guard !data.isEmpty else { return [] }
        let key = Key(type: ObjectIdentifier(type), data: data)
        if let cached = cache[key] as? [T] {
            return cached
        }
        let value = (try? JSONDecoder().decode(type, from: data)) ?? []
        if cache.count >= limit {
            cache.removeAll(keepingCapacity: true)
        }
        cache[key] = value
        return value
    }

    static func encode<T: Encodable>(_ value: [T]) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    /// Só para testes.
    static var count: Int { cache.count }
    static func reset() { cache.removeAll() }
}
