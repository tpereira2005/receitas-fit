import Foundation

/// Nutrientes de um rótulo, pela ordem da declaração nutricional europeia.
nonisolated enum Nutrient: String, CaseIterable, Identifiable, Sendable {
    case calories, fat, saturatedFat, carbs, sugars, fiber, protein, salt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calories: "Energia"
        case .fat: "Lípidos"
        case .saturatedFat: "Saturados"
        case .carbs: "Hidratos"
        case .sugars: "Açúcares"
        case .fiber: "Fibra"
        case .protein: "Proteína"
        case .salt: "Sal"
        }
    }

    var unit: String { self == .calories ? "kcal" : "g" }

    var keyPath: WritableKeyPath<NutritionFacts, Double> {
        switch self {
        case .calories: \.calories
        case .fat: \.fat
        case .saturatedFat: \.saturatedFat
        case .carbs: \.carbs
        case .sugars: \.sugars
        case .fiber: \.fiber
        case .protein: \.protein
        case .salt: \.salt
        }
    }
}

/// Valores lidos (por 100 g ou 100 ml); cada nutriente só existe se foi encontrado.
nonisolated struct PartialFacts: Equatable, Sendable {
    var values: [Nutrient: Double] = [:]
    var base: MeasureBase?

    subscript(_ nutrient: Nutrient) -> Double? {
        get { values[nutrient] }
        set { values[nutrient] = newValue }
    }

    var isEmpty: Bool { values.isEmpty }
}

/// Interpreta as linhas de uma tabela nutricional já reconhecidas (uma linha por fila da tabela,
/// com as células separadas). Usa sempre a primeira coluna numérica, que nos rótulos europeus é
/// a de 100 g / 100 ml.
nonisolated enum LabelParser {
    /// Palavras-chave (sem acentos, em minúsculas) em português, inglês, espanhol, francês e alemão.
    /// A ordem importa: "saturados" e "açúcares" são testados antes de "lípidos" e "hidratos".
    private static let keywords: [(Nutrient, [String])] = [
        (.calories, ["energia", "energetico", "energy", "energie", "kcal"]),
        (.saturatedFat, ["saturad", "saturates", "saturated", "saturees", "gesattigte", "saturi"]),
        (.sugars, ["acucar", "sugar", "azucar", "sucre", "zucker", "zuccheri"]),
        (.fat, ["lipido", "gordura", "fat", "grasa", "matieres grasses", "fett", "grassi"]),
        (.carbs, ["hidratos", "carbo", "glucides", "kohlenhydrat", "carboidrati"]),
        (.fiber, ["fibra", "fibre", "fiber", "ballaststoffe"]),
        (.protein, ["proteina", "protein", "eiweiss"]),
        (.salt, ["sal", "salt", "sel", "salz", "sale"]),
    ]

    static func parse(rows: [[String]]) -> PartialFacts {
        var result = PartialFacts()
        let normalizedRows = rows.map { $0.map(normalize) }
        /// Fila onde cada nutriente foi encontrado, e filas com valores mas sem nome reconhecido.
        var rowOf: [Nutrient: Int] = [:]
        var unlabeled: [Int] = []

        for (index, cells) in normalizedRows.enumerated() {
            let joined = cells.joined(separator: " ")
            if result.base == nil {
                if joined.contains("100 ml") || joined.contains("100ml") { result.base = .milliliters }
                else if joined.contains("100 g") || joined.contains("100g") { result.base = .grams }
            }
            guard let (nutrient, labelCell, labelEnd) = match(cells) else {
                unlabeled.append(index)
                continue
            }
            guard result[nutrient] == nil else { continue }
            rowOf[nutrient] = index

            if nutrient == .calories {
                let values = valueCells(cells, from: labelCell, labelEnd: labelEnd)
                if let kcal = first("kcal", in: values) {
                    result[.calories] = kcal
                } else if index + 1 < normalizedRows.count, match(normalizedRows[index + 1]) == nil,
                          let kcal = first("kcal", in: normalizedRows[index + 1]) {
                    // "1620 kJ" numa linha e "383 kcal" na seguinte.
                    result[.calories] = kcal
                } else if let kj = first("kj", in: values) {
                    result[.calories] = (kj / 4.184).rounded()
                }
                continue
            }
            if let value = firstValue(in: cells, from: labelCell, labelEnd: labelEnd) {
                result[nutrient] = value
            }
        }

        // Nome ilegível (p. ex. "Fibra" lida como "-ОГa"): a ordem da declaração europeia é fixa,
        // por isso uma única fila com valores entre os açúcares e as proteínas só pode ser a fibra,
        // e uma logo a seguir às proteínas só pode ser o sal.
        func valueOfSingleRow(after start: Int?, before end: Int?) -> Double? {
            guard let start, let end else { return nil }
            let candidates = unlabeled.filter { $0 > start && $0 < end }
            guard candidates.count == 1 else { return nil }
            let cells = normalizedRows[candidates[0]]
            guard let firstCell = cells.first else { return nil }
            return firstValue(in: cells, from: 0, labelEnd: firstCell.startIndex)
        }
        if result[.fiber] == nil, let value = valueOfSingleRow(after: rowOf[.sugars] ?? rowOf[.carbs], before: rowOf[.protein]) {
            result[.fiber] = value
        }
        if result[.salt] == nil, let protein = rowOf[.protein],
           let value = valueOfSingleRow(after: protein, before: protein + 2) {
            result[.salt] = value
        }
        return result
    }

    // MARK: - Etiquetas

    /// Nutriente da linha, a célula onde está o nome e onde acaba o nome dentro dessa célula.
    private static func match(_ cells: [String]) -> (Nutrient, Int, String.Index)? {
        for (cellIndex, cell) in cells.enumerated() {
            // As etiquetas estão antes dos números; uma célula que começa por número já é valor.
            if cell.first?.isNumber == true || cell.first == "<" { continue }
            for (nutrient, words) in keywords {
                for word in words {
                    guard let range = wordRange(word, in: cell) else { continue }
                    // "kcal" sozinho numa célula só identifica a energia se não houver etiqueta antes.
                    if word == "kcal" && cellIndex > 0 { continue }
                    let end = lastKeywordEnd(in: cell) ?? range.upperBound
                    return (nutrient, cellIndex, end)
                }
            }
        }
        return nil
    }

    /// Procura a palavra no início de uma palavra do texto ("sal" não encontra "salsa" nem "universal").
    private static func wordRange(_ word: String, in text: String) -> Range<String.Index>? {
        var searchStart = text.startIndex
        while let range = text.range(of: word, range: searchStart..<text.endIndex) {
            let startsWord = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetter
            let shortWord = word.count <= 4
            let endsWord = range.upperBound == text.endIndex || !text[range.upperBound].isLetter
            if startsWord && (!shortWord || endsWord) { return range }
            searchStart = range.upperBound
        }
        return nil
    }

    /// Fim da parte de texto da etiqueta (antes do primeiro número), para "Sal 0,48 g" numa só célula.
    private static func lastKeywordEnd(in cell: String) -> String.Index? {
        cell.firstIndex { $0.isNumber || $0 == "<" }
    }

    // MARK: - Valores

    private struct Number {
        let value: Double
        let lessThan: Bool
        let unit: String
    }

    /// Números de um texto com a unidade que se segue ("1569 kj", "0.35 g", "<0.5 g", "6%").
    private static func numbers(in text: String) -> [Number] {
        let pattern = #"(<\s*)?(\d+(?:\.\d+)?)\s*(kcal|kj|mg|g|ml|%)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard let value = Double(ns.substring(with: match.range(at: 2))) else { return nil }
            let lessThan = match.range(at: 1).location != NSNotFound
            let unit = match.range(at: 3).location != NSNotFound ? ns.substring(with: match.range(at: 3)) : ""
            return Number(value: value, lessThan: lessThan, unit: unit)
        }
    }

    /// Texto das células de valores: o resto da célula da etiqueta e as células seguintes.
    private static func valueCells(_ cells: [String], from labelCell: Int, labelEnd: String.Index) -> [String] {
        let rest = String(cells[labelCell][labelEnd...])
        return [rest] + cells.dropFirst(labelCell + 1)
    }

    private static func firstValue(in cells: [String], from labelCell: Int, labelEnd: String.Index) -> Double? {
        for cell in valueCells(cells, from: labelCell, labelEnd: labelEnd) {
            for number in numbers(in: cell) where number.unit != "%" && number.unit != "kj" && number.unit != "kcal" {
                // "<0,5 g" significa quantidade desprezável.
                if number.lessThan { return 0 }
                return number.unit == "mg" ? number.value / 1000 : number.value
            }
        }
        return nil
    }

    /// Primeiro número com esta unidade ("kcal" ou "kj").
    private static func first(_ unit: String, in cells: [String]) -> Double? {
        for cell in cells {
            if let number = numbers(in: cell).first(where: { $0.unit == unit }) { return number.value }
        }
        return nil
    }

    // MARK: - Normalização

    /// Minúsculas, sem acentos, vírgula decimal como ponto e erros típicos do OCR ("O,5" → "0.5").
    static func normalize(_ text: String) -> String {
        var s = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_PT"))
        s = s.replacingOccurrences(of: #"(?<![a-z])[o](?=[.,]\d)"#, with: "0", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?<=\d)\s*[,](?=\d)"#, with: ".", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?<=\d)\s+(?=\d{3}\b)"#, with: "", options: .regularExpression) // "1 569 kJ"
        s = s.replacingOccurrences(of: "kcai", with: "kcal")
        return s
    }
}
