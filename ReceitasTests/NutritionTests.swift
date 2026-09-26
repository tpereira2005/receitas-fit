import Foundation
import SwiftData
import Testing
@testable import Receitas

@MainActor
struct NutritionTests {
    private func food(_ name: String = "Peito de frango", kcal: Double = 110, protein: Double = 23,
                      unitWeight: Double? = nil) -> Food {
        let food = Food(name: name, category: .protein)
        food.per100 = NutritionFacts(calories: kcal, protein: protein)
        food.unitWeight = unitWeight
        return food
    }

    @Test func gramsForEachUnit() {
        #expect(NutritionCalculator.grams(amount: 150, unit: "g", unitWeight: nil) == 150)
        #expect(NutritionCalculator.grams(amount: 200, unit: "ml", unitWeight: nil) == 200)
        #expect(NutritionCalculator.grams(amount: 2, unit: "un", unitWeight: 60) == 120)
        #expect(NutritionCalculator.grams(amount: 2, unit: "un", unitWeight: nil) == nil)
        #expect(NutritionCalculator.grams(amount: 1, unit: "c. sopa", unitWeight: nil) == 15)
        #expect(NutritionCalculator.grams(amount: 2, unit: "c. chá", unitWeight: nil) == 10)
        #expect(NutritionCalculator.grams(amount: nil, unit: "q.b.", unitWeight: nil) == 0)
        #expect(NutritionCalculator.grams(amount: 1, unit: "chávena", unitWeight: nil) == nil)
    }

    @Test func factsUseSnapshotNotLiveFood() {
        let chicken = food()
        let ingredient = Ingredient(food: chicken, amount: 200, unit: .gram)
        chicken.per100 = NutritionFacts(calories: 999, protein: 99)  // editado depois
        let facts = NutritionCalculator.facts(for: ingredient, food: chicken)
        #expect(facts?.calories == 220)
        #expect(facts?.protein == 46)
        #expect(NutritionCalculator.isOutdated(ingredient, comparedTo: chicken))
    }

    @Test func summaryCountsLinkedAndUnresolved() {
        let egg = food("Ovo", kcal: 143, protein: 12.6, unitWeight: nil)
        let items = [
            Ingredient(food: egg, amount: 2, unit: .unit),   // sem peso por unidade → não conta
            Ingredient(food: food(), amount: 100, unit: .gram),
            Ingredient(name: "Sal", amount: nil, unit: "q.b."), // sem alimento
        ]
        let summary = NutritionCalculator.summarize(items, foods: [:])
        #expect(summary.linked == 2)
        #expect(summary.unresolved == 2)
        #expect(summary.total.calories == 110)
    }

    @Test func updateStoresPerServingValues() {
        let recipe = Recipe(title: "Teste")
        recipe.servings = 2
        recipe.ingredients = [Ingredient(food: food(), amount: 300, unit: .gram)]
        NutritionCalculator.update(recipe, foods: [:])
        #expect(recipe.nutritionIsComputed)
        #expect(abs(recipe.calories - 165) < 0.001)
        #expect(abs(recipe.protein - 34.5) < 0.001)
    }

    @Test func applyingFoodChangesUpdatesSnapshots() {
        let chicken = food()
        let recipe = Recipe(title: "Teste")
        recipe.ingredients = [Ingredient(food: chicken, amount: 100, unit: .gram)]
        NutritionCalculator.update(recipe, foods: [:])
        chicken.per100 = NutritionFacts(calories: 120, protein: 25)
        let updated = NutritionCalculator.ingredientsUpdated(recipe.ingredients, with: chicken)
        #expect(updated.first?.snapshot?.per100.calories == 120)
        #expect(!NutritionCalculator.isOutdated(updated[0], comparedTo: chicken))
    }

    @Test func foodMatcherPrefersMostSpecific() {
        let foods = [food("Sal"), food("Molho de soja reduzido em sal"), food("Lombo de salmão")]
        #expect(FoodMatcher.match("Molho de soja reduzido em sal", in: foods)?.name == "Molho de soja reduzido em sal")
        #expect(FoodMatcher.match("Lombos de salmão (≈150 g)", in: foods)?.name == "Lombo de salmão")
        #expect(FoodMatcher.match("Salmão fumado", in: foods) == nil)
    }

    @Test func foodDraftDescribesChanges() {
        var original = FoodDraft()
        original.name = "Peito de frango"
        original.facts = NutritionFacts(calories: 110, protein: 23)
        var edited = original
        edited.facts.calories = 120
        let changes = edited.changes(from: original)
        #expect(changes.count == 1)
        #expect(changes.first?.hasPrefix("Energia") == true)
        #expect(original.changes(from: original).isEmpty)
    }

    @Test func jsonCacheReturnsSameValues() {
        JSONCache.reset()
        let steps = [RecipeStep(text: "Um"), RecipeStep(text: "Dois")]
        let data = JSONCache.encode(steps)
        #expect(JSONCache.decode([RecipeStep].self, from: data) == steps)
        #expect(JSONCache.decode([RecipeStep].self, from: data) == steps)
        #expect(JSONCache.count == 1)
        #expect(JSONCache.decode([RecipeStep].self, from: Data()).isEmpty)
    }
}
