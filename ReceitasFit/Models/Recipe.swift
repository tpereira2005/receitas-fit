import Foundation
import SwiftData

nonisolated struct Ingredient: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    var amount: Double?
    var unit: String
    /// Alimento da biblioteca de onde veio este ingrediente. `nil` em ingredientes antigos.
    var foodID: UUID?
    /// Valores do alimento no momento em que foi adicionado (ou atualizado com autorização do utilizador).
    var snapshot: FoodSnapshot?
    /// Porção com nome do alimento usada como medida (desde a versão 1.3); `unit` guarda o nome dela.
    var portionID: UUID?

    init(id: UUID = UUID(), name: String = "", amount: Double? = nil, unit: String = "", foodID: UUID? = nil,
         snapshot: FoodSnapshot? = nil, portionID: UUID? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.foodID = foodID
        self.snapshot = snapshot
        self.portionID = portionID
    }

    /// Cria um ingrediente a partir de um alimento da biblioteca, guardando os valores atuais.
    init(food: Food, amount: Double?, unit: IngredientUnit, id: UUID = UUID()) {
        self.init(food: food, amount: amount, measure: .unit(unit), id: id)
    }

    /// Cria um ingrediente com uma medida do alimento. `snapshot` permite manter valores anteriores.
    init(food: Food, amount: Double?, measure: IngredientMeasure, id: UUID = UUID(), snapshot: FoodSnapshot? = nil) {
        let values = snapshot ?? FoodSnapshot(food: food)
        switch measure {
        case .unit(let unit):
            self.init(id: id, name: values.name, amount: unit == .toTaste ? nil : amount, unit: unit.rawValue,
                      foodID: food.id, snapshot: values)
        case .portion(let portion):
            self.init(id: id, name: values.name, amount: amount, unit: portion.name,
                      foodID: food.id, snapshot: values, portionID: portion.id)
        }
    }

    /// Medida usada por este ingrediente, se for uma das conhecidas.
    var measure: IngredientMeasure? {
        if let portionID {
            return snapshot?.portion(portionID).map { .portion($0) }
        }
        return IngredientUnit(rawValue: unit).map { .unit($0) }
    }
}

nonisolated struct RecipeStep: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

@Model
final class Recipe {
    var id: UUID = UUID()
    var title: String = ""
    var summary: String = ""
    var categoryRaw: String = "lunch"  // RecipeCategory.lunch
    var tags: [String] = []
    var servings: Int = 1
    var prepMinutes: Int = 0
    var cookMinutes: Int = 0

    // Nutrição por porção (calculada a partir da biblioteca de alimentos)
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sugars: Double = 0
    var saturatedFat: Double = 0
    var salt: Double = 0
    /// `true` quando os valores vêm da biblioteca de alimentos; `false` em receitas antigas com valores manuais.
    var nutritionIsComputed: Bool = false

    var sourceURL: String = ""
    var notes: String = ""
    var isFavorite: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Attribute(.externalStorage) var photoData: Data?
    var thumbnailData: Data?

    // Guardados como JSON para manter a ordem e evitar surpresas do SwiftData com arrays de structs.
    var ingredientsData: Data = Data()
    var stepsData: Data = Data()

    // Esquema V2
    /// Receita de exemplo criada pela app (pode ser removida em bloco nas Definições).
    var isSample: Bool = false
    /// Datas em que o utilizador marcou "Fiz esta receita".
    var cookedDates: [Date] = []
    /// Ponto de foco da fotografia (0…1), usado em todos os recortes.
    var photoFocusX: Double = 0.5
    var photoFocusY: Double = 0.5

    init(title: String = "", category: RecipeCategory = .lunch) {
        self.id = UUID()
        self.title = title
        self.categoryRaw = category.rawValue
        self.createdAt = .now
        self.updatedAt = .now
    }

    var category: RecipeCategory {
        get { RecipeCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var ingredients: [Ingredient] {
        get { JSONCache.decode([Ingredient].self, from: ingredientsData) }
        set { ingredientsData = JSONCache.encode(newValue) }
    }

    var steps: [RecipeStep] {
        get { JSONCache.decode([RecipeStep].self, from: stepsData) }
        set { stepsData = JSONCache.encode(newValue) }
    }

    var totalMinutes: Int { prepMinutes + cookMinutes }

    var timesCooked: Int { cookedDates.count }
    var lastCookedAt: Date? { cookedDates.max() }

    /// Valores por porção guardados na receita.
    var perServing: NutritionFacts {
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
}

// MARK: - Apresentação

extension Recipe {
    /// Linha curta mostrada por baixo do título nos cartões.
    var cardFacts: String {
        var parts: [String] = []
        if protein > 0 { parts.append("\(protein.cleanString) g proteína") }
        if totalMinutes > 0 { parts.append(Format.minutes(totalMinutes)) }
        return parts.isEmpty ? category.title : parts.joined(separator: " · ")
    }

    var quickFacts: String {
        var parts: [String] = []
        if calories > 0 { parts.append("\(Int(calories.rounded())) kcal") }
        if protein > 0 { parts.append("\(protein.cleanString) g prot.") }
        if totalMinutes > 0 { parts.append(Format.minutes(totalMinutes)) }
        return parts.isEmpty ? category.title : parts.joined(separator: " · ")
    }

    var sourceLink: URL? {
        let trimmed = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme.hasPrefix("http") else { return nil }
        return url
    }

    var shareText: String {
        var lines: [String] = [title]
        if !summary.isEmpty { lines.append(summary) }
        lines.append("")
        lines.append("Ingredientes (\(Format.servings(servings))):")
        lines.append(contentsOf: ingredients.map { "• \($0.displayText())" })
        lines.append("")
        lines.append("Preparação:")
        lines.append(contentsOf: steps.enumerated().map { "\($0.offset + 1). \($0.element.text)" })
        if calories > 0 || protein > 0 {
            lines.append("")
            lines.append("Por porção: \(Int(calories.rounded())) kcal · Proteína \(protein.cleanString) g · Hidratos \(carbs.cleanString) g (açúcares \(sugars.cleanString) g) · Gordura \(fat.cleanString) g (saturada \(saturatedFat.cleanString) g)")
        }
        if let link = sourceLink {
            lines.append("")
            lines.append(link.absoluteString)
        }
        return lines.joined(separator: "\n")
    }

    var searchIndex: String {
        ([title, summary, category.title, notes] + tags + ingredients.map(\.name))
            .joined(separator: " ")
            .searchNormalized
    }

    func matches(query: String) -> Bool {
        let tokens = query.searchNormalized.split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else { return true }
        let index = searchIndex
        return tokens.allSatisfy { index.contains($0) }
    }
}

nonisolated extension Ingredient {
    /// Quantidade formatada (já com a escala das porções aplicada), p. ex. "150 g".
    func amountText(scale: Double = 1) -> String? {
        guard let amount, amount > 0 else { return nil }
        let value = amount * scale
        let number = value.formatted(.number.precision(.fractionLength(0...(value < 10 ? 2 : 0))))
        let unitText = portionID == nil ? unit : FoodPortion.pluralize(unit, amount: value)
        return unitText.isEmpty ? number : "\(number) \(unitText)"
    }

    func displayText(scale: Double = 1) -> String {
        if let amount = amountText(scale: scale) {
            return "\(amount) \(name)"
        }
        return unit.isEmpty ? name : "\(name) \(unit)"
    }
}
