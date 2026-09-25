import Foundation
import SwiftData
import Testing
@testable import ReceitasFit

@MainActor
struct BrowseTests {
    private func recipe(_ title: String, category: RecipeCategory = .lunch, tags: [String] = [],
                        protein: Double = 10, calories: Double = 500) -> Recipe {
        let recipe = Recipe(title: title, category: category)
        recipe.tags = tags
        recipe.protein = protein
        recipe.calories = calories
        return recipe
    }

    @Test func combinedFiltersNeedAllConditions() {
        let bowl = recipe("Bowl", category: .lunch, tags: ["Meal prep"], protein: 40, calories: 450)
        let shake = recipe("Batido", category: .drink, tags: ["Pós-treino"], protein: 30, calories: 250)
        let cake = recipe("Bolo", category: .dessert, protein: 5, calories: 300)
        cake.isSample = true
        shake.cookedDates = [.now]

        var filters = RecipeFilterSet()
        filters.quick = [.highProtein]
        #expect([bowl, shake, cake].filter(filters.matches).map(\.title) == ["Bowl", "Batido"])

        filters.categories = [.drink, .dessert]
        #expect([bowl, shake, cake].filter(filters.matches).map(\.title) == ["Batido"])

        filters = RecipeFilterSet(tags: ["Meal prep", "Pós-treino"])
        #expect([bowl, shake, cake].filter(filters.matches).count == 2)

        filters = RecipeFilterSet(cooked: .neverCooked, hideSamples: true)
        #expect([bowl, shake, cake].filter(filters.matches).map(\.title) == ["Bowl"])
        #expect(filters.activeCount == 2)
        filters.remove(.samples)
        #expect(filters.activeCount == 1)
    }

    @Test func searchRanksTitleMatchesFirst() {
        let a = recipe("Salada com frango")
        a.ingredients = [Ingredient(name: "Frango", amount: 100, unit: "g")]
        let b = recipe("Frango teriyaki")
        let c = recipe("Wrap", tags: ["frango"])
        let scores = [a, b, c].compactMap { r in r.searchScore("frango").map { (r.title, $0) } }
        let ordered = scores.sorted { $0.1 > $1.1 }.map(\.0)
        #expect(ordered.first == "Frango teriyaki")
        #expect(recipe("Bolo").searchScore("frango") == nil)
    }

    @Test func tagsRenameMergeAndDelete() {
        let a = recipe("A", tags: ["Rapida", "Meal prep"])
        let b = recipe("B", tags: ["Rápida"])
        TagLibrary.rename("Rapida", to: "Rápida", in: [a, b])
        #expect(a.tags == ["Rápida", "Meal prep"])
        #expect(TagLibrary.counts(in: [a, b]).first?.tag == "Rápida")
        #expect(TagLibrary.counts(in: [a, b]).first?.count == 2)

        // Juntar numa etiqueta que a receita já tem não a repete.
        let c = recipe("C", tags: ["Rápida", "Rapidinha"])
        TagLibrary.rename("Rapidinha", to: "Rápida", in: [c])
        #expect(c.tags == ["Rápida"])

        TagLibrary.delete("Rápida", in: [a, b, c])
        #expect(a.tags == ["Meal prep"] && b.tags.isEmpty && c.tags.isEmpty)
    }

    @Test func tagCatalogKeepsOriginalsAndCreatedTags() {
        UserDefaults.standard.removeObject(forKey: TagLibrary.catalogKey)
        defer { UserDefaults.standard.removeObject(forKey: TagLibrary.catalogKey) }
        let a = recipe("A", tags: ["Meal prep", "Verão"])

        // As etiquetas de origem aparecem mesmo sem receitas, depois das usadas.
        let all = TagLibrary.all(in: [a])
        #expect(all.prefix(2).map(\.tag).sorted() == ["Meal prep", "Verão"])
        #expect(all.contains { $0.tag == "Low carb" && $0.count == 0 })
        #expect(all.filter { $0.tag == "Meal prep" }.count == 1)

        // Criar, sem repetir as que já existem.
        #expect(TagLibrary.create("Jantar rápido", in: [a]))
        #expect(!TagLibrary.create("verão", in: [a]))
        #expect(TagLibrary.all(in: [a]).contains { $0.tag == "Jantar rápido" })

        // Editar e apagar uma de origem.
        TagLibrary.rename("Low carb", to: "Poucos hidratos", in: [a])
        TagLibrary.delete("Pré-treino", in: [a])
        let tags = TagLibrary.all(in: [a]).map(\.tag)
        #expect(tags.contains("Poucos hidratos") && !tags.contains("Low carb") && !tags.contains("Pré-treino"))

        // Apagar todas deixa a lista vazia (não volta às de origem).
        for tag in TagLibrary.catalog { TagLibrary.delete(tag, in: []) }
        #expect(TagLibrary.catalog.isEmpty)
    }

    @Test func editingASampleMakesItTheUsers() {
        let sample = recipe("Exemplo")
        sample.isSample = true
        RecipeDraft(recipe: sample).apply(to: sample, foods: [:])
        #expect(!sample.isSample)
    }

    @Test func recentlyCookedSortAndRelativeDays() {
        let old = recipe("Antiga")
        old.cookedDates = [Date.now.addingTimeInterval(-10 * 86_400)]
        let fresh = recipe("Ontem")
        fresh.cookedDates = [Date.now.addingTimeInterval(-86_400)]
        let never = recipe("Nunca")
        #expect(RecipeSort.recentlyCooked.sorted([old, never, fresh]).map(\.title) == ["Ontem", "Antiga", "Nunca"])

        #expect(Format.relativeDay(.now) == "hoje")
        #expect(Format.relativeDay(Date.now.addingTimeInterval(-86_400)) == "ontem")
        #expect(Format.relativeDay(Date.now.addingTimeInterval(-3 * 86_400)) == "há 3 dias")
    }
}
