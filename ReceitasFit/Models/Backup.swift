import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct RecipeBackup: Codable {
    var version = 1
    var exportedAt = Date()
    var recipes: [RecipeDTO]

    static func encode(_ recipes: [Recipe]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(RecipeBackup(recipes: recipes.map(RecipeDTO.init(recipe:))))
    }

    /// Importa as receitas que ainda não existem. Devolve quantas foram adicionadas.
    @MainActor
    static func restore(from data: Data, into context: ModelContext, existing: [Recipe]) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(RecipeBackup.self, from: data)
        let existingIDs = Set(existing.map(\.id))
        var added = 0
        for dto in backup.recipes where !existingIDs.contains(dto.id) {
            context.insert(dto.makeRecipe())
            added += 1
        }
        try context.save()
        return added
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

struct BackupDocument: FileDocument {
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
