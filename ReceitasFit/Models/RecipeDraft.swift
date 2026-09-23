import Foundation

/// Cópia editável de uma receita. Só é aplicada ao modelo quando o utilizador carrega em Guardar.
struct RecipeDraft: Equatable {
    static let suggestedTags = ["Alta proteína", "Low carb", "Vegetariana", "Vegan", "Sem glúten", "Sem lactose", "Meal prep", "Rápida", "Pré-treino", "Pós-treino"]

    var title = ""
    var summary = ""
    var category: RecipeCategory = .lunch
    var tags: [String] = []
    var servings = 1
    var prepMinutes = 0
    var cookMinutes = 0
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sourceURL = ""
    var notes = ""
    var ingredients: [Ingredient] = []
    var steps: [RecipeStep] = []
    var photoData: Data?
    var thumbnailData: Data?

    init() {}

    init(recipe: Recipe) {
        title = recipe.title
        summary = recipe.summary
        category = recipe.category
        tags = recipe.tags
        servings = recipe.servings
        prepMinutes = recipe.prepMinutes
        cookMinutes = recipe.cookMinutes
        calories = recipe.calories
        protein = recipe.protein
        carbs = recipe.carbs
        fat = recipe.fat
        fiber = recipe.fiber
        sourceURL = recipe.sourceURL
        notes = recipe.notes
        ingredients = recipe.ingredients
        steps = recipe.steps
        photoData = recipe.photoData
        thumbnailData = recipe.thumbnailData
    }

    var isValid: Bool { !title.trimmed.isEmpty }

    var macroCalories: Double { protein * 4 + carbs * 4 + fat * 9 }

    func apply(to recipe: Recipe) {
        recipe.title = title.trimmed
        recipe.summary = summary.trimmed
        recipe.category = category
        recipe.tags = tags
        recipe.servings = max(1, servings)
        recipe.prepMinutes = max(0, prepMinutes)
        recipe.cookMinutes = max(0, cookMinutes)
        recipe.calories = max(0, calories)
        recipe.protein = max(0, protein)
        recipe.carbs = max(0, carbs)
        recipe.fat = max(0, fat)
        recipe.fiber = max(0, fiber)
        recipe.sourceURL = sourceURL.trimmed
        recipe.notes = notes.trimmed
        recipe.ingredients = ingredients
            .map { var item = $0; item.name = item.name.trimmed; item.unit = item.unit.trimmed; return item }
            .filter { !$0.name.isEmpty }
        recipe.steps = steps
            .map { RecipeStep(id: $0.id, text: $0.text.trimmed) }
            .filter { !$0.text.isEmpty }
        if recipe.photoData != photoData {
            recipe.photoData = photoData
            recipe.thumbnailData = thumbnailData
        }
        recipe.updatedAt = .now
    }

    mutating func merge(_ result: RecipeTextParser.Result) {
        if title.trimmed.isEmpty, let parsedTitle = result.title { title = parsedTitle }
        ingredients.append(contentsOf: result.ingredients)
        steps.append(contentsOf: result.steps)
        if calories == 0, let value = result.calories { calories = value }
        if protein == 0, let value = result.protein { protein = value }
        if carbs == 0, let value = result.carbs { carbs = value }
        if fat == 0, let value = result.fat { fat = value }
        if servings == 1, let value = result.servings { servings = value }
        if sourceURL.trimmed.isEmpty, let link = result.sourceURL { sourceURL = link }
    }
}
