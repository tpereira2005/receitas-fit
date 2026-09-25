import Foundation
import SwiftData
import SwiftUI

/// Valores nutricionais. Nos alimentos são por 100 g/ml; nas receitas são por porção.
nonisolated struct NutritionFacts: Hashable, Codable, Sendable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var sugars: Double = 0
    var fat: Double = 0
    var saturatedFat: Double = 0
    var fiber: Double = 0
    var salt: Double = 0

    static let zero = NutritionFacts()

    static func + (lhs: NutritionFacts, rhs: NutritionFacts) -> NutritionFacts {
        NutritionFacts(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            sugars: lhs.sugars + rhs.sugars,
            fat: lhs.fat + rhs.fat,
            saturatedFat: lhs.saturatedFat + rhs.saturatedFat,
            fiber: lhs.fiber + rhs.fiber,
            salt: lhs.salt + rhs.salt
        )
    }

    func scaled(by factor: Double) -> NutritionFacts {
        NutritionFacts(
            calories: calories * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            sugars: sugars * factor,
            fat: fat * factor,
            saturatedFat: saturatedFat * factor,
            fiber: fiber * factor,
            salt: salt * factor
        )
    }

    /// Energia estimada a partir dos macros (fatores da UE: 4/4/9 e 2 para a fibra).
    var estimatedCalories: Double { protein * 4 + carbs * 4 + fat * 9 + fiber * 2 }

    var isEmpty: Bool { calories == 0 && protein == 0 && carbs == 0 && fat == 0 }
}

nonisolated enum FoodCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case protein, dairy, grains, fruit, vegetables, fats, supplements, condiments, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protein: "Carne, peixe e ovos"
        case .dairy: "Laticínios e bebidas vegetais"
        case .grains: "Cereais, pão e tubérculos"
        case .fruit: "Fruta"
        case .vegetables: "Legumes e verduras"
        case .fats: "Gorduras, frutos secos e sementes"
        case .supplements: "Suplementos"
        case .condiments: "Temperos, molhos e doces"
        case .other: "Outros"
        }
    }

    var shortTitle: String {
        switch self {
        case .protein: "Proteínas"
        case .dairy: "Laticínios"
        case .grains: "Cereais"
        case .fruit: "Fruta"
        case .vegetables: "Legumes"
        case .fats: "Gorduras"
        case .supplements: "Suplementos"
        case .condiments: "Temperos"
        case .other: "Outros"
        }
    }

    var symbol: String {
        switch self {
        case .protein: "fish.fill"
        case .dairy: "cup.and.saucer.fill"
        case .grains: "basket.fill"
        case .fruit: "leaf.fill"
        case .vegetables: "carrot.fill"
        case .fats: "drop.fill"
        case .supplements: "dumbbell.fill"
        case .condiments: "sparkles"
        case .other: "square.grid.2x2.fill"
        }
    }

    /// Ícone desenhado para a app (quando não há um SF Symbol adequado).
    var assetName: String? {
        switch self {
        case .protein: "glyph.drumstick"
        case .dairy: "glyph.milk"
        case .grains: "glyph.wheat"
        case .fruit: "glyph.apple"
        default: nil
        }
    }

    /// Ícone da categoria: desenhado para a app ou SF Symbol.
    var glyph: Image {
        assetName.map { Image($0) } ?? Image(systemName: symbol)
    }

    var color: Color {
        switch self {
        case .protein: .red
        case .dairy: .blue
        case .grains: .brown
        case .fruit: .pink
        case .vegetables: .green
        case .fats: .yellow
        case .supplements: .purple
        case .condiments: .orange
        case .other: .gray
        }
    }
}

/// Porção com nome definida pelo utilizador para um alimento (por exemplo "scoop" = 30 g).
nonisolated struct FoodPortion: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    /// Nome de uma porção, no singular e sem número ("scoop", "fatia", "iogurte").
    var name: String
    /// Peso (g ou ml, conforme a base do alimento) de uma porção.
    var grams: Double

    init(id: UUID = UUID(), name: String, grams: Double) {
        self.id = id
        self.name = name
        self.grams = grams
    }

    /// Plural simples do português, acima de 1: "0,5 fatia", "2 fatias", "2 barras proteicas", "2 fatias de pão".
    /// As palavras depois de "de", "com"… ficam como estão.
    static func pluralize(_ name: String, amount: Double) -> String {
        guard amount > 1, !name.isEmpty else { return name }
        let stops: Set<String> = ["de", "do", "da", "dos", "das", "com", "sem", "em", "para"]
        var words = name.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        for index in words.indices {
            if stops.contains(words[index].lowercased()) { break }
            words[index] = pluralWord(words[index])
        }
        return words.joined(separator: " ")
    }

    private static func pluralWord(_ word: String) -> String {
        let lower = word.lowercased()
        guard let last = lower.last else { return word }
        if last == "s" || last == "x" || !last.isLetter { return word }
        if lower == "pão" { return String(word.dropLast(2)) + "ães" }
        if lower.hasSuffix("ão") { return String(word.dropLast(2)) + "ões" }
        if lower.hasSuffix("al") { return String(word.dropLast()) + "is" }
        if last == "m" { return String(word.dropLast()) + "ns" }
        if last == "r" || last == "z" { return word + "es" }
        return word + "s"
    }
}

/// Base dos valores do rótulo: por 100 g ou por 100 ml.
nonisolated enum MeasureBase: String, CaseIterable, Identifiable, Codable, Sendable {
    case grams = "g"
    case milliliters = "ml"

    var id: String { rawValue }
    var title: String { self == .grams ? "Por 100 g" : "Por 100 ml" }
    var short: String { self == .grams ? "100 g" : "100 ml" }
}

/// Unidades disponíveis para indicar a quantidade de um ingrediente numa receita.
nonisolated enum IngredientUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case gram = "g"
    case milliliter = "ml"
    case unit = "un"
    case tablespoon = "c. sopa"
    case teaspoon = "c. chá"
    case toTaste = "q.b."

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gram: "Gramas (g)"
        case .milliliter: "Mililitros (ml)"
        case .unit: "Unidades"
        case .tablespoon: "Colheres de sopa"
        case .teaspoon: "Colheres de chá"
        case .toTaste: "Q.b. (a gosto)"
        }
    }

    static func available(for food: Food) -> [IngredientUnit] {
        var units: [IngredientUnit] = [food.measureBase == .grams ? .gram : .milliliter]
        if (food.unitWeight ?? 0) > 0 { units.append(.unit) }
        units.append(contentsOf: [.tablespoon, .teaspoon, .toTaste])
        return units
    }

    /// Peso de uma colher quando o alimento não indica outro.
    static let defaultTablespoon: Double = 15
    static let defaultTeaspoon: Double = 5
}

/// Medida escolhida para um ingrediente: uma unidade comum ou uma porção com nome do alimento.
nonisolated enum IngredientMeasure: Hashable, Identifiable, Sendable {
    case unit(IngredientUnit)
    case portion(FoodPortion)

    var id: String {
        switch self {
        case .unit(let unit): unit.rawValue
        case .portion(let portion): portion.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .unit(let unit): unit.title
        case .portion(let portion): portion.name.prefix(1).uppercased() + portion.name.dropFirst()
        }
    }
}

@Model
final class Food {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var categoryRaw: String = "other"  // FoodCategory.other
    var measureBaseRaw: String = "g"  // MeasureBase.grams
    /// Peso (g ou ml) de uma unidade, p. ex. 1 ovo ≈ 60 g. Opcional.
    var unitWeight: Double?
    /// Imagem personalizada (PNG), usada no lugar do ícone da categoria.
    @Attribute(.externalStorage) var imageData: Data?

    // Valores por 100 g ou 100 ml
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var sugars: Double = 0
    var fat: Double = 0
    var saturatedFat: Double = 0
    var fiber: Double = 0
    var salt: Double = 0

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Esquema V2
    /// Porções com nome (por exemplo "1 scoop = 30 g"), guardadas como JSON.
    var portionsData: Data = Data()
    /// Peso de uma colher de sopa / de chá deste alimento, se for diferente de 15 g / 5 g.
    var tablespoonWeight: Double?
    var teaspoonWeight: Double?

    // Esquema V3
    /// Data em que foi apagado; fica em "Apagadas recentemente" durante 30 dias.
    var deletedAt: Date?

    init(name: String = "", category: FoodCategory = .other) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var measureBase: MeasureBase {
        get { MeasureBase(rawValue: measureBaseRaw) ?? .grams }
        set { measureBaseRaw = newValue.rawValue }
    }

    var per100: NutritionFacts {
        get {
            NutritionFacts(calories: calories, protein: protein, carbs: carbs, sugars: sugars,
                           fat: fat, saturatedFat: saturatedFat, fiber: fiber, salt: salt)
        }
        set {
            calories = newValue.calories
            protein = newValue.protein
            carbs = newValue.carbs
            sugars = newValue.sugars
            fat = newValue.fat
            saturatedFat = newValue.saturatedFat
            fiber = newValue.fiber
            salt = newValue.salt
        }
    }

    var portions: [FoodPortion] {
        get { JSONCache.decode([FoodPortion].self, from: portionsData) }
        set { portionsData = newValue.isEmpty ? Data() : JSONCache.encode(newValue) }
    }

    /// Medidas que se podem usar nas receitas: base, porções com nome, unidade, colheres e q.b.
    var measures: [IngredientMeasure] {
        let units = IngredientUnit.available(for: self)
        return [.unit(units[0])] + portions.map { .portion($0) } + units.dropFirst().map { .unit($0) }
    }

    /// Peso de uma medida deste alimento (para mostrar "1 scoop = 30 g").
    func grams(of measure: IngredientMeasure) -> Double? {
        switch measure {
        case .portion(let portion): portion.grams
        case .unit(.unit): unitWeight
        case .unit(.tablespoon): tablespoonWeight ?? IngredientUnit.defaultTablespoon
        case .unit(.teaspoon): teaspoonWeight ?? IngredientUnit.defaultTeaspoon
        case .unit: nil
        }
    }

    /// "P 23 · H 0 · G 1,5" — resumo curto dos macros por 100 g/ml.
    var macroSummary: String {
        "P \(protein.cleanString) · H \(carbs.cleanString) · G \(fat.cleanString)"
    }
}

/// Cópia dos dados de um alimento guardada em cada ingrediente de uma receita.
/// Assim, editar um alimento na biblioteca nunca altera uma receita sem o utilizador aceitar.
nonisolated struct FoodSnapshot: Codable, Hashable, Sendable {
    var name: String
    var base: String
    var unitWeight: Double?
    var per100: NutritionFacts
    // Desde a versão 1.3. Ficam `nil` quando não estão definidos, para que as cópias antigas
    // continuem iguais às novas de um alimento que não mudou.
    var portions: [FoodPortion]?
    var tablespoonWeight: Double?
    var teaspoonWeight: Double?

    init(food: Food) {
        name = food.name
        base = food.measureBaseRaw
        unitWeight = food.unitWeight
        per100 = food.per100
        let portions = food.portions
        self.portions = portions.isEmpty ? nil : portions
        tablespoonWeight = food.tablespoonWeight
        teaspoonWeight = food.teaspoonWeight
    }

    func portion(_ id: UUID?) -> FoodPortion? {
        guard let id else { return nil }
        return portions?.first { $0.id == id }
    }

    /// Gramas (ou ml) de um ingrediente com estes valores; `nil` se não houver conversão.
    func grams(for ingredient: Ingredient) -> Double? {
        if let portionID = ingredient.portionID {
            guard let amount = ingredient.amount, let portion = portion(portionID), portion.grams > 0 else { return nil }
            return amount * portion.grams
        }
        return NutritionCalculator.grams(
            amount: ingredient.amount,
            unit: ingredient.unit,
            unitWeight: unitWeight,
            tablespoon: tablespoonWeight,
            teaspoon: teaspoonWeight
        )
    }

    /// Sabe converter esta medida? (Uma cópia antiga pode não ter uma porção criada depois.)
    func supports(_ measure: IngredientMeasure) -> Bool {
        switch measure {
        case .portion(let portion): self.portion(portion.id) != nil
        case .unit(.unit): (unitWeight ?? 0) > 0
        case .unit: true
        }
    }
}

/// Cópia editável de um alimento.
struct FoodDraft: Equatable {
    var name = ""
    var brand = ""
    var category: FoodCategory = .other
    var base: MeasureBase = .grams
    var unitWeight: Double?
    var facts = NutritionFacts()
    var imageData: Data?
    var portions: [FoodPortion] = []
    var tablespoonWeight: Double?
    var teaspoonWeight: Double?

    init() {}

    init(food: Food) {
        name = food.name
        brand = food.brand
        category = food.category
        base = food.measureBase
        unitWeight = food.unitWeight
        facts = food.per100
        imageData = food.imageData
        portions = food.portions
        tablespoonWeight = food.tablespoonWeight
        teaspoonWeight = food.teaspoonWeight
    }

    /// Porções completas (com nome e peso); as linhas por preencher são ignoradas ao guardar.
    var validPortions: [FoodPortion] {
        portions
            .map { FoodPortion(id: $0.id, name: $0.name.trimmed, grams: $0.grams) }
            .filter { !$0.name.isEmpty && $0.grams > 0 }
    }

    var isValid: Bool { !name.trimmed.isEmpty }

    /// Descrição legível do que mudou em relação a `original` (só dados que afetam as receitas).
    func changes(from original: FoodDraft) -> [String] {
        var lines: [String] = []
        if name.trimmed != original.name.trimmed {
            lines.append("Nome: \(original.name.trimmed) → \(name.trimmed)")
        }
        if base != original.base {
            lines.append("Valores: \(original.base.title.lowercased()) → \(base.title.lowercased())")
        }
        let oldWeight = (original.unitWeight ?? 0) > 0 ? original.unitWeight : nil
        let newWeight = (unitWeight ?? 0) > 0 ? unitWeight : nil
        if oldWeight != newWeight {
            let describe: (Double?) -> String = { $0.map { "\($0.cleanString) \(base.rawValue)" } ?? "—" }
            lines.append("Peso de 1 unidade: \(describe(oldWeight)) → \(describe(newWeight))")
        }
        let nutrients: [(String, String, KeyPath<NutritionFacts, Double>)] = [
            ("Energia", "kcal", \.calories),
            ("Lípidos", "g", \.fat),
            ("Saturados", "g", \.saturatedFat),
            ("Hidratos", "g", \.carbs),
            ("Açúcares", "g", \.sugars),
            ("Fibra", "g", \.fiber),
            ("Proteína", "g", \.protein),
            ("Sal", "g", \.salt),
        ]
        for (title, unit, keyPath) in nutrients where facts[keyPath: keyPath] != original.facts[keyPath: keyPath] {
            lines.append("\(title): \(original.facts[keyPath: keyPath].cleanString) → \(facts[keyPath: keyPath].cleanString) \(unit)")
        }
        let spoons: [(String, Double?, Double?, Double)] = [
            ("Colher de sopa", original.tablespoonWeight, tablespoonWeight, IngredientUnit.defaultTablespoon),
            ("Colher de chá", original.teaspoonWeight, teaspoonWeight, IngredientUnit.defaultTeaspoon),
        ]
        for (title, old, new, fallback) in spoons {
            let oldValue = old.flatMap { $0 > 0 ? $0 : nil } ?? fallback
            let newValue = new.flatMap { $0 > 0 ? $0 : nil } ?? fallback
            if oldValue != newValue {
                lines.append("\(title): \(oldValue.cleanString) → \(newValue.cleanString) \(base.rawValue)")
            }
        }
        let oldPortions = Dictionary(original.validPortions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newPortions = validPortions
        for portion in newPortions {
            if let old = oldPortions[portion.id] {
                if old != portion {
                    lines.append("Porção: 1 \(old.name) = \(old.grams.cleanString) \(base.rawValue) → 1 \(portion.name) = \(portion.grams.cleanString) \(base.rawValue)")
                }
            } else {
                lines.append("Nova porção: 1 \(portion.name) = \(portion.grams.cleanString) \(base.rawValue)")
            }
        }
        let kept = Set(newPortions.map(\.id))
        for old in original.validPortions where !kept.contains(old.id) {
            lines.append("Porção removida: 1 \(old.name)")
        }
        return lines
    }

    func apply(to food: Food) {
        food.name = name.trimmed
        food.brand = brand.trimmed
        food.category = category
        food.measureBase = base
        if food.imageData != imageData {
            food.imageData = imageData
        }
        if let unitWeight, unitWeight > 0 {
            food.unitWeight = unitWeight
        } else {
            food.unitWeight = nil
        }
        food.tablespoonWeight = tablespoonWeight.flatMap { $0 > 0 ? $0 : nil }
        food.teaspoonWeight = teaspoonWeight.flatMap { $0 > 0 ? $0 : nil }
        food.portions = validPortions
        food.per100 = NutritionFacts(
            calories: max(0, facts.calories),
            protein: max(0, facts.protein),
            carbs: max(0, facts.carbs),
            sugars: max(0, facts.sugars),
            fat: max(0, facts.fat),
            saturatedFat: max(0, facts.saturatedFat),
            fiber: max(0, facts.fiber),
            salt: max(0, facts.salt)
        )
        food.updatedAt = .now
    }
}
