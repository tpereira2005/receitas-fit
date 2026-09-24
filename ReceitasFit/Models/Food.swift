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

/// Porção com nome definida pelo utilizador para um alimento (por exemplo "1 scoop" = 30 g).
nonisolated struct FoodPortion: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    /// Peso (g ou ml, conforme a base do alimento) de uma porção.
    var grams: Double

    init(id: UUID = UUID(), name: String, grams: Double) {
        self.id = id
        self.name = name
        self.grams = grams
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
        set { portionsData = JSONCache.encode(newValue) }
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

    init(food: Food) {
        name = food.name
        base = food.measureBaseRaw
        unitWeight = food.unitWeight
        per100 = food.per100
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

    init() {}

    init(food: Food) {
        name = food.name
        brand = food.brand
        category = food.category
        base = food.measureBase
        unitWeight = food.unitWeight
        facts = food.per100
        imageData = food.imageData
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
