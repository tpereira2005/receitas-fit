import Foundation
import SwiftData

/// Calcula os valores nutricionais das receitas a partir da biblioteca de alimentos.
enum NutritionCalculator {
    struct Summary {
        var total = NutritionFacts.zero
        /// Ingredientes ligados a um alimento da biblioteca.
        var linked = 0
        /// Ingredientes que não contam para o total (sem alimento ou sem conversão possível).
        var unresolved = 0
    }

    static func index(_ foods: [Food]) -> [UUID: Food] {
        Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Converte a quantidade do ingrediente em gramas (ou ml) do alimento.
    static func grams(amount: Double?, unit: String, food: Food) -> Double? {
        guard let unit = IngredientUnit(rawValue: unit) else { return nil }
        switch unit {
        case .toTaste:
            return 0
        case .gram, .milliliter:
            return amount
        case .unit:
            guard let amount, let weight = food.unitWeight, weight > 0 else { return nil }
            return amount * weight
        case .tablespoon:
            return amount.map { $0 * 15 }
        case .teaspoon:
            return amount.map { $0 * 5 }
        }
    }

    static func facts(for ingredient: Ingredient, food: Food?) -> NutritionFacts? {
        guard let food, let grams = grams(amount: ingredient.amount, unit: ingredient.unit, food: food) else { return nil }
        return food.per100.scaled(by: grams / 100)
    }

    static func summarize(_ ingredients: [Ingredient], foods: [UUID: Food]) -> Summary {
        var summary = Summary()
        for ingredient in ingredients {
            let food = ingredient.foodID.flatMap { foods[$0] }
            if food != nil { summary.linked += 1 }
            if let facts = facts(for: ingredient, food: food) {
                summary.total = summary.total + facts
            } else {
                summary.unresolved += 1
            }
        }
        return summary
    }

    /// Atualiza os valores por porção guardados na receita (usados nos cartões, filtros e ordenação).
    /// Receitas antigas sem ingredientes ligados mantêm os valores introduzidos à mão.
    static func update(_ recipe: Recipe, foods: [UUID: Food]) {
        var ingredients = recipe.ingredients
        var renamed = false
        for index in ingredients.indices {
            if let id = ingredients[index].foodID, let food = foods[id], ingredients[index].name != food.name {
                ingredients[index].name = food.name
                renamed = true
            }
        }
        if renamed { recipe.ingredients = ingredients }

        let summary = summarize(ingredients, foods: foods)
        guard summary.linked > 0 || recipe.nutritionIsComputed else { return }
        recipe.perServing = summary.total.scaled(by: 1 / Double(max(1, recipe.servings)))
        recipe.nutritionIsComputed = true
    }

    /// Recalcula todas as receitas; chamado quando um alimento é editado ou apagado.
    @MainActor
    static func refreshAllRecipes(in context: ModelContext) {
        let foods = (try? context.fetch(FetchDescriptor<Food>())) ?? []
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        let foodIndex = index(foods)
        for recipe in recipes where recipe.nutritionIsComputed || recipe.ingredients.contains(where: { $0.foodID != nil }) {
            update(recipe, foods: foodIndex)
        }
        try? context.save()
    }
}

/// Liga ingredientes antigos (só com nome) aos alimentos da biblioteca.
enum FoodMatcher {
    private static let stopWords: Set<String> = ["de", "do", "da", "dos", "das", "e", "em", "com", "sem", "a", "o", "ao"]

    static func words(_ text: String) -> Set<String> {
        let withoutParentheses = text.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        let tokens = withoutParentheses.searchNormalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
            .map { $0.count > 3 && $0.hasSuffix("s") ? String($0.dropLast()) : $0 }
        return Set(tokens)
    }

    /// Devolve o alimento cujas palavras estão todas contidas no nome do ingrediente (o mais específico ganha).
    static func match(_ ingredientName: String, in foods: [Food]) -> Food? {
        let ingredientWords = words(ingredientName)
        guard !ingredientWords.isEmpty else { return nil }
        var best: (food: Food, score: Int)?
        for food in foods {
            let foodWords = words(food.name)
            guard !foodWords.isEmpty, foodWords.isSubset(of: ingredientWords) else { continue }
            if best == nil || foodWords.count > best!.score {
                best = (food, foodWords.count)
            }
        }
        return best?.food
    }
}
