import Foundation
import SwiftData
import Testing
@testable import ReceitasFit

@MainActor
struct DataTests {
    private func memoryContainer() throws -> ModelContainer {
        try ModelContainer(for: DataStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// Uma base de dados criada com o esquema antigo (V1) tem de abrir com o atual (V2) sem perder nada.
    @Test func migrationFromV1KeepsData() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "migracao-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "teste.store")
        let recipeID = UUID()

        do {
            let v1 = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(for: v1, configurations: ModelConfiguration(schema: v1, url: url))
            let context = ModelContext(container)
            let recipe = SchemaV1.Recipe(title: "Panquecas")
            recipe.id = recipeID
            recipe.servings = 3
            recipe.isFavorite = true
            recipe.calories = 310
            context.insert(recipe)
            let food = SchemaV1.Food(name: "Ovo")
            food.unitWeight = 60
            context.insert(food)
            try context.save()
        }

        let container = try ModelContainer(
            for: DataStore.schema,
            migrationPlan: ReceitasMigrationPlan.self,
            configurations: ModelConfiguration(schema: DataStore.schema, url: url)
        )
        let context = ModelContext(container)
        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        #expect(recipes.count == 1)
        let recipe = try #require(recipes.first)
        #expect(recipe.id == recipeID)
        #expect(recipe.title == "Panquecas")
        #expect(recipe.servings == 3)
        #expect(recipe.isFavorite)
        #expect(recipe.calories == 310)
        #expect(recipe.isSample == false)
        #expect(recipe.cookedDates.isEmpty)
        #expect(recipe.photoFocusX == 0.5)
        let foods = try context.fetch(FetchDescriptor<Food>())
        #expect(foods.first?.unitWeight == 60)
        #expect(foods.first?.portions.isEmpty == true)
        #expect(foods.first?.tablespoonWeight == nil)
    }

    @Test func backupRoundTripKeepsEverything() throws {
        let source = ModelContext(try memoryContainer())
        let food = Food(name: "Whey", category: .supplements)
        food.per100 = NutritionFacts(calories: 380, protein: 75)
        food.portions = [FoodPortion(name: "1 scoop", grams: 30)]
        food.tablespoonWeight = 8
        source.insert(food)
        let recipe = Recipe(title: "Batido", category: .drink)
        recipe.ingredients = [Ingredient(food: food, amount: 30, unit: .gram)]
        recipe.steps = [RecipeStep(text: "Misturar")]
        recipe.cookedDates = [Date(timeIntervalSince1970: 1_700_000_000)]
        recipe.isSample = true
        recipe.photoFocusY = 0.3
        NutritionCalculator.update(recipe, foods: [:])
        source.insert(recipe)
        try source.save()

        let data = try RecipeBackup.encode(recipes: [recipe], foods: [food])
        let target = ModelContext(try memoryContainer())
        let result = try RecipeBackup.restore(from: data, into: target)
        #expect(result.recipes == 1)
        #expect(result.foods == 1)

        let restored = try #require(try target.fetch(FetchDescriptor<Recipe>()).first)
        #expect(restored.title == "Batido")
        #expect(restored.ingredients.count == 1)
        #expect(restored.steps.first?.text == "Misturar")
        #expect(restored.cookedDates.count == 1)
        #expect(restored.isSample)
        #expect(restored.photoFocusY == 0.3)
        #expect(abs(restored.protein - 22.5) < 0.001)
        let restoredFood = try #require(try target.fetch(FetchDescriptor<Food>()).first)
        #expect(restoredFood.portions.first?.grams == 30)
        #expect(restoredFood.tablespoonWeight == 8)

        // Importar a mesma cópia outra vez não duplica nada.
        let again = try RecipeBackup.restore(from: data, into: target)
        #expect(again.recipes == 0 && again.foods == 0)
    }

    @Test func samplesAreMarkedAndMigrationFindsOldOnes() throws {
        let context = ModelContext(try memoryContainer())
        SampleData.insert(into: context)
        let samples = try context.fetch(FetchDescriptor<Recipe>())
        #expect(!samples.isEmpty)
        let allMarked = samples.allSatisfy { $0.isSample }
        #expect(allMarked)

        let old = Recipe(title: "Bowl de frango teriyaki")
        let mine = Recipe(title: "A minha receita")
        context.insert(old)
        context.insert(mine)
        DataMigration.migrateToV4(context)
        #expect(old.isSample)
        #expect(!mine.isSample)
    }
}
