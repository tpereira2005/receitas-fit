import Foundation
import SwiftData
import Testing
@testable import Receitas

@MainActor
struct CookingTests {
    private func food(_ name: String, base: MeasureBase = .grams, unit: Double? = nil, portions: [FoodPortion] = []) -> Food {
        let food = Food(name: name)
        food.measureBase = base
        food.unitWeight = unit
        food.portions = portions
        food.per100 = NutritionFacts(calories: 100, protein: 10)
        return food
    }

    @Test func timersComeFromTheStepText() {
        #expect(StepAnalysis.durations(in: "Leva ao forno durante 30 minutos").map(\.seconds) == [1800])
        #expect(StepAnalysis.durations(in: "Coze 2 a 3 min e deixa repousar 1 hora").map(\.label) == ["2 min", "1 h"])
        #expect(StepAnalysis.durations(in: "Deixa hidratar 10 minutos.").first?.label == "10 min")
        // Esperas longas têm o seu próprio aviso; temperaturas e gramas não são tempos.
        #expect(StepAnalysis.durations(in: "Congela durante pelo menos 24 horas").isEmpty)
        #expect(StepAnalysis.durations(in: "Pré-aquece o forno a 170 °C e junta 5 g de sal").isEmpty)
    }

    @Test func stepsFindTheirIngredients() {
        let ingredients = [
            Ingredient(name: "Leite Proteína", amount: 375, unit: "ml"),
            Ingredient(name: "Leite magro", amount: 225, unit: "ml"),
            Ingredient(name: "Canela", amount: 2, unit: "g"),
            Ingredient(name: "Sal", amount: 0.5, unit: "g"),
            Ingredient(name: "Lotus Biscoff", amount: 3, unit: "bolacha"),
            Ingredient(name: "Iogurte Natural +Proteínas", amount: 2, unit: "un"),
            Ingredient(name: "Avelãs", amount: 15, unit: "g"),
        ]
        let names = { (text: String) in StepAnalysis.ingredients(in: text, from: ingredients).map(\.name) }
        #expect(names("Mistura os dois leites, a canela e o sal") == ["Leite Proteína", "Leite magro", "Canela", "Sal"])
        #expect(names("Esmaga as bolachas Biscoff congeladas") == ["Lotus Biscoff"])
        #expect(names("Tritura os iogurtes") == ["Iogurte Natural +Proteínas"])
        #expect(names("Pica as avelãs") == ["Avelãs"])
        // "salgado" não é "sal"; "proteico" não é "Proteína".
        #expect(names("Um toque salgado e proteico").isEmpty)
    }

    @Test func progressLastsTwelveHours() {
        let defaults = UserDefaults(suiteName: "teste-\(UUID().uuidString)")!
        let id = UUID()
        let step = UUID()
        CookingProgress.save(CookingProgress(steps: [step], updatedAt: .now), for: id, defaults: defaults)
        #expect(CookingProgress.load(for: id, defaults: defaults).steps == [step])
        #expect(CookingProgress.load(for: id, now: .now.addingTimeInterval(13 * 3600), defaults: defaults).isEmpty)
        CookingProgress.clear(for: id, defaults: defaults)
        #expect(CookingProgress.load(for: id, defaults: defaults).isEmpty)
    }

    @Test func weightsNextToMeasures() {
        let yogurt = food("Iogurte", unit: 120)
        let biscoff = food("Lotus Biscoff", portions: [FoodPortion(name: "bolacha", grams: 8)])
        let milk = food("Leite", base: .milliliters)
        let recipe = Recipe(title: "Gelado")
        recipe.servings = 2
        recipe.ingredients = [
            Ingredient(food: yogurt, amount: 2, unit: .unit),
            Ingredient(food: biscoff, amount: 3, measure: .portion(biscoff.portions[0])),
            Ingredient(food: milk, amount: 100, unit: .milliliter),
            Ingredient(food: milk, amount: nil, unit: .toTaste),
        ]
        let items = recipe.ingredients
        #expect(items[0].weightText() == "240 g")
        #expect(items[1].weightText(scale: 2) == "48 g")
        #expect(items[2].weightText() == nil)
        // (240 + 24 + 100) ÷ 2 porções; o q.b. não conta.
        #expect(recipe.weightPerServing == 182)
    }

    @Test func waitReadinessAndPhrases() {
        let recipe = Recipe(title: "Gelado Oreo")
        recipe.waitMinutes = 1440
        recipe.waitKind = .freezer
        #expect(!WaitReminder.isReady(recipe))
        recipe.frozenAt = .now.addingTimeInterval(-20 * 3600)
        #expect(!WaitReminder.isReady(recipe))
        recipe.frozenAt = .now.addingTimeInterval(-25 * 3600)
        #expect(WaitReminder.isReady(recipe))
        WaitReminder.finish(recipe)
        #expect(recipe.frozenAt == nil && recipe.timesCooked == 1)
        #expect(Format.remaining(60) == "Falta 1 h")
        #expect(Format.remaining(240) == "Faltam 4 h")
        #expect(Format.remaining(45) == "Faltam 45 min")
    }
}
