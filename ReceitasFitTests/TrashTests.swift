import Foundation
import SwiftData
import Testing
@testable import ReceitasFit

@MainActor
struct TrashTests {
    private func memoryContext() throws -> ModelContext {
        ModelContext(try ModelContainer(for: DataStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    @Test func deletedItemsAreHiddenAndCanBeRestored() throws {
        let context = try memoryContext()
        let kept = Recipe(title: "Gelado Oreo")
        let deleted = Recipe(title: "Gelado Biscoff")
        let food = Food(name: "Oreo")
        [kept, deleted].forEach(context.insert)
        context.insert(food)
        deleted.moveToTrash()
        food.moveToTrash()
        try context.save()

        let visible = try context.fetch(FetchDescriptor<Recipe>(predicate: Recipe.notDeleted))
        #expect(visible.map(\.title) == ["Gelado Oreo"])
        #expect(try context.fetch(FetchDescriptor<Food>(predicate: Food.notDeleted)).isEmpty)

        deleted.restoreFromTrash()
        #expect(try context.fetch(FetchDescriptor<Recipe>(predicate: Recipe.notDeleted)).count == 2)
    }

    @Test func purgeRemovesOnlyOldItems() throws {
        let context = try memoryContext()
        let old = Recipe(title: "Antiga")
        old.deletedAt = .now.addingTimeInterval(-31 * 86_400)
        let recent = Recipe(title: "Recente")
        recent.deletedAt = .now.addingTimeInterval(-2 * 86_400)
        [old, recent, Recipe(title: "Normal")].forEach(context.insert)
        try context.save()

        #expect(RecentlyDeleted.purge(context) == 1)
        #expect(Set(try context.fetch(FetchDescriptor<Recipe>()).map(\.title)) == ["Recente", "Normal"])
        #expect(RecentlyDeleted.daysLeft(since: .now.addingTimeInterval(-2 * 86_400)) == 28)
    }

    /// Importar uma cópia que tem uma receita apagada volta a pô-la visível, sem a duplicar.
    @Test func importingABackupRestoresDeletedItems() throws {
        let context = try memoryContext()
        let recipe = Recipe(title: "Cookie Dough Cake")
        context.insert(recipe)
        try context.save()
        let data = try RecipeBackup.encode(recipes: [recipe], foods: [])
        recipe.moveToTrash()
        try context.save()

        let result = try RecipeBackup.restore(from: data, into: context)
        #expect(result.recipes == 1)
        #expect(recipe.deletedAt == nil)
        #expect(try context.fetch(FetchDescriptor<Recipe>()).count == 1)
    }

    @Test func backupStampsRoundTrip() {
        let date = AutoBackup.date(fromStamp: "2026-09-25-2130")
        #expect(date != nil)
        #expect(date.map(AutoBackup.stamp) == "2026-09-25-2130")
    }
}
