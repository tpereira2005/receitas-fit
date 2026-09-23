import Foundation
import SwiftData
import SwiftUI

/// Valores nutricionais. Nos alimentos são por 100 g/ml; nas receitas são por porção.
struct NutritionFacts: Equatable, Codable {
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

enum FoodCategory: String, CaseIterable, Identifiable, Codable {
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

/// Base dos valores do rótulo: por 100 g ou por 100 ml.
enum MeasureBase: String, CaseIterable, Identifiable, Codable {
    case grams = "g"
    case milliliters = "ml"

    var id: String { rawValue }
    var title: String { self == .grams ? "Por 100 g" : "Por 100 ml" }
    var short: String { self == .grams ? "100 g" : "100 ml" }
}

/// Unidades disponíveis para indicar a quantidade de um ingrediente numa receita.
enum IngredientUnit: String, CaseIterable, Identifiable, Codable {
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
    var categoryRaw: String = FoodCategory.other.rawValue
    var measureBaseRaw: String = MeasureBase.grams.rawValue
    /// Peso (g ou ml) de uma unidade, p. ex. 1 ovo ≈ 60 g. Opcional.
    var unitWeight: Double?

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

    /// "P 23 · H 0 · G 1,5" — resumo curto dos macros por 100 g/ml.
    var macroSummary: String {
        "P \(protein.cleanString) · H \(carbs.cleanString) · G \(fat.cleanString)"
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

    init() {}

    init(food: Food) {
        name = food.name
        brand = food.brand
        category = food.category
        base = food.measureBase
        unitWeight = food.unitWeight
        facts = food.per100
    }

    var isValid: Bool { !name.trimmed.isEmpty }

    func apply(to food: Food) {
        food.name = name.trimmed
        food.brand = brand.trimmed
        food.category = category
        food.measureBase = base
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
