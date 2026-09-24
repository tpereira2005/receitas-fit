import Foundation
import UIKit

/// Lê as fotografias da embalagem com o Gemini (Gemini Developer API, com a chave do utilizador).
///
/// O modelo percebe a tabela como uma pessoa: escolhe a coluna de 100 g / 100 ml mesmo com tabelas
/// separadas, lado a lado ou em várias línguas. As fotografias só são enviadas quando o utilizador
/// toca em "Ler"; nada é guardado sem rever no editor.
enum GeminiReader {
    static let keychainAccount = "gemini-api-key"

    /// Modelos a tentar, por ordem (se um não existir ou tiver a quota gratuita esgotada, tenta o seguinte).
    static let models = ["gemini-3.8-flash", "gemini-flash-latest", "gemini-3.5-flash-lite"]

    static var apiKey: String? {
        Keychain.string(for: keychainAccount).flatMap { $0.trimmed.isEmpty ? nil : $0.trimmed }
    }

    /// Resultado da leitura: valores por 100 g/ml e dados extra do rótulo.
    nonisolated struct Result: Equatable, Sendable {
        var name: String
        var brand: String
        var facts: PartialFacts
        /// Porção indicada no rótulo (ex.: "dose" = 30 g), para sugerir como porção do alimento.
        var servingName: String?
        var servingGrams: Double?
        /// Só usado para procurar no Open Food Facts; nunca é guardado.
        var barcode: String?
        var notes: String
    }

    enum ReadError: Error, Equatable {
        case noKey
        case invalidKey
        case quota
        case offline
        case unreadable(String)

        var message: String {
            switch self {
            case .noKey: "Sem chave do Gemini nas Definições"
            case .invalidKey: "A chave do Gemini não é válida"
            case .quota: "Limite gratuito do Gemini atingido por agora"
            case .offline: "Sem ligação ao Gemini"
            case .unreadable(let detail): "O Gemini não conseguiu ler as fotografias (\(detail))"
            }
        }
    }

    // MARK: - Pedido

    static func read(photos: [UIImage]) async throws -> Result {
        guard let key = apiKey else { throw ReadError.noKey }
        let images = photos.compactMap(jpeg)
        guard !images.isEmpty else { throw ReadError.unreadable("sem imagens") }
        let body = requestBody(images: images)

        var lastError = ReadError.unreadable("sem resposta")
        for model in models {
            do {
                let data = try await send(body, model: model, key: key)
                guard let result = parse(response: data) else { throw ReadError.unreadable("resposta inesperada") }
                return result
            } catch let error as ReadError {
                lastError = error
                // Chave errada ou sem internet: tentar outro modelo não adianta.
                if error == .invalidKey || error == .offline { throw error }
            } catch {
                lastError = .unreadable(error.localizedDescription)
            }
        }
        throw lastError
    }

    /// Verifica a chave com um pedido mínimo (sem imagens).
    static func test(key: String) async -> ReadError? {
        let body: [String: Any] = ["contents": [["parts": [["text": "Responde só: ok"]]]]]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return .unreadable("pedido") }
        for model in models {
            do {
                _ = try await send(data, model: model, key: key.trimmed)
                return nil
            } catch let error as ReadError {
                if error == .invalidKey || error == .offline { return error }
            } catch {}
        }
        return .quota
    }

    private static func send(_ body: Data, model: String, key: String) async throws -> Data {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw ReadError.unreadable("endereço")
        }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ReadError.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return data
        case 400 where String(decoding: data, as: UTF8.self).contains("API_KEY_INVALID"), 401, 403:
            throw ReadError.invalidKey
        case 429: throw ReadError.quota
        default: throw ReadError.unreadable("erro \(status)")
        }
    }

    /// Imagem em JPEG com no máximo 1600 px no lado maior (legível e leve).
    private static func jpeg(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.8) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Instruções e formato da resposta

    static let prompt = """
    Estas fotografias são de uma embalagem de um alimento (frente, tabela nutricional, código de barras…).
    Extrai a informação nutricional POR 100 g (ou POR 100 ml, se o rótulo for por 100 ml).

    Regras:
    - Usa só a coluna de 100 g / 100 ml. Ignora colunas ou tabelas por porção, por dose e %DR/%VRN.
    - Se o rótulo só tiver valores por porção, calcula os valores por 100 g com o peso da porção e explica em "notas".
    - Energia em kcal. Se só houver kJ, converte (kcal = kJ / 4,184).
    - Se só houver sódio, sal = sódio × 2,5.
    - Valores escritos como "<0,5 g" (ou "< 0,1"): usa o número (0,5) e põe o nome do campo em "menor_que".
    - Se um valor não estiver visível, usa null. Nunca inventes valores.
    - "nome": nome do produto como aparece na frente, em português se existir. "marca": só a marca.
    - "porcao_nome" e "porcao_gramas": a porção indicada no rótulo (ex.: "dose", 30), se existir.
    - "codigo_barras": os dígitos por baixo do código de barras, se estiverem visíveis.
    - Não copies a lista de ingredientes.
    - "notas": dúvidas ou problemas de leitura (em português, curto). Vazio se não houver.
    """

    private static func number(_ description: String) -> [String: Any] {
        ["type": "NUMBER", "nullable": true, "description": description]
    }

    static let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "nome": ["type": "STRING"],
            "marca": ["type": "STRING"],
            "base": ["type": "STRING", "enum": ["100g", "100ml"]],
            "energia_kcal": number("kcal por 100 g/ml"),
            "lipidos": number("g por 100 g/ml"),
            "saturados": number("g por 100 g/ml"),
            "hidratos": number("g por 100 g/ml"),
            "acucares": number("g por 100 g/ml"),
            "fibra": number("g por 100 g/ml"),
            "proteina": number("g por 100 g/ml"),
            "sal": number("g por 100 g/ml"),
            "menor_que": [
                "type": "ARRAY",
                "items": ["type": "STRING", "enum": ["lipidos", "saturados", "hidratos", "acucares", "fibra", "proteina", "sal"]],
            ],
            "porcao_nome": ["type": "STRING", "nullable": true],
            "porcao_gramas": number("peso da porção em g ou ml"),
            "codigo_barras": ["type": "STRING", "nullable": true],
            "notas": ["type": "STRING"],
        ],
        "required": ["nome", "marca", "base", "energia_kcal", "lipidos", "saturados", "hidratos",
                     "acucares", "fibra", "proteina", "sal", "menor_que", "notas"],
    ]

    static func requestBody(images: [Data]) -> Data {
        var parts: [[String: Any]] = images.map { ["inline_data": ["mime_type": "image/jpeg", "data": $0.base64EncodedString()]] }
        parts.append(["text": prompt])
        let body: [String: Any] = [
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema,
                "temperature": 0,
            ],
        ]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    // MARK: - Resposta

    private nonisolated static let fields: [(Nutrient, String)] = [
        (.calories, "energia_kcal"), (.fat, "lipidos"), (.saturatedFat, "saturados"), (.carbs, "hidratos"),
        (.sugars, "acucares"), (.fiber, "fibra"), (.protein, "proteina"), (.salt, "sal"),
    ]

    /// Interpreta a resposta do Gemini (separado da rede para poder ser testado).
    nonisolated static func parse(response data: Data) -> Result? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else { return nil }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        guard let answer = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return nil }

        var facts = PartialFacts()
        facts.base = (answer["base"] as? String) == "100ml" ? .milliliters : .grams
        for (nutrient, key) in fields {
            if let value = answer[key] as? Double, value >= 0 { facts[nutrient] = value }
        }
        let lessThan = Set((answer["menor_que"] as? [String]) ?? [])
        for (nutrient, key) in fields where lessThan.contains(key) && facts[nutrient] != nil {
            facts.lessThan.insert(nutrient)
        }
        let string = { (key: String) in ((answer[key] as? String) ?? "").trimmed }
        let barcode = string("codigo_barras").filter(\.isNumber)
        let servingName = string("porcao_nome")
        return Result(
            name: string("nome"),
            brand: string("marca"),
            facts: facts,
            servingName: servingName.isEmpty ? nil : servingName,
            servingGrams: (answer["porcao_gramas"] as? Double).flatMap { $0 > 0 ? $0 : nil },
            barcode: barcode.count >= 8 ? barcode : nil,
            notes: string("notas")
        )
    }
}
