import Foundation

/// Converte texto livre (legendas do Instagram/TikTok, texto de capturas de ecrã) numa receita estruturada.
enum RecipeTextParser {
    struct Result {
        var title: String?
        var ingredients: [Ingredient] = []
        var steps: [RecipeStep] = []
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
        var servings: Int?
        var sourceURL: String?

        var isEmpty: Bool { title == nil && ingredients.isEmpty && steps.isEmpty }
    }

    private enum Section { case unknown, ingredients, steps, nutrition }

    static func parse(_ text: String) -> Result {
        var result = Result()
        var section = Section.unknown
        var sawHeader = false
        var preamble: [String] = []
        var nutritionLines: [String] = []

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

        for raw in lines {
            if let header = header(for: raw) {
                section = header
                sawHeader = true
                if result.servings == nil { result.servings = servings(in: raw) }
                continue
            }
            if raw.lowercased().hasPrefix("http") { continue }

            let line = stripBullet(raw)
            guard !line.isEmpty else { continue }

            if isNutritionLine(line) && !startsWithQuantity(line) {
                nutritionLines.append(line)
                continue
            }

            switch section {
            case .ingredients:
                result.ingredients.append(parseIngredient(line))
            case .steps:
                let step = stripStepNumber(line)
                if !step.isEmpty { result.steps.append(RecipeStep(text: step)) }
            case .nutrition:
                nutritionLines.append(line)
            case .unknown:
                preamble.append(line)
            }
        }

        if sawHeader {
            result.title = preamble.first { $0.count <= 70 }
        } else {
            // Sem cabeçalhos: tenta adivinhar linha a linha.
            for line in preamble {
                if looksLikeIngredient(line) {
                    result.ingredients.append(parseIngredient(line))
                } else if line.count >= 45 || startsWithStepNumber(line) {
                    let step = stripStepNumber(line)
                    if !step.isEmpty { result.steps.append(RecipeStep(text: step)) }
                } else if result.title == nil {
                    result.title = line
                }
            }
        }

        let nutritionText = nutritionLines.joined(separator: "\n")
        result.calories = value(for: "kcal|calorias|energia", in: nutritionText)
        result.protein = value(for: "prote[ií]nas?|protein", in: nutritionText)
        result.carbs = value(for: "hidratos(?:\\s+de\\s+carbono)?|carboidratos|carbs?", in: nutritionText)
        result.fat = value(for: "gorduras?|l[ií]pidos|fat", in: nutritionText)
        if result.servings == nil { result.servings = servings(in: text) }
        result.sourceURL = firstLink(in: text)

        if let title = result.title {
            result.title = title.trimmingCharacters(in: CharacterSet(charactersIn: ":.-–— ")).trimmed
        }
        return result
    }

    // MARK: - Ingredientes

    private static let unitAliases: [(String, String)] = [
        ("colheres de sopa", "c. sopa"), ("colher de sopa", "c. sopa"), ("c. de sopa", "c. sopa"), ("c. sopa", "c. sopa"),
        ("c.sopa", "c. sopa"), ("c.s.", "c. sopa"), ("tbsp", "c. sopa"),
        ("colheres de chá", "c. chá"), ("colher de chá", "c. chá"), ("c. de chá", "c. chá"), ("c. chá", "c. chá"),
        ("c.chá", "c. chá"), ("c.c.", "c. chá"), ("tsp", "c. chá"),
        ("chávenas", "chávena"), ("chávena", "chávena"), ("xícaras", "chávena"), ("xícara", "chávena"), ("cups", "chávena"), ("cup", "chávena"),
        ("copos", "copo"), ("copo", "copo"),
        ("unidades", "un"), ("unidade", "un"), ("und", "un"), ("un.", "un"), ("un", "un"),
        ("dentes", "dentes"), ("dente", "dente"), ("fatias", "fatias"), ("fatia", "fatia"),
        ("latas", "latas"), ("lata", "lata"), ("scoops", "scoop"), ("scoop", "scoop"),
        ("pitadas", "pitada"), ("pitada", "pitada"), ("punhado", "punhado"),
        ("quilos", "kg"), ("kg", "kg"), ("gramas", "g"), ("gr", "g"), ("mg", "mg"), ("g", "g"),
        ("ml", "ml"), ("dl", "dl"), ("cl", "cl"), ("litros", "l"), ("litro", "l"), ("l", "l"), ("oz", "oz"),
    ].sorted { $0.0.count > $1.0.count }

    static func parseIngredient(_ line: String) -> Ingredient {
        var rest = line.trimmed
        var amount: Double?
        var unit = ""

        if let match = firstMatch(#"^((?:\d+\s+)?\d+\s*/\s*\d+|\d+(?:[.,]\d+)?|[½¼¾⅓⅔])\s*(?:x\s+)?"#, in: rest) {
            amount = number(from: match[1])
            rest = String(rest.dropFirst(match[0].count))
        }

        let lower = rest.lowercased()
        for (alias, canonical) in unitAliases where lower.hasPrefix(alias) {
            let after = lower.dropFirst(alias.count)
            if let next = after.first, next.isLetter { continue }
            unit = canonical
            rest = String(rest.dropFirst(alias.count)).trimmed
            break
        }

        if !unit.isEmpty, let match = firstMatch(#"^(?:de|of)\s+"#, in: rest) {
            rest = String(rest.dropFirst(match[0].count))
        }

        if amount == nil, let match = firstMatch(#"\s*(?:q\.?\s?b\.?|a gosto)\s*$"#, in: rest) {
            unit = "q.b."
            rest = String(rest.dropLast(match[0].count))
        }

        var name = rest.trimmingCharacters(in: CharacterSet(charactersIn: " ,;.-–:")).trimmed
        if let first = name.first {
            name = first.uppercased() + name.dropFirst()
        }
        return Ingredient(name: name.isEmpty ? line : name, amount: amount, unit: unit)
    }

    private static func number(from string: String) -> Double? {
        let text = string.trimmed.replacingOccurrences(of: #"\s*/\s*"#, with: "/", options: .regularExpression)
        switch text {
        case "½": return 0.5
        case "¼": return 0.25
        case "¾": return 0.75
        case "⅓": return 1.0 / 3.0
        case "⅔": return 2.0 / 3.0
        default: break
        }
        if text.contains("/") {
            var total = 0.0
            for part in text.split(separator: " ") {
                if part.contains("/") {
                    let fraction = part.split(separator: "/")
                    if fraction.count == 2, let top = Double(fraction[0]), let bottom = Double(fraction[1]), bottom != 0 {
                        total += top / bottom
                    }
                } else if let whole = Double(part) {
                    total += whole
                }
            }
            return total > 0 ? total : nil
        }
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: - Heurísticas de linhas

    private static func header(for line: String) -> Section? {
        let cleaned = stripBullet(line)
        let normalized = cleaned.searchNormalized.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
        guard !normalized.isEmpty, normalized.count <= 40 else { return nil }
        // "Passo 1: mistura tudo" é um passo, não um cabeçalho.
        if let colon = normalized.firstIndex(of: ":"), String(normalized[normalized.index(after: colon)...]).trimmed.count > 3 {
            return nil
        }
        if normalized.contains("ingrediente") { return .ingredients }
        let stepKeys = ["preparacao", "modo de prepar", "modo de fazer", "como fazer", "preparo", "instruc", "metodo", "passo a passo", "passos"]
        if stepKeys.contains(where: { normalized.contains($0) }) { return .steps }
        let nutritionKeys = ["informacao nutricional", "valores nutricionais", "valor nutricional", "macros", "nutricao"]
        if nutritionKeys.contains(where: { normalized.contains($0) }) { return .nutrition }
        return nil
    }

    private static func isNutritionLine(_ line: String) -> Bool {
        let normalized = line.searchNormalized
        guard normalized.contains(where: \.isNumber) else { return false }
        let keys = ["kcal", "calorias", "proteina", "hidratos", "carboidrat", "carbs", "gordura", "lipidos", "macros"]
        return keys.contains(where: { normalized.contains($0) })
    }

    private static func startsWithQuantity(_ line: String) -> Bool {
        guard let first = line.first else { return false }
        return first.isNumber
    }

    private static func looksLikeIngredient(_ line: String) -> Bool {
        if startsWithQuantity(line) && !startsWithStepNumber(line) && line.count < 60 { return true }
        return firstMatch(#"\s(?:q\.?\s?b\.?|a gosto)\s*$"#, in: line) != nil
    }

    private static func startsWithStepNumber(_ line: String) -> Bool {
        firstMatch(#"^(?:passo\s*)?\d{1,2}\s*[.)ºª°:-]\s+\S"#, in: line) != nil
    }

    private static func stripStepNumber(_ line: String) -> String {
        guard let match = firstMatch(#"^(?:passo\s*\d{1,2}\s*[.)ºª°:-]?|\d{1,2}\s*[.)ºª°:-])\s*"#, in: line) else { return line }
        return String(line.dropFirst(match[0].count)).trimmed
    }

    /// Remove marcadores, emojis e pontuação no início da linha.
    private static func stripBullet(_ line: String) -> String {
        String(line.drop { !($0.isLetter || $0.isNumber) }).trimmed
    }

    private static func servings(in text: String) -> Int? {
        guard let match = firstMatch(#"(\d{1,2})\s*(?:porç(?:ões|ão|oes|ao)|doses?|pessoas|servings)"#, in: text) else { return nil }
        return Int(match[1])
    }

    private static func value(for keywords: String, in text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        let number = #"(\d+(?:[.,]\d+)?)"#
        let patterns = [
            number + #"\s*(?:g|gr|kcal)?\s*(?:de\s+)?(?:"# + keywords + #")"#,
            #"(?:"# + keywords + #")[^\d\n]{0,15}"# + number,
        ]
        for pattern in patterns {
            if let match = firstMatch(pattern, in: text), let value = Double(match[1].replacingOccurrences(of: ",", with: ".")) {
                return value
            }
        }
        return nil
    }

    private static func firstLink(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, range: range)?.url?.absoluteString
    }

    /// Devolve o texto completo da correspondência e de cada grupo (grupos em falta ficam como "").
    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            return range.location == NSNotFound ? "" : nsText.substring(with: range)
        }
    }
}
