import Foundation
import SwiftData

struct Ingredient: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var amount: Double?
    var unit: String
    /// Alimento da biblioteca que fornece os valores nutricionais. `nil` em ingredientes antigos.
    var foodID: UUID?

    init(id: UUID = UUID(), name: String = "", amount: Double? = nil, unit: String = "", foodID: UUID? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.foodID = foodID
    }
}

struct RecipeStep: Codable, Hashable, Identifiable {
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
    var categoryRaw: String = RecipeCategory.lunch.rawValue
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
        get { (try? JSONDecoder().decode([Ingredient].self, from: ingredientsData)) ?? [] }
        set { ingredientsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var steps: [RecipeStep] {
        get { (try? JSONDecoder().decode([RecipeStep].self, from: stepsData)) ?? [] }
        set { stepsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var totalMinutes: Int { prepMinutes + cookMinutes }

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

extension Ingredient {
    /// Quantidade formatada (já com a escala das porções aplicada), p. ex. "150 g".
    func amountText(scale: Double = 1) -> String? {
        guard let amount, amount > 0 else { return nil }
        let value = amount * scale
        let number = value.formatted(.number.precision(.fractionLength(0...(value < 10 ? 2 : 0))))
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    func displayText(scale: Double = 1) -> String {
        if let amount = amountText(scale: scale) {
            return "\(amount) \(name)"
        }
        return unit.isEmpty ? name : "\(name) \(unit)"
    }
}
