import Foundation

/// Cópia editável de uma receita. Só é aplicada ao modelo quando o utilizador carrega em Guardar.
struct RecipeDraft: Equatable {
    static let suggestedTags = ["Alta proteína", "Low carb", "Meal prep", "Rápida", "Pré-treino", "Pós-treino"]

    var title = ""
    var summary = ""
    var category: RecipeCategory = .lunch
    var tags: [String] = []
    var servings = 1
    var prepMinutes = 0
    var cookMinutes = 0
    var sourceURL = ""
    var notes = ""
    var ingredients: [Ingredient] = []
    var steps: [RecipeStep] = []
    var photoData: Data?
    var thumbnailData: Data?
    /// Valores introduzidos à mão em versões antigas da app (só para mostrar enquanto não há ingredientes ligados).
    var legacyNutrition = NutritionFacts.zero

    init() {}

    init(recipe: Recipe) {
        title = recipe.title
        summary = recipe.summary
        category = recipe.category
        tags = recipe.tags
        servings = recipe.servings
        prepMinutes = recipe.prepMinutes
        cookMinutes = recipe.cookMinutes
        sourceURL = recipe.sourceURL
        notes = recipe.notes
        ingredients = recipe.ingredients
        steps = recipe.steps
        photoData = recipe.photoData
        thumbnailData = recipe.thumbnailData
        legacyNutrition = recipe.nutritionIsComputed ? .zero : recipe.perServing
    }

    var isValid: Bool { !title.trimmed.isEmpty }

    func apply(to recipe: Recipe, foods: [UUID: Food]) {
        recipe.title = title.trimmed
        recipe.summary = summary.trimmed
        recipe.category = category
        recipe.tags = tags
        recipe.servings = max(1, servings)
        recipe.prepMinutes = max(0, prepMinutes)
        recipe.cookMinutes = max(0, cookMinutes)
        recipe.sourceURL = sourceURL.trimmed
        recipe.notes = notes.trimmed
        recipe.ingredients = ingredients
        recipe.steps = steps
            .map { RecipeStep(id: $0.id, text: $0.text.trimmed) }
            .filter { !$0.text.isEmpty }
        if recipe.photoData != photoData {
            recipe.photoData = photoData
            recipe.thumbnailData = thumbnailData
        }
        NutritionCalculator.update(recipe, foods: foods)
        recipe.updatedAt = .now
    }
}
