import Foundation
import SwiftData

/// Calcula os valores nutricionais das receitas.
///
/// Cada ingrediente guarda uma cópia (`FoodSnapshot`) dos valores do alimento. Os cálculos usam sempre
/// essa cópia, por isso editar um alimento na biblioteca só altera uma receita quando o utilizador aceita.
enum NutritionCalculator {
    struct Summary {
        var total = NutritionFacts.zero
        /// Ingredientes com valores nutricionais (ligados a um alimento).
        var linked = 0
        /// Ingredientes que não contam para o total (sem alimento ou sem conversão possível).
        var unresolved = 0
    }

    static func index(_ foods: [Food]) -> [UUID: Food] {
        Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Converte a quantidade do ingrediente em gramas (ou ml).
    /// As colheres usam o peso indicado no alimento ou, se não houver, 15 g e 5 g.
    nonisolated static func grams(
        amount: Double?,
        unit: String,
        unitWeight: Double?,
        tablespoon: Double? = nil,
        teaspoon: Double? = nil
    ) -> Double? {
        guard let unit = IngredientUnit(rawValue: unit) else { return nil }
        switch unit {
        case .toTaste:
            return 0
        case .gram, .milliliter:
            return amount
        case .unit:
            guard let amount, let unitWeight, unitWeight > 0 else { return nil }
            return amount * unitWeight
        case .tablespoon:
            let weight = tablespoon.flatMap { $0 > 0 ? $0 : nil } ?? IngredientUnit.defaultTablespoon
            return amount.map { $0 * weight }
        case .teaspoon:
            let weight = teaspoon.flatMap { $0 > 0 ? $0 : nil } ?? IngredientUnit.defaultTeaspoon
            return amount.map { $0 * weight }
        }
    }

    /// Valores de um ingrediente. Usa a cópia guardada; o alimento só serve de recurso para ingredientes antigos.
    static func facts(for ingredient: Ingredient, food: Food?) -> NutritionFacts? {
        guard let source = ingredient.snapshot ?? food.map(FoodSnapshot.init(food:)),
              let grams = source.grams(for: ingredient)
        else { return nil }
        return source.per100.scaled(by: grams / 100)
    }

    static func summarize(_ ingredients: [Ingredient], foods: [UUID: Food]) -> Summary {
        var summary = Summary()
        for ingredient in ingredients {
            let food = ingredient.foodID.flatMap { foods[$0] }
            if ingredient.snapshot != nil || food != nil { summary.linked += 1 }
            if let facts = facts(for: ingredient, food: food) {
                summary.total = summary.total + facts
            } else {
                summary.unresolved += 1
            }
        }
        return summary
    }

    /// Guarda a cópia dos valores nos ingredientes ligados que ainda não a têm (receitas de versões anteriores).
    static func fillMissingSnapshots(_ ingredients: [Ingredient], foods: [UUID: Food]) -> [Ingredient] {
        ingredients.map { ingredient in
            guard ingredient.snapshot == nil, let id = ingredient.foodID, let food = foods[id] else { return ingredient }
            var filled = ingredient
            filled.snapshot = FoodSnapshot(food: food)
            return filled
        }
    }

    /// Atualiza os valores por porção guardados na receita (usados nos cartões, filtros e ordenação).
    /// Receitas antigas sem ingredientes ligados mantêm os valores introduzidos à mão.
    static func update(_ recipe: Recipe, foods: [UUID: Food]) {
        let original = recipe.ingredients
        let ingredients = fillMissingSnapshots(original, foods: foods)
        if ingredients != original { recipe.ingredients = ingredients }

        let summary = summarize(ingredients, foods: foods)
        guard summary.linked > 0 || recipe.nutritionIsComputed else { return }
        recipe.perServing = summary.total.scaled(by: 1 / Double(max(1, recipe.servings)))
        recipe.nutritionIsComputed = true
    }

    // MARK: - Alterações a alimentos

    /// Ingredientes que usam valores diferentes dos atuais do alimento.
    /// Só conta o que afeta este ingrediente: nome, valores e o peso da medida que usa
    /// (acrescentar uma porção que a receita não usa não obriga a rever a receita).
    static func isOutdated(_ ingredient: Ingredient, comparedTo food: Food) -> Bool {
        guard ingredient.foodID == food.id else { return false }
        guard let snapshot = ingredient.snapshot else { return true }
        let current = FoodSnapshot(food: food)
        return snapshot.name != current.name
            || snapshot.base != current.base
            || snapshot.per100 != current.per100
            || snapshot.grams(for: ingredient) != current.grams(for: ingredient)
    }

    /// Receitas com pelo menos um ingrediente deste alimento com valores anteriores.
    static func recipesAffected(by food: Food, in recipes: [Recipe]) -> [Recipe] {
        recipes.filter { recipe in recipe.ingredients.contains { isOutdated($0, comparedTo: food) } }
    }

    /// Ingredientes da receita com os valores atuais do alimento.
    static func ingredientsUpdated(_ ingredients: [Ingredient], with food: Food) -> [Ingredient] {
        ingredients.map { ingredient in
            guard ingredient.foodID == food.id else { return ingredient }
            var updated = ingredient
            updated.name = food.name
            updated.snapshot = FoodSnapshot(food: food)
            // Porção renomeada: o texto da medida acompanha o novo nome.
            if let portion = updated.snapshot?.portion(ingredient.portionID) {
                updated.unit = portion.name
            }
            return updated
        }
    }

    /// Valores por porção que a receita teria com os valores atuais do alimento (para pré-visualizar).
    static func preview(_ recipe: Recipe, with food: Food) -> Summary {
        let ingredients = ingredientsUpdated(recipe.ingredients, with: food)
        var summary = summarize(ingredients, foods: [:])
        summary.total = summary.total.scaled(by: 1 / Double(max(1, recipe.servings)))
        return summary
    }

    /// Aplica os valores atuais do alimento às receitas escolhidas pelo utilizador.
    @MainActor
    static func apply(_ food: Food, to recipes: [Recipe], context: ModelContext) {
        for recipe in recipes {
            recipe.ingredients = ingredientsUpdated(recipe.ingredients, with: food)
            update(recipe, foods: [:])
            recipe.updatedAt = .now
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
