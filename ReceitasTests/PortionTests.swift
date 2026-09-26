import Foundation
import Testing
@testable import Receitas

@MainActor
struct PortionTests {
    private func close(_ value: Double?, _ expected: Double) -> Bool {
        guard let value else { return false }
        return abs(value - expected) < 0.001
    }

    private func whey() -> Food {
        let food = Food(name: "Whey", category: .supplements)
        food.per100 = NutritionFacts(calories: 400, protein: 80)
        food.portions = [FoodPortion(name: "scoop", grams: 30)]
        return food
    }

    @Test func portionConvertsToGrams() throws {
        let food = whey()
        let portion = try #require(food.portions.first)
        let ingredient = Ingredient(food: food, amount: 2, measure: .portion(portion))
        #expect(ingredient.unit == "scoop")
        #expect(ingredient.portionID == portion.id)
        let facts = try #require(NutritionCalculator.facts(for: ingredient, food: food))
        #expect(abs(facts.protein - 48) < 0.001)  // 60 g × 80 / 100
        #expect(ingredient.amountText() == "2 scoops")
        #expect(ingredient.amountText(scale: 0.5) == "1 scoop")
    }

    @Test func spoonWeightsPerFood() throws {
        let oil = Food(name: "Azeite", category: .fats)
        oil.per100 = NutritionFacts(calories: 900, fat: 100)
        let before = Ingredient(food: oil, amount: 1, unit: .tablespoon)
        #expect(close(NutritionCalculator.facts(for: before, food: oil)?.calories, 135))  // 15 g por omissão

        oil.tablespoonWeight = 13
        let after = Ingredient(food: oil, amount: 1, unit: .tablespoon)
        #expect(close(NutritionCalculator.facts(for: after, food: oil)?.calories, 117))
        // A receita antiga só muda depois de o utilizador aceitar.
        #expect(NutritionCalculator.isOutdated(before, comparedTo: oil))
        #expect(close(NutritionCalculator.facts(for: before, food: oil)?.calories, 135))
    }

    @Test func addingAnUnusedPortionDoesNotOutdateRecipes() {
        let food = whey()
        let grams = Ingredient(food: food, amount: 30, unit: .gram)
        food.portions.append(FoodPortion(name: "saqueta", grams: 25))
        food.teaspoonWeight = 3
        #expect(!NutritionCalculator.isOutdated(grams, comparedTo: food))
    }

    @Test func changingAUsedPortionOutdatesAndRenames() throws {
        let food = whey()
        var portion = try #require(food.portions.first)
        let ingredient = Ingredient(food: food, amount: 1, measure: .portion(portion))
        portion.grams = 32
        portion.name = "medida"
        food.portions = [portion]
        #expect(NutritionCalculator.isOutdated(ingredient, comparedTo: food))
        let updated = NutritionCalculator.ingredientsUpdated([ingredient], with: food)[0]
        #expect(updated.unit == "medida")
        #expect(close(NutritionCalculator.facts(for: updated, food: food)?.calories, 128))
    }

    /// Cópias gravadas antes da versão 1.3 (sem os campos novos) continuam iguais às atuais.
    @Test func oldSnapshotsStayCurrent() throws {
        let food = Food(name: "Ovo", category: .protein)
        food.unitWeight = 60
        food.per100 = NutritionFacts(calories: 143, protein: 12.6)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(FoodSnapshot(food: food))) as! [String: Any]
        json.removeValue(forKey: "portions")
        json.removeValue(forKey: "tablespoonWeight")
        json.removeValue(forKey: "teaspoonWeight")
        let old = try JSONDecoder().decode(FoodSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old == FoodSnapshot(food: food))
        let ingredient = Ingredient(name: "Ovo", amount: 2, unit: "un", foodID: food.id, snapshot: old)
        #expect(!NutritionCalculator.isOutdated(ingredient, comparedTo: food))
    }

    @Test func draftReportsPortionChanges() {
        let food = whey()
        let original = FoodDraft(food: food)
        var draft = original
        draft.portions[0].grams = 35
        draft.portions.append(FoodPortion(name: "  ", grams: 10))  // linha vazia: ignorada
        draft.tablespoonWeight = 8
        let changes = draft.changes(from: original)
        #expect(changes.contains { $0.hasPrefix("Porção: 1 scoop = 30 g") })
        #expect(changes.contains { $0.hasPrefix("Colher de sopa: 15 → 8") })
        #expect(changes.count == 2)
        draft.apply(to: food)
        #expect(food.portions.count == 1)
        #expect(food.tablespoonWeight == 8)
    }

    @Test func pluralization() {
        #expect(FoodPortion.pluralize("fatia", amount: 2) == "fatias")
        #expect(FoodPortion.pluralize("fatia", amount: 0.5) == "fatia")
        #expect(FoodPortion.pluralize("colher", amount: 3) == "colheres")
        #expect(FoodPortion.pluralize("pão", amount: 2) == "pães")
        #expect(FoodPortion.pluralize("barra proteica", amount: 2) == "barras proteicas")
        #expect(FoodPortion.pluralize("fatia de pão", amount: 2) == "fatias de pão")
        #expect(FoodPortion.pluralize("copo", amount: 1) == "copo")
    }
}
