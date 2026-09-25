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

    /// Instalação nova: todas as receitas base, com todos os ingredientes ligados a alimentos.
    @Test func baseRecipesAreLinkedAndComputed() throws {
        let context = ModelContext(try memoryContainer())
        FoodLibrary.insertMissingDefaults(in: context)
        let created = SampleData.insertBase(into: context)
        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        #expect(created == SampleData.baseTitles.count)
        #expect(recipes.count == created)
        for recipe in recipes {
            #expect(!recipe.isSample)
            #expect(recipe.nutritionIsComputed)
            #expect(recipe.calories > 0, "\(recipe.title)")
            let unlinked = recipe.ingredients.filter { $0.foodID == nil }.map(\.name)
            #expect(unlinked.isEmpty, "\(recipe.title): \(unlinked)")
        }

        // Biscoff: 375 ml de leite proteico + 225 ml de leite magro + 3 bolachas, a dividir por 2 doses.
        let biscoff = try #require(recipes.first { $0.title == "Gelado Biscoff" })
        #expect(abs(biscoff.protein - 23.2) < 0.1)
        #expect(biscoff.ingredients.last?.displayText() == "3 bolachas Lotus Biscoff")

        // Correr outra vez não duplica nada.
        #expect(SampleData.insertBase(into: context) == 0)
    }

    /// Atualização (versão 5): entram só os gelados que faltam e só os alimentos de que precisam.
    @Test func migrationV5AddsOnlyMissingRecipesAndFoods() throws {
        let context = ModelContext(try memoryContainer())
        let milk = Food(name: "Leite magro", category: .dairy)
        milk.measureBase = .milliliters
        milk.per100 = NutritionFacts(calories: 34, protein: 3.4, carbs: 4.9)
        context.insert(milk)
        context.insert(Recipe(title: "Cookie Dough Cake", category: .snack))
        try context.save()

        DataMigration.migrateToV5(context)

        let titles = try context.fetch(FetchDescriptor<Recipe>()).map(\.title)
        #expect(titles.filter { $0 == "Cookie Dough Cake" }.count == 1)
        #expect(titles.contains("Gelado Oreo"))
        let foods = try context.fetch(FetchDescriptor<Food>())
        let names = Set(foods.map(\.name))
        #expect(foods.filter { $0.name == "Leite magro" }.count == 1)
        #expect(names.contains("Goma xantana"))
        #expect(names.contains("Leite Proteína"))
        // Alimentos de origem que nenhum gelado usa não voltam a aparecer.
        #expect(!names.contains("Peito de frango"))
        // O Cookie Dough Cake já existia: os alimentos só dele não são acrescentados.
        #expect(!names.contains("Select Protein Powder Gourmet Vanilla"))
    }
}
