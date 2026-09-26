import Foundation

/// Cópia editável de uma receita. Só é aplicada ao modelo quando o utilizador carrega em Guardar.
struct RecipeDraft: Equatable {
    var title = ""
    var summary = ""
    var category: RecipeCategory = .lunch
    var tags: [String] = []
    var servings = 1
    var prepMinutes = 0
    var cookMinutes = 0
    var waitMinutes = 0
    var waitKind: WaitKind = .freezer
    /// Nome de uma porção ("" = porção).
    var servingName = ""
    var sourceURL = ""
    var notes = ""
    var ingredients: [Ingredient] = []
    var steps: [RecipeStep] = []
    var photoData: Data?
    var thumbnailData: Data?
    /// Ponto de foco da fotografia (0…1), que fica sempre à vista nos recortes.
    var photoFocusX = 0.5
    var photoFocusY = 0.5
    var photoZoom = 1.0
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
        waitMinutes = recipe.waitMinutes
        waitKind = recipe.waitKind ?? .freezer
        servingName = recipe.servingName
        sourceURL = recipe.sourceURL
        notes = recipe.notes
        ingredients = recipe.ingredients
        steps = recipe.steps
        photoData = recipe.photoData
        thumbnailData = recipe.thumbnailData
        photoFocusX = recipe.photoFocusX
        photoFocusY = recipe.photoFocusY
        photoZoom = recipe.photoZoom
        legacyNutrition = recipe.nutritionIsComputed ? .zero : recipe.perServing
    }

    /// Cópia de uma receita para guardar como receita nova (o título indica que é uma cópia).
    init(duplicating recipe: Recipe) {
        self.init(recipe: recipe)
        title = "\(recipe.title.trimmed) (cópia)"
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
        recipe.waitMinutes = max(0, waitMinutes)
        recipe.waitKind = waitMinutes > 0 ? waitKind : nil
        let noun = ServingName.noun(servingName)
        recipe.servingName = noun == "porção" ? "" : noun
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
        recipe.photoFocusX = min(1, max(0, photoFocusX))
        recipe.photoFocusY = min(1, max(0, photoFocusY))
        recipe.photoZoom = min(FocusedImage.maxZoom, max(1, photoZoom))
        NutritionCalculator.update(recipe, foods: foods)
        // Uma receita de exemplo editada passa a ser do utilizador (não é apagada com os exemplos).
        recipe.isSample = false
        recipe.updatedAt = .now
    }
}
