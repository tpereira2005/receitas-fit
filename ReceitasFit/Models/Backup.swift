import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct RecipeBackup: Codable {
    var version = 3
    var exportedAt = Date()
    var recipes: [RecipeDTO]
    /// Ausente nas cópias da versão 1.
    var foods: [FoodDTO]?

    static func encode(recipes: [Recipe], foods: [Food]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let backup = RecipeBackup(recipes: recipes.map(RecipeDTO.init(recipe:)), foods: foods.map(FoodDTO.init(food:)))
        return try encoder.encode(backup)
    }

    struct RestoreResult {
        var recipes = 0
        var foods = 0
    }

    /// Importa os alimentos e as receitas que ainda não existem.
    @MainActor
    static func restore(from data: Data, into context: ModelContext) throws -> RestoreResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(RecipeBackup.self, from: data)

        let existingFoods = Set(((try? context.fetch(FetchDescriptor<Food>())) ?? []).map(\.id))
        let existingRecipes = Set(((try? context.fetch(FetchDescriptor<Recipe>())) ?? []).map(\.id))
        var result = RestoreResult()

        for dto in backup.foods ?? [] where !existingFoods.contains(dto.id) {
            context.insert(dto.makeFood())
            result.foods += 1
        }
        try context.save()
        // Cópias antigas não têm os valores guardados nos ingredientes: usa os dos alimentos importados.
        let foodIndex = NutritionCalculator.index((try? context.fetch(FetchDescriptor<Food>())) ?? [])
        for dto in backup.recipes where !existingRecipes.contains(dto.id) {
            let recipe = dto.makeRecipe()
            if recipe.ingredients.contains(where: { $0.foodID != nil && $0.snapshot == nil }) {
                NutritionCalculator.update(recipe, foods: foodIndex)
            }
            context.insert(recipe)
            result.recipes += 1
        }
        try context.save()
        return result
    }
}

struct FoodDTO: Codable {
    var id: UUID
    var name: String
    var brand: String
    var category: String
    var measureBase: String
    var unitWeight: Double?
    var per100: NutritionFacts
    var createdAt: Date
    /// Ausente em cópias anteriores à versão 1.1.5.
    var imageData: Data?
    /// Ausentes em cópias anteriores à versão 1.2.
    var portions: [FoodPortion]?
    var tablespoonWeight: Double?
    var teaspoonWeight: Double?

    init(food: Food) {
        id = food.id
        name = food.name
        brand = food.brand
        category = food.categoryRaw
        measureBase = food.measureBaseRaw
        unitWeight = food.unitWeight
        per100 = food.per100
        createdAt = food.createdAt
        imageData = food.imageData
        portions = food.portions
        tablespoonWeight = food.tablespoonWeight
        teaspoonWeight = food.teaspoonWeight
    }

    func makeFood() -> Food {
        let food = Food(name: name)
        food.id = id
        food.brand = brand
        food.categoryRaw = category
        food.measureBaseRaw = measureBase
        food.unitWeight = unitWeight
        food.per100 = per100
        food.createdAt = createdAt
        food.imageData = imageData
        food.portions = portions ?? []
        food.tablespoonWeight = tablespoonWeight
        food.teaspoonWeight = teaspoonWeight
        return food
    }
}

struct RecipeDTO: Codable {
    var id: UUID
    var title: String
    var summary: String
    var category: String
    var tags: [String]
    var servings: Int
    var prepMinutes: Int
    var cookMinutes: Int
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    // Opcionais para aceitar cópias da versão 1.
    var sugars: Double?
    var saturatedFat: Double?
    var salt: Double?
    var nutritionIsComputed: Bool?
    // Ausentes em cópias anteriores à versão 1.2.
    var isSample: Bool?
    var cookedDates: [Date]?
    var photoFocusX: Double?
    var photoFocusY: Double?
    // Ausentes em cópias anteriores à versão 1.4.
    var waitMinutes: Int?
    var waitKind: String?
    var servingName: String?
    var photoZoom: Double?
    var frozenAt: Date?
    var sourceURL: String
    var notes: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    var ingredients: [Ingredient]
    var steps: [RecipeStep]
    var photo: Data?

    init(recipe: Recipe) {
        id = recipe.id
        title = recipe.title
        summary = recipe.summary
        category = recipe.categoryRaw
        tags = recipe.tags
        servings = recipe.servings
        prepMinutes = recipe.prepMinutes
        cookMinutes = recipe.cookMinutes
        calories = recipe.calories
        protein = recipe.protein
        carbs = recipe.carbs
        fat = recipe.fat
        fiber = recipe.fiber
        sugars = recipe.sugars
        saturatedFat = recipe.saturatedFat
        salt = recipe.salt
        nutritionIsComputed = recipe.nutritionIsComputed
        isSample = recipe.isSample
        cookedDates = recipe.cookedDates
        photoFocusX = recipe.photoFocusX
        photoFocusY = recipe.photoFocusY
        waitMinutes = recipe.waitMinutes
        waitKind = recipe.waitKindRaw
        servingName = recipe.servingName
        photoZoom = recipe.photoZoom
        frozenAt = recipe.frozenAt
        sourceURL = recipe.sourceURL
        notes = recipe.notes
        isFavorite = recipe.isFavorite
        createdAt = recipe.createdAt
        updatedAt = recipe.updatedAt
        ingredients = recipe.ingredients
        steps = recipe.steps
        photo = recipe.photoData
    }

    func makeRecipe() -> Recipe {
        let recipe = Recipe(title: title)
        recipe.id = id
        recipe.summary = summary
        recipe.categoryRaw = category
        recipe.tags = tags
        recipe.servings = servings
        recipe.prepMinutes = prepMinutes
        recipe.cookMinutes = cookMinutes
        recipe.calories = calories
        recipe.protein = protein
        recipe.carbs = carbs
        recipe.fat = fat
        recipe.fiber = fiber
        recipe.sugars = sugars ?? 0
        recipe.saturatedFat = saturatedFat ?? 0
        recipe.salt = salt ?? 0
        recipe.nutritionIsComputed = nutritionIsComputed ?? false
        recipe.isSample = isSample ?? false
        recipe.cookedDates = cookedDates ?? []
        recipe.photoFocusX = photoFocusX ?? 0.5
        recipe.photoFocusY = photoFocusY ?? 0.5
        recipe.waitMinutes = waitMinutes ?? 0
        recipe.waitKindRaw = waitKind ?? ""
        recipe.servingName = servingName ?? ""
        recipe.photoZoom = photoZoom ?? 1
        recipe.frozenAt = frozenAt
        recipe.sourceURL = sourceURL
        recipe.notes = notes
        recipe.isFavorite = isFavorite
        recipe.createdAt = createdAt
        recipe.updatedAt = updatedAt
        recipe.ingredients = ingredients
        recipe.steps = steps
        if let photo {
            recipe.photoData = photo
            recipe.thumbnailData = ImageProcessing.thumbnail(from: photo)
        }
        return recipe
    }
}

/// O SwiftUI pode ler e escrever o documento fora da thread principal.
nonisolated struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
