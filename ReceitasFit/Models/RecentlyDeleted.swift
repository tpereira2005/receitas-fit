import Foundation
import SwiftData

/// "Apagadas recentemente": apagar uma receita ou um alimento guarda-o aqui durante 30 dias.
/// Não aparece em lado nenhum da app (nem na pesquisa, no Spotlight ou nas cópias) até ser recuperado.
enum RecentlyDeleted {
    static let days = 30
    static let lifetime: TimeInterval = TimeInterval(days) * 86_400

    /// Dias que ainda faltam até sair de vez (pelo menos 1).
    static func daysLeft(since deletedAt: Date, now: Date = .now) -> Int {
        max(1, days - Int(now.timeIntervalSince(deletedAt) / 86_400))
    }

    /// Apaga de vez o que está aqui há mais de 30 dias. Devolve quantos itens saíram.
    @MainActor
    @discardableResult
    static func purge(_ context: ModelContext, now: Date = .now) -> Int {
        let limit = now.addingTimeInterval(-lifetime)
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.deletedAt != nil }))) ?? []
        let foods = (try? context.fetch(FetchDescriptor<Food>(predicate: #Predicate { $0.deletedAt != nil }))) ?? []
        var removed = 0
        for recipe in recipes where (recipe.deletedAt ?? now) < limit {
            context.delete(recipe)
            removed += 1
        }
        for food in foods where (food.deletedAt ?? now) < limit {
            context.delete(food)
            removed += 1
        }
        if removed > 0 { try? context.save() }
        return removed
    }
}

extension Recipe {
    /// Receitas visíveis (não apagadas), para os `@Query` e as pesquisas.
    static let notDeleted = #Predicate<Recipe> { $0.deletedAt == nil }

    var isInTrash: Bool { deletedAt != nil }

    /// Vai para "Apagadas recentemente" (a espera em curso é cancelada).
    func moveToTrash() {
        if frozenAt != nil { WaitReminder.cancel(self) }
        deletedAt = .now
        CookingProgress.clear(for: id)
    }

    func restoreFromTrash() {
        deletedAt = nil
    }
}

extension Food {
    static let notDeleted = #Predicate<Food> { $0.deletedAt == nil }

    func moveToTrash() {
        deletedAt = .now
    }

    func restoreFromTrash() {
        deletedAt = nil
    }
}
